#!/usr/bin/env bash
# Operator tool: watch job issues until each is back with the candidate, and restart stuck ones.
#
# Usage: scripts/watch-jobs.sh [JOB-N ...]     (no arguments: every open job issue)
# Env:   STALL_MIN=10  minutes without an agent run before a todo/in_progress issue counts as stuck
#        MAX_KICKS=3   restarts per issue before it is left for the operator
#        POLL=60       seconds between checks;  MAX_HOURS=8  give up after this long
#        DRY_RUN=1     only report what would be restarted
#        (Claude usage limit: no restarts within 15 min of a usage-limit failure; later ones are uncounted probes)
#        UNTIL=letters an issue counts as back only when it is in_review AND scripts/check_final.sh passes
#                      (use after accepting "write a letter?" cards: they sit in_review with the Coordinator first)
#
# Stuck means: status blocked, OR status todo/in_progress with no queued/running/retrying heartbeat run
# for that issue and no update for STALL_MIN minutes (an agent can end a run without handing off,
# e.g. after wrongly concluding that Bash is denied). A restart resets the assignee's saved session for
# that issue (so it cannot resume a wrong belief), posts a comment and sets the issue to todo.
# Done when every watched issue is in_review (with UNTIL=letters: in_review and final letters pass), done or
# cancelled. Never runs a sync or find-jobs.
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
  runs="$(curl -sf "$API/companies/$CID/heartbeat-runs?limit=200")"
  active="$(jq -r '.[] | select(.status=="queued" or .status=="running" or .status=="scheduled_retry")
    | .contextSnapshot.issueId // empty' <<<"$runs")"
  # Claude usage limit: restarts while it lasts would only burn MAX_KICKS. If the newest finished run failed on
  # it less than 15 min ago, wait; if longer ago, restart as a probe that does not count against MAX_KICKS.
  probe=""
  lim="$(jq -r '[.[] | select(.status=="failed" or .status=="succeeded")] | sort_by(.createdAt) | last
      | select(.status=="failed" and ((.error // "") | test("usage|spend limit|429"; "i"))) | .createdAt' <<<"$runs")"
  if [ -n "$lim" ]; then
    if [ $(( ($(date +%s) - $(date -d "$lim" +%s)) / 60 )) -lt 15 ]; then
      [ -n "${limited:-}" ] || echo "$(date +%H:%M) Claude usage limit reached: waiting, no restarts until it resets"
      limited=1
      [ "$(date +%s)" -ge "$deadline" ] && { echo "$(date +%H:%M) TIMEOUT during usage limit"; exit 1; }
      sleep "$POLL"; continue
    fi
    probe=1
  fi
  [ -n "${limited:-}" ] && { echo "$(date +%H:%M) usage limit may be over: restarting as a probe"; limited=""; }
  waiting=0; now=$(date +%s)
  for j in $JOBS; do
    read -r id st ag upd <<<"$(curl -sf "$API/issues/$j" | jq -r '"\(.id) \(.status) \(.assigneeAgentId) \(.updatedAt)"')"
    case "$st" in done|cancelled) continue;; esac
    if [ "$st" = in_review ]; then
      [ "${UNTIL:-}" = letters ] || continue
      "$JH/scripts/check_final.sh" "$j" >/dev/null 2>&1 && continue
    fi
    [ "$ag" = null ] && continue  # unassigned: nobody to restart, not a pipeline job
    waiting=$((waiting+1))
    why=""
    if [ "$st" = blocked ]; then
      why="blocked"
    elif ! grep -qx "$id" <<<"$active"; then
      age=$(( (now - $(date -d "$upd" +%s)) / 60 ))
      [ "$age" -ge "$STALL_MIN" ] && why="$st for ${age} min with no agent run"
      [ "$st" = in_review ] && [ -n "$why" ] && why="$why, letters not final yet"
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
    [ -n "$probe" ] || kicks[$j]=$((c+1))
    echo "$(date +%H:%M) restarted $j ($why)${probe:+ [usage-limit probe, not counted]}, restart ${kicks[$j]:-0}/$MAX_KICKS"
  done
  [ "$waiting" = 0 ] && { echo "$(date +%H:%M) ALL BACK"; exit 0; }
  [ "$(date +%s)" -ge "$deadline" ] && { echo "$(date +%H:%M) TIMEOUT, $waiting still open"; exit 1; }
  sleep "$POLL"
done
