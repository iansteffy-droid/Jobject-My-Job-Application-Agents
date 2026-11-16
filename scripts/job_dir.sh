#!/usr/bin/env bash
# Print the folder of a job issue, e.g. scripts/job_dir.sh JOB-7 -> /home/.../jobs/examplecorp_senior-...
# The `.ticket` file inside each folder is the source of truth. Folders move to applied/, rejected/ or
# finished/ and are renamed if the company or position text changes (scripts/sync_folders.py), so
# agents always look their folder up by ticket in the same run instead of trusting a path written earlier.
set -euo pipefail
t="${1:?usage: job_dir.sh JOB-N}"
JOBS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/jobs"
for f in "$JOBS"/*/.ticket "$JOBS"/{applied,rejected,finished}/*/.ticket; do
  [ -f "$f" ] && [ "$(tr -d '[:space:]' < "$f")" = "$t" ] && { dirname "$f"; exit 0; }
done
echo "no folder for $t" >&2; exit 1
