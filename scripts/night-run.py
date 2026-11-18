#!/usr/bin/env python3
"""Hold the computer awake for the nightly job search: wait for the instance, for the scheduled
"Find jobs" chunk to appear, and until no chunk is being scouted or reviewed any more.

Started by the wake service (scripts/install-night-run.sh) a few minutes before the routine's
schedule. It starts nothing itself: the instance's own scheduler fires the routine.
"""
import json
import sys
import time
import urllib.request
from datetime import datetime, timedelta, timezone

API = "http://127.0.0.1:3300"
HEALTH_WAIT = 180      # the instance resumes (or autostarts) within this
TRIGGER_WAIT = 15 * 60  # the wake timer fires a few minutes before the schedule
TOTAL = 60 * 60
OPEN = {"todo", "in_progress", "in_review", "backlog"}


def get(path):
    return json.load(urllib.request.urlopen(API + path, timeout=20))


def chunks(company):
    d = get(f"/api/companies/{company}/issues?limit=1000")
    d = d if isinstance(d, list) else d.get("issues", d.get("items", []))
    return [i for i in d if i["title"].startswith("Find jobs")]


def main():
    start = time.time()
    since = (datetime.now(timezone.utc) - timedelta(minutes=1)).isoformat()
    while True:
        try:
            get("/api/health")
            break
        except Exception:
            if time.time() - start > HEALTH_WAIT:
                sys.exit("instance not reachable: no job search tonight")
            time.sleep(5)
    company = next(c["id"] for c in get("/api/companies") if c["name"] == "Job Hunt")
    fired = False
    while time.time() - start < TOTAL:
        try:
            c = chunks(company)
            fired = fired or any(i["createdAt"] > since for i in c)
            busy = any(i["status"] in OPEN for i in c)
            if fired and not busy:
                time.sleep(90)  # a queued chunk released by `scout.py finish` shows up as open again
                if not any(i["status"] in OPEN for i in chunks(company)):
                    print("job search finished")
                    return
            elif not fired and not busy and time.time() - start > TRIGGER_WAIT:
                sys.exit("the schedule opened no chunk (trigger disabled or routine paused?)")
        except Exception as e:  # network or instance hiccup right after resume
            print("poll failed:", e, flush=True)
        time.sleep(30)
    sys.exit("a chunk is still open after an hour; giving up")


if __name__ == "__main__":
    main()
