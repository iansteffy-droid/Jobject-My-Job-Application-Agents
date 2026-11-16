#!/usr/bin/env bash
# Print the folder of a job issue, e.g. scripts/job_dir.sh JOB-7 -> /home/.../jobs/006-senior-...
# Folders are renamed when the sheet rows move (scripts/sync_folders.py), so agents always look
# their folder up by ticket instead of trusting a path written earlier.
set -euo pipefail
t="${1:?usage: job_dir.sh JOB-N}"
JOBS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/jobs"
for f in "$JOBS"/*/.ticket "$JOBS"/{applied,rejected,finished}/*/.ticket; do
  [ -f "$f" ] && [ "$(tr -d '[:space:]' < "$f")" = "$t" ] && { dirname "$f"; exit 0; }
done
echo "no folder for $t" >&2; exit 1
