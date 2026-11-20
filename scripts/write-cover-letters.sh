#!/usr/bin/env bash
# Operator command "write-cover-letters": start the letters for every open job that is waiting on its
# "write a cover letter?" card and is either rated Strong fit or named on the command line.
#
# Usage: scripts/write-cover-letters.sh [JOB-N ...]
#   JOB-N ...  extra jobs to write letters for, whatever their verdict (the candidate's marks on the sheet:
#              "letter" in column A "aktn?", or "write the letter" in Agent: Stage; the operator reads the
#              sheet and passes those tickets here, because scripts have no sheet access).
#
# Accepting the card is the candidate's "yes": the Coordinator then runs the letter pipeline (strategist,
# writer, fact-checker, proofreader; one letter per job, German and English). The verdict comes from
# the Fit Scorer's latest "Fit x/10 — <verdict>:" comment, not from the card text. Nothing is ever submitted.
# Follow the letters with: UNTIL=letters scripts/watch-jobs.sh <the accepted JOB-Ns>
set -uo pipefail

JH="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
API="${PAPERCLIP_API:-http://127.0.0.1:3300}/api"
CID="$(curl -sf "$API/companies" | jq -r '.[0].id')"
J='Content-Type: application/json'
MARKED=" $* "

accepted=()
for j in $(curl -sf "$API/companies/$CID/issues?limit=500" | jq -r '.[]
    | select(.status=="in_review" and .originKind!="routine_execution") | .identifier'); do
  id="$(curl -sf "$API/issues/$j" | jq -r .id)"
  card="$(curl -sf "$API/issues/$id/interactions" | jq -r '[.[] | select(.status=="pending" and .kind=="request_confirmation")] | .[-1].id // empty')"
  [ -n "$card" ] || continue
  verdict="$(curl -sf "$API/issues/$id/comments" | jq -r '[sort_by(.createdAt)[] | .body
    | capture("^Fit [0-9.]+/10 — (?<v>[A-Za-z ]+?)[:(]") | .v] | .[-1] // "unrated"')"
  why=""
  [ "$verdict" = "Strong fit" ] && why="Strong fit"
  [[ "$MARKED" == *" $j "* ]] && why="${why:+$why, }marked by the candidate"
  if [ -z "$why" ]; then echo "skip     $j ($verdict)"; continue; fi
  r="$(curl -sf -X POST -H "$J" -d '{}' "$API/issues/$id/interactions/$card/accept" | jq -r '.status // "error"')"
  echo "$r $j ($why)"; [ "$r" = accepted ] && accepted+=("$j")
done
for m in $*; do
  [[ " ${accepted[*]} " == *" $m "* ]] || echo "note     $m was marked but has no open 'write a cover letter?' card (not rated yet, or letters already started)"
done
echo "started: ${accepted[*]:-none}"
