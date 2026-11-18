#!/usr/bin/env bash
# Operator tool: watch job issues until each is back with the candidate, and restart stuck ones.
#
# Usage: scripts/watch-jobs.sh [JOB-N ...]     (no arguments: every open job issue)
# Env:   STALL_MIN=10  minutes without an agent run before a todo/in_progress issue counts as stuck
#        MAX_KICKS=3   restarts per issue before it is left for the operator
#        POLL=60       seconds between checks;  MAX_HOURS=8  give up after this long
#        DRY_RUN=1     only report what would be restarted
#
# Stuck means: status blocked, OR status todo/in_progress with no queued/running/retrying heartbeat run
# for that issue and no update for STALL_MIN minutes (an agent can end a run without handing off,
# e.g. after wrongly concluding that Bash is denied). A restart resets the assignee's saved session for
# that issue (so it cannot resume a wrong belief), posts a comment and sets the issue to todo.
# Done when every watched issue is in_review, done or cancelled. Never runs a sync or find-jobs.
set -uo pipefail

JH="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
API="${PAPERCLIP_API:-http://127.0.0.1:3300}/api"
CID="$(jq -r .companyId "$JH/agents/_shared/roster.json" 2>/dev/null)"
[ -n "$CID" ] && [ "$CID" != null ] || CID="$(curl -sf "$API/companies" | jq -r '.[0].id')"
STALL_MIN="${STALL_MIN:-10}"; MAX_KICKS="${MAX_KICKS:-3}"; POLL="${POLL:-60}"; MAX_HOURS="${MAX_HOURS:-8}"
J='Content-Type: application/json'

if [ $# -gt 0 ]; then
  JOBS="$*"
else
  JOBS="$(curl -sf "$API/companies/$CID/issues?limit=500" | jq -r '.[]
    | select(.status=="todo" or .status=="in_progress" or .status=="blocked")
    | select(.originKind != "routine_execution" and .assigneeAgentId != null) | .identifier')"
fi
[ -n "$JOBS" ] || { echo "nothing to watch"; exit 0; }
echo "$(date +%H:%M) watching: $(echo $JOBS)"

declare -A kicks
deadline=$(( $(date +%s) + MAX_HOURS * 3600 ))
while :; do
  active="$(curl -sf "$API/companies/$CID/heartbeat-runs?limit=200" | jq -r '.[]
    | select(.status=="queued" or .status=="running" or .status=="scheduled_retry")
    | .contextSnapshot.issueId // empty')"
  waiting=0; now=$(date +%s)
  for j in $JOBS; do
    read -r id st ag upd <<<"$(curl -sf "$API/issues/$j" | jq -r '"\(.id) \(.status) \(.assigneeAgentId) \(.updatedAt)"')"
    case "$st" in in_review|done|cancelled) continue;; esac
    [ "$ag" = null ] && continue  # unassigned: nobody to restart, not a pipeline job
    waiting=$((waiting+1))
    why=""
    if [ "$st" = blocked ]; then
      why="blocked"
    elif ! grep -qx "$id" <<<"$active"; then
      age=$(( (now - $(date -d "$upd" +%s)) / 60 ))
      [ "$age" -ge "$STALL_MIN" ] && why="$st for ${age} min with no agent run"
    fi
    [ -n "$why" ] || continue
    c=${kicks[$j]:-0}
    if [ "$c" -ge "$MAX_KICKS" ]; then
      echo "$(date +%H:%M) $j STILL STUCK ($why) after $c restarts: needs the operator"; continue
    fi
    [ -n "${DRY_RUN:-}" ] && { echo "$(date +%H:%M) would restart $j ($why)"; continue; }
    curl -sf -X POST -H "$J" -d "{\"taskKey\":\"$id\"}" "$API/agents/$ag/runtime-state/reset-session" >/dev/null
    curl -sf -X POST -H "$J" -d "$(jq -nc --arg w "$why" '{body:("Operator restart (" + $w + "). Start fresh from the issue comments. Bash works: if a command was denied, only that form is off; rewrite it as one plain command (WORKFLOW.md), never stop. Continue the work and hand off as usual.")}')" "$API/issues/$id/comments" >/dev/null
    curl -sf -X PATCH -H "$J" -d "{\"assigneeAgentId\":\"$ag\",\"status\":\"todo\"}" "$API/issues/$id" >/dev/null
    kicks[$j]=$((c+1)); echo "$(date +%H:%M) restarted $j ($why), restart ${kicks[$j]}/$MAX_KICKS"
  done
  [ "$waiting" = 0 ] && { echo "$(date +%H:%M) ALL BACK"; exit 0; }
  [ "$(date +%s)" -ge "$deadline" ] && { echo "$(date +%H:%M) TIMEOUT, $waiting still open"; exit 1; }
  sleep "$POLL"
done
