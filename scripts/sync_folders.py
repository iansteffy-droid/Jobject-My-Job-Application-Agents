#!/usr/bin/env python3
"""Keep the job folders in step with the job sheet: open jobs in jobs/<company>_<position>/, moved or
finished jobs in jobs/applied/, jobs/rejected/, jobs/finished/.

Usage: python3 -I scripts/sync_folders.py <rows.json>

rows.json (written by the Coordinator from the sheet, one entry per row that has a ticket in column R):
  [{"ticket": "JOB-7", "row": 6, "position": "Senior Software Engineer (m/f/d)", "company": "ExampleCorp", "busy": false}, ...]
  busy = true while an agent is working on the issue (status in_progress): its folder is not renamed
  this time, so no agent loses its paths mid-run.
  A job whose row the candidate moved to the applied or rejected tab gets an entry without a row:
  {"ticket": "JOB-9", "moved": "applied"} or {"ticket": "JOB-11", "moved": "rejected"}.

Each job folder holds a `.ticket` file with its issue identifier; that is how folders are matched,
never by name. Rules:
  - folder name = <company slug>_<position slug>, e.g. examplecorp_senior-software-engineer-m-f-d.
    It carries no row number and stays the same for the life of the job: moving or sorting rows never
    renames a folder. Only a change of the company or position text itself renames it.
  - name collision (same company + position twice, e.g. a duplicate row) -> append -JOB-N
  - a "moved" entry -> folder moves to jobs/applied/ or jobs/rejected/ (also out of jobs/finished/)
  - a ticket that no longer appears in the sheet (row deleted) -> folder moves to jobs/finished/
  - a folder is never moved onto an existing one
Prints one JSON object: {"renamed": [[ticket, old, new]...], "applied": [...], "rejected": [...],
"finished": [[ticket, old, new]...], "skipped_busy": [...], "skipped_recent": [...]}
"""
import json
import re
import sys
import time
import unicodedata
from pathlib import Path

JOBS = Path(__file__).resolve().parent.parent / "jobs"
FINISHED = JOBS / "finished"
MOVED = {"applied": JOBS / "applied", "rejected": JOBS / "rejected"}
LEGACY_ROW = re.compile(r"^\d{3}-")  # old <row>-<position>_<company> names


def slug(text, limit=60):
    text = text.lower().replace("ä", "ae").replace("ö", "oe").replace("ü", "ue").replace("ß", "ss")
    text = unicodedata.normalize("NFKD", text).encode("ascii", "ignore").decode()
    return re.sub(r"[^a-z0-9]+", "-", text).strip("-")[:limit].strip("-") or "job"


def folder_name(company, position):
    return f"{slug(company or '', 25)}_{slug(position or '', 50)}".strip("_")


def ticket_folders(base):
    out = {}
    for d in sorted(p for p in base.iterdir() if p.is_dir() and p.name not in ("finished", "applied", "rejected") and not p.name.startswith(".")):
        t = d / ".ticket"
        if t.exists():
            out[t.read_text().strip()] = d
    return out


def free_name(base, name, ticket, current=None):
    """base/name, or base/name-JOB-N if another folder holds that name; never an existing folder."""
    for cand in [base / name, base / f"{name}-{ticket}"] + [base / f"{name}-{ticket}-{n}" for n in range(2, 100)]:
        if cand == current or not cand.exists():
            return cand
    raise SystemExit(f"no free folder name for {ticket} in {base}")


def main():
    if len(sys.argv) != 2:
        print(__doc__, file=sys.stderr)
        return 2
    entries = json.loads(Path(sys.argv[1]).read_text())
    moved = {r["ticket"]: r["moved"] for r in entries if r.get("moved") in MOVED}
    rows = {r["ticket"]: r for r in entries if r["ticket"] not in moved}
    FINISHED.mkdir(exist_ok=True)
    for d in MOVED.values():
        d.mkdir(exist_ok=True)
    result = {"renamed": [], "applied": [], "rejected": [], "finished": [], "skipped_busy": [], "skipped_recent": []}
    open_folders = ticket_folders(JOBS)
    finished_folders = ticket_folders(FINISHED)

    def move(ticket, folder, dest, key):
        folder.rename(dest)
        result[key].append([ticket, str(folder.relative_to(JOBS.parent)), str(dest.relative_to(JOBS.parent))])

    for ticket, where in moved.items():
        # The candidate moved the row on purpose: no busy/recent safety, and pull it out of finished/ too.
        folder = open_folders.pop(ticket, None) or finished_folders.get(ticket)
        if folder is not None:
            move(ticket, folder, free_name(MOVED[where], LEGACY_ROW.sub("", folder.name), ticket), where)
    for ticket, folder in open_folders.items():
        row = rows.get(ticket)
        if row is None:
            # Safety: a folder touched in the last 30 minutes belongs to live work (e.g. a job opened
            # after rows.json was written); never finish it on this run.
            newest = max([folder.stat().st_mtime] + [f.stat().st_mtime for f in folder.rglob("*")])
            if time.time() - newest < 1800:
                result["skipped_recent"].append(ticket)
                continue
            move(ticket, folder, free_name(FINISHED, LEGACY_ROW.sub("", folder.name), ticket), "finished")
            continue
        want = folder_name(row.get("company"), row.get("position"))
        if folder.name in (want, f"{want}-{ticket}"):
            continue  # same company + position text: the folder keeps its name, whatever the row number
        if row.get("busy"):
            result["skipped_busy"].append(ticket)
            continue
        dest = free_name(JOBS, want, ticket, current=folder)
        if dest != folder:
            move(ticket, folder, dest, "renamed")
    print(json.dumps(result, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())
