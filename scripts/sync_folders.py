#!/usr/bin/env python3
"""Keep the job folders named after the job sheet: <row>-<position>_<company>, finished jobs in jobs/finished/.

Usage: python3 -I scripts/sync_folders.py <rows.json>

rows.json (written by the Coordinator from the sheet, one entry per row that has a ticket in column R):
  [{"ticket": "JOB-7", "row": 6, "position": "Senior Software Engineer (m/f/d)", "company": "ExampleCorp", "busy": false}, ...]
  busy = true while an agent is working on the issue (status in_progress): its folder is not renamed
  this time, so no agent loses its paths mid-run.

Each job folder holds a `.ticket` file with its issue identifier; that is how folders are matched,
never by name. Rules:
  - folder name = <row, 3 digits>-<position slug>_<company slug>,
    e.g. 006-senior-software-engineer-m-f-d_examplecorp
  - a ticket that no longer appears in the sheet (row deleted) -> folder moves to jobs/finished/
Prints one JSON object: {"renamed": [[ticket, old, new]...], "finished": [[ticket, old, new]...], "skipped_busy": [...]}
"""
import json
import re
import sys
import time
import unicodedata
from pathlib import Path

JOBS = Path(__file__).resolve().parent.parent / "jobs"
FINISHED = JOBS / "finished"


def slug(text, limit=60):
    text = text.lower().replace("ä", "ae").replace("ö", "oe").replace("ü", "ue").replace("ß", "ss")
    text = unicodedata.normalize("NFKD", text).encode("ascii", "ignore").decode()
    return re.sub(r"[^a-z0-9]+", "-", text).strip("-")[:limit].strip("-") or "job"


def ticket_folders(base):
    out = {}
    for d in sorted(p for p in base.iterdir() if p.is_dir() and p.name != "finished" and not p.name.startswith(".")):
        t = d / ".ticket"
        if t.exists():
            out[t.read_text().strip()] = d
    return out


def free_name(base, name, current=None):
    cand, n = base / name, 2
    while cand.exists() and cand != current:
        cand, n = base / f"{name}-{n}", n + 1
    return cand


def main():
    if len(sys.argv) != 2:
        print(__doc__, file=sys.stderr)
        return 2
    rows = {r["ticket"]: r for r in json.loads(Path(sys.argv[1]).read_text())}
    FINISHED.mkdir(exist_ok=True)
    result = {"renamed": [], "finished": [], "skipped_busy": [], "skipped_recent": []}
    for ticket, folder in ticket_folders(JOBS).items():
        row = rows.get(ticket)
        if row is None:
            # Safety: a folder touched in the last 30 minutes belongs to live work (e.g. a job opened
            # after rows.json was written); never finish it on this run.
            newest = max([folder.stat().st_mtime] + [f.stat().st_mtime for f in folder.rglob("*")])
            if time.time() - newest < 1800:
                result["skipped_recent"].append(ticket)
                continue
            # The row number means nothing once the row is gone: keep only the position part.
            dest = free_name(FINISHED, re.sub(r"^\d{3}-", "", folder.name))
            folder.rename(dest)
            result["finished"].append([ticket, str(folder.relative_to(JOBS.parent)), str(dest.relative_to(JOBS.parent))])
            continue
        want = f"{int(row['row']):03d}-{slug(row['position'], 50)}_{slug(row.get('company', ''), 25)}".rstrip("_")
        if folder.name == want:
            continue
        if row.get("busy"):
            result["skipped_busy"].append(ticket)
            continue
        dest = free_name(JOBS, want, current=folder)
        if dest != folder:
            folder.rename(dest)
            result["renamed"].append([ticket, str(folder.relative_to(JOBS.parent)), str(dest.relative_to(JOBS.parent))])
    print(json.dumps(result, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())
