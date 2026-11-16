#!/usr/bin/env bash
# Start the "Find jobs" routine now: the same as the "Find jobs" button on the Paperclip Dashboard.
# The Job Scout finds one chunk of new jobs for the scout tab and the Job Reviewer checks it. Started
# several times, the chunks queue and run one after another (scripts/scout.py start / finish).
#
# Usage: scripts/find-jobs.sh
set -euo pipefail

API="http://127.0.0.1:3300/api"
TITLE="Find jobs"

cid="$(curl -sf "$API/companies" | jq -r '.[] | select(.issuePrefix=="JOB") | .id' | head -n1)" \
  || { echo "instance not reachable (scripts/instance.sh status)" >&2; exit 1; }
rid="$(curl -sf "$API/companies/$cid/routines" | jq -r --arg t "$TITLE" '.[] | select(.title==$t) | .id' | head -n1)"
[ -n "$rid" ] || { echo "routine \"$TITLE\" missing: run scripts/provision.sh" >&2; exit 1; }

curl -sf -X POST -H 'Content-Type: application/json' -d '{"source":"manual"}' "$API/routines/$rid/run" >/dev/null \
  || { echo "could not start the routine" >&2; exit 1; }
echo "Job search started. Follow it at http://127.0.0.1:3300/JOB/issues (newest 'Find jobs' issue)."
