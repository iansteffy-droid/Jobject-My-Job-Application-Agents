#!/usr/bin/env bash
# Start the "Sync job sheet" routine now instead of waiting for the next hourly run.
# The Coordinator goes through the job tab (Coordinator §A): opens issues for new rows (they then get
# intake, research and a fit score), fills Location / Lang req / Remote, syncs the stage and agent columns,
# handles rows moved to the applied / rejected tabs, and re-sorts the tab by fit.
# Lighter than scripts/sync-now.sh, which also checks the candidate's documents for changes.
#
# Usage: scripts/sync-spreadsheet.sh
set -euo pipefail

API="http://127.0.0.1:3300/api"
TITLE="Sync job sheet"

cid="$(curl -sf "$API/companies" | jq -r '.[] | select(.issuePrefix=="JOB") | .id' | head -n1)" \
  || { echo "instance not reachable (scripts/instance.sh status)" >&2; exit 1; }
rid="$(curl -sf "$API/companies/$cid/routines" | jq -r --arg t "$TITLE" '.[] | select(.title==$t) | .id' | head -n1)"
[ -n "$rid" ] || { echo "routine \"$TITLE\" missing: run scripts/provision.sh" >&2; exit 1; }

curl -sf -X POST -H 'Content-Type: application/json' -d '{"source":"manual"}' "$API/routines/$rid/run" >/dev/null \
  || { echo "could not start the routine" >&2; exit 1; }
echo "Sheet sync started. Follow it at http://127.0.0.1:3300/JOB/issues (newest 'Sync job sheet' issue)."
