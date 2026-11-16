#!/usr/bin/env bash
# Start the "Full refresh" routine now: the same as the "Sync now" button on the Paperclip Dashboard.
# The Coordinator syncs the whole sheet (new rows, colours, deleted rows, Fit sort, folders), checks
# the candidate's documents and CVs for changes and has letters re-checked when they changed (Coordinator §E).
# The routine has no schedule; it runs only when started here or by the button.
#
# Usage: scripts/sync-now.sh
set -euo pipefail

API="http://127.0.0.1:3300/api"
TITLE="Full refresh"

cid="$(curl -sf "$API/companies" | jq -r '.[] | select(.issuePrefix=="JOB") | .id' | head -n1)" \
  || { echo "instance not reachable (scripts/instance.sh status)" >&2; exit 1; }
rid="$(curl -sf "$API/companies/$cid/routines" | jq -r --arg t "$TITLE" '.[] | select(.title==$t) | .id' | head -n1)"
[ -n "$rid" ] || { echo "routine \"$TITLE\" missing: run scripts/provision.sh" >&2; exit 1; }

curl -sf -X POST -H 'Content-Type: application/json' -d '{"source":"manual"}' "$API/routines/$rid/run" >/dev/null \
  || { echo "could not start the routine" >&2; exit 1; }
echo "Full refresh started. Follow it at http://127.0.0.1:3300/JOB/issues (newest 'Full refresh' issue)."
