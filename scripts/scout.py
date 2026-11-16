#!/usr/bin/env python3
"""Deterministic helpers for the job-scouting agents (Job Scout, Job Reviewer), so they spend
tokens only on judgement. Everything personal comes from documents/search.json (gitignored).

Usage: python3 -I scripts/scout.py <command>

  start                    Scout, first step: checks the issue out, queues it behind an older chunk
                           that is still being scouted or reviewed, creates the chunk folder.
                           Prints `GO <chunk folder>` or `WAIT ...` (then stop the run).
  search                   Job-board APIs (Arbeitsagentur, Arbeitnow) with the searches from
                           documents/search.json: only postings young enough, title filter applied,
                           already-seen jobs removed. One JSON line per candidate, nearby jobs first.
  check <company> <title> <url>
                           Prints NEW or SEEN for a job found elsewhere (web search, careers page).
  fetch <n> <url>          Renders the posting, saves it verbatim to <chunk>/postings/<n>.md and
                           prints its text (capped).
  record                   Adds every job in <chunk>/chunk.json to the seen store.
  handoff <one-line comment>   Scout, last step: comment + assign the issue to the Job Reviewer.
  dir                      Prints this issue's chunk folder.
  finish <one-line comment>    Comment, close the issue, release the next queued chunk.
"""
import datetime as dt
import json
import os
import re
import subprocess
import sys
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

JH = Path(__file__).resolve().parent.parent
SCOUT = JH / "jobs" / "scout"
SEEN = SCOUT / "seen.json"
ROUTINE_TITLE = "Find jobs"
OPEN = ("todo", "in_progress", "in_review", "blocked")
STALE_HOURS = 6  # an older chunk without any update for this long no longer holds up the queue
FETCH_PRINT_CHARS = 9000
BA_API = "https://rest.arbeitsagentur.de/jobboerse/jobsuche-service/pc/v6/jobs"
BA_DETAIL = "https://www.arbeitsagentur.de/jobsuche/jobdetail/"
ARBEITNOW_API = "https://www.arbeitnow.com/api/job-board-api"
TODAY = dt.date.today()


def die(msg):
    print(msg, file=sys.stderr)
    sys.exit(1)


def config():
    path = JH / "documents" / "search.json"
    if not path.exists():
        die(f"missing {path}: copy documents.example/search.json and fill it in")
    return json.loads(path.read_text(encoding="utf-8"))


def http_json(url, headers=None, method="GET", body=None):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, data=data, method=method, headers={
        "Accept": "application/json", "User-Agent": "job-hunt-scout/1.0", **(headers or {})})
    with urllib.request.urlopen(req, timeout=40) as res:
        raw = res.read()
    return json.loads(raw) if raw.strip() else None


# ---------- seen store ----------

def norm_url(url):
    p = urllib.parse.urlsplit(url.strip())
    query = [(k, v) for k, v in urllib.parse.parse_qsl(p.query) if not k.lower().startswith(("utm_", "ref", "source"))]
    return f"{p.netloc.lower().removeprefix('www.')}{p.path.rstrip('/')}" + ("?" + urllib.parse.urlencode(query) if query else "")


def job_key(company, title):
    def squash(s):
        s = re.sub(r"\((?:[mwfdx/|* ,:-]|all genders|gn|div)+\)", " ", s.lower())
        s = re.sub(r"\b(gmbh|ag|se|kg|co|mbh|ug|inc|ltd|group|holding)\b", " ", s)
        return re.sub(r"[^a-z0-9äöüß]+", "", s)
    return f"{squash(company)}|{squash(title)}"


def load_seen():
    if SEEN.exists():
        return json.loads(SEEN.read_text(encoding="utf-8"))
    return {"urls": {}, "keys": {}}


def is_seen(seen, company, title, url):
    return norm_url(url) in seen["urls"] or job_key(company, title) in seen["keys"]


# ---------- search ----------

def title_ok(title, cfg):
    low = title.lower()
    if any(x.lower() in low for x in cfg.get("title_exclude", [])):
        return False
    for kw in cfg["title_keywords"]:
        if len(kw) <= 3:  # AI, KI, ML: whole word, exact case ("Mail", "Kiel" must not match)
            if re.search(rf"(?<![A-Za-zÄÖÜäöü]){re.escape(kw)}(?![A-Za-zÄÖÜäöü])", title):
                return True
        elif kw.lower() in low:
            return True
    return False


def search_ba(cfg, out, errors):
    oldest = (TODAY - dt.timedelta(days=cfg["max_age_days"])).isoformat()
    for s in cfg.get("ba_searches", []):
        params = {"was": s["what"], "veroeffentlichtseit": cfg["max_age_days"], "size": s.get("size", 50), "page": 1}
        if s.get("where"):
            params.update(wo=s["where"], umkreis=s.get("radius_km", 25))
        try:
            data = http_json(f"{BA_API}?{urllib.parse.urlencode(params)}", {"X-API-Key": "jobboerse-jobsuche"})
        except (urllib.error.URLError, TimeoutError, ValueError) as e:
            errors.append(f"arbeitsagentur '{s['what']}': {e}")
            continue
        for j in (data or {}).get("ergebnisliste") or []:
            # The API's own age filter counts re-publications; the first publication date is what matters.
            if j.get("stellenangebotsart") != "ARBEIT" or (j.get("datumErsteVeroeffentlichung") or "9") < oldest:
                continue
            if s.get("homeoffice_only") and not j.get("homeofficemoeglich"):
                continue
            places = [a.get("adresse", {}).get("ort", "") for a in j.get("stellenlokationen") or []]
            out.append({
                "tier": s["tier"], "title": j.get("stellenangebotsTitel", ""), "company": j.get("firma", ""),
                "location": " / ".join(p for p in places[:3] if p), "posted": j.get("datumErsteVeroeffentlichung"),
                "homeoffice": j.get("homeofficetyp") if j.get("homeofficemoeglich") else None,
                "url": j.get("externeURL") or BA_DETAIL + j.get("referenznummer", ""), "source": "Arbeitsagentur"})


def search_arbeitnow(cfg, out, errors):
    an = cfg.get("arbeitnow") or {}
    if not an.get("enabled"):
        return
    oldest = TODAY - dt.timedelta(days=cfg["max_age_days"])
    places = {tier: [p.lower() for p in names] for tier, names in cfg.get("local_places", {}).items()}
    for page in range(1, an.get("pages", 2) + 1):
        try:
            data = http_json(f"{ARBEITNOW_API}?page={page}")
        except (urllib.error.URLError, TimeoutError, ValueError) as e:
            errors.append(f"arbeitnow page {page}: {e}")
            break
        for j in (data or {}).get("data") or []:
            posted = dt.date.fromtimestamp(j.get("created_at", 0))
            place = j.get("location", "")
            near = next((tier for tier, names in places.items() if any(n in place.lower() for n in names)), None)
            if posted < oldest or not (near or j.get("remote")):
                continue
            out.append({"tier": near or "remote", "title": j.get("title", ""), "company": j.get("company_name", ""),
                        "location": place, "posted": posted.isoformat(), "homeoffice": "remote" if j.get("remote") else None,
                        "url": j.get("url", ""), "source": "Arbeitnow"})


def cmd_search():
    cfg, seen, found, errors = config(), load_seen(), [], []
    search_ba(cfg, found, errors)
    search_arbeitnow(cfg, found, errors)
    tiers = cfg["tier_order"]  # nearest first: the candidate prefers jobs near home
    keys, result = set(), {t: [] for t in tiers}
    for c in sorted(found, key=lambda c: c["posted"] or "", reverse=True):
        key = job_key(c["company"], c["title"])
        if not c["url"] or key in keys or not title_ok(c["title"], cfg) or is_seen(seen, c["company"], c["title"], c["url"]):
            continue
        keys.add(key)
        result[c["tier"]].append(c)
    per_tier = cfg.get("search_print_per_tier", 14)
    print("# tier | posted | company | title | location | home office | source | url")
    for t in tiers:
        for c in result[t][:per_tier]:
            print(" | ".join(str(c.get(k) or "-") for k in ("tier", "posted", "company", "title", "location", "homeoffice", "source", "url")))
    print("# new candidates: " + ", ".join(f"{t} {len(result[t])} (showing {min(len(result[t]), per_tier)})" for t in tiers)
          + f"; max age {cfg['max_age_days']} days; chunk size {cfg['chunk_size']}")
    for e in errors:
        print(f"# source failed: {e}")


def cmd_check(company, title, url):
    print("SEEN" if is_seen(load_seen(), company, title, url) else "NEW")


# ---------- Paperclip ----------

def api(method, path, body=None):
    base, key = os.environ.get("PAPERCLIP_API_URL"), os.environ.get("PAPERCLIP_API_KEY")
    if not base or not key:
        die("PAPERCLIP_API_URL / PAPERCLIP_API_KEY missing: this command only works inside an agent run")
    headers = {"Authorization": f"Bearer {key}"}
    if os.environ.get("PAPERCLIP_RUN_ID"):
        headers["X-Paperclip-Run-Id"] = os.environ["PAPERCLIP_RUN_ID"]
    if body is not None:
        headers["Content-Type"] = "application/json"
    try:
        return http_json(base.rstrip("/") + path, headers, method, body)
    except urllib.error.HTTPError as e:
        die(f"{method} {path}: HTTP {e.code}: {e.read()[:400].decode(errors='replace')}")


def my_issue():
    task = os.environ.get("PAPERCLIP_TASK_ID")
    if not task:
        die("PAPERCLIP_TASK_ID missing: no issue in this run")
    return api("GET", f"/api/issues/{task}")


def chunk_issues():
    cid = os.environ["PAPERCLIP_COMPANY_ID"]
    return [i for i in api("GET", f"/api/companies/{cid}/issues?limit=500")
            if i.get("originKind") == "routine_execution" and i.get("title", "").startswith(ROUTINE_TITLE)]


def chunk_dir(issue, create=False):
    SCOUT.mkdir(parents=True, exist_ok=True)
    for d in SCOUT.glob(f"*_{issue['identifier']}"):
        return d
    d = SCOUT / f"{TODAY.isoformat()}_{issue['identifier']}"
    if not create:
        die(f"no chunk folder for {issue['identifier']} under {SCOUT}")
    (d / "postings").mkdir(parents=True)
    return d


def cmd_start():
    me = my_issue()
    fresh = (dt.datetime.now(dt.timezone.utc) - dt.timedelta(hours=STALE_HOURS)).isoformat()
    ahead = [i for i in chunk_issues() if i["id"] != me["id"] and i["status"] in OPEN
             and i["createdAt"] < me["createdAt"] and i["updatedAt"] > fresh]
    if ahead:
        api("PATCH", f"/api/issues/{me['id']}", {"status": "backlog"})
        api("POST", f"/api/issues/{me['id']}/comments",
            {"body": f"Queued: {ahead[0]['identifier']} is still being scouted or reviewed. This chunk starts when it is finished."})
        print(f"WAIT: queued behind {ahead[0]['identifier']}. Stop this run now; do nothing else.")
        return
    api("POST", f"/api/issues/{me['id']}/checkout",
        {"agentId": os.environ["PAPERCLIP_AGENT_ID"], "expectedStatuses": ["todo", "backlog", "in_progress", "in_review", "blocked"]})
    print(f"GO {chunk_dir(me, create=True)}  (issue {me['identifier']}, today {TODAY.isoformat()})")


def cmd_dir():
    me = my_issue()
    api("POST", f"/api/issues/{me['id']}/checkout",
        {"agentId": os.environ["PAPERCLIP_AGENT_ID"], "expectedStatuses": ["todo", "backlog", "in_progress", "in_review", "blocked"]})
    print(f"{chunk_dir(me)}  (issue {me['identifier']}, today {TODAY.isoformat()})")


def cmd_fetch(n, url):
    d = chunk_dir(my_issue())
    text = subprocess.run([str(JH / "scripts" / "fetch_page.sh"), url, "40000"], capture_output=True, text=True, timeout=120).stdout.strip()
    if not text or text.startswith("FETCH_FAILED"):
        print(text or "FETCH_FAILED: no output")
        return
    path = d / "postings" / f"{int(n):02d}.md"
    path.write_text(f"{text}\n\n---\nSource: {url}\nFetched: {TODAY.isoformat()} with scripts/fetch_page.sh (headless Chrome), verbatim page text\n", encoding="utf-8")
    print(text[:FETCH_PRINT_CHARS])
    print(f"\n# saved {len(text)} chars to {path}" + (f" (only the first {FETCH_PRINT_CHARS} printed)" if len(text) > FETCH_PRINT_CHARS else ""))


def cmd_record():
    d = chunk_dir(my_issue())
    jobs, seen = json.loads((d / "chunk.json").read_text(encoding="utf-8")), load_seen()
    for j in jobs:
        seen["urls"][norm_url(j["url"])] = TODAY.isoformat()
        seen["keys"][job_key(j["company"], j["title"])] = TODAY.isoformat()
    SEEN.write_text(json.dumps(seen, ensure_ascii=False, indent=0), encoding="utf-8")
    print(f"recorded {len(jobs)} jobs; seen store now holds {len(seen['keys'])}")


def cmd_handoff(comment):
    me = my_issue()
    reviewer = json.loads((JH / "agents" / "_shared" / "roster.json").read_text())["job-reviewer"]
    api("POST", f"/api/issues/{me['id']}/comments", {"body": comment})
    api("PATCH", f"/api/issues/{me['id']}", {"assigneeAgentId": reviewer, "status": "todo"})
    print(f"{me['identifier']} handed to the Job Reviewer. Stop this run now.")


def cmd_finish(comment):
    me = my_issue()
    api("POST", f"/api/issues/{me['id']}/comments", {"body": comment})
    api("PATCH", f"/api/issues/{me['id']}", {"status": "done"})
    queued = sorted((i for i in chunk_issues() if i["status"] == "backlog"), key=lambda i: i["createdAt"])
    if queued:
        api("PATCH", f"/api/issues/{queued[0]['id']}", {"status": "todo"})
    print(f"{me['identifier']} closed." + (f" Released queued chunk {queued[0]['identifier']}." if queued else "") + " Stop this run now.")


COMMANDS = {"start": (cmd_start, 0), "search": (cmd_search, 0), "check": (cmd_check, 3), "fetch": (cmd_fetch, 2),
            "record": (cmd_record, 0), "handoff": (cmd_handoff, 1), "dir": (cmd_dir, 0), "finish": (cmd_finish, 1)}

if __name__ == "__main__":
    if len(sys.argv) < 2 or sys.argv[1] not in COMMANDS or len(sys.argv) - 2 != COMMANDS[sys.argv[1]][1]:
        die(__doc__)
    COMMANDS[sys.argv[1]][0](*sys.argv[2:])
