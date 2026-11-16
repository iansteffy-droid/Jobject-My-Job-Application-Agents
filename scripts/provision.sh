#!/usr/bin/env bash
# Create or update the Job Hunt company's agents and the sheet-sync routine on the job-hunt
# instance. Idempotent: existing agents (matched by name) get their adapter config refreshed;
# nothing is created twice. Writes agents/_shared/roster.json (agent folder -> id) for the agents.
#
# Usage: scripts/provision.sh            (instance must be running: scripts/instance.sh start)
set -euo pipefail
JH="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
API="$("$JH/scripts/instance.sh" url)"
COMPANY_NAME="Job Hunt"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
curl -sf "$API/api/health" >/dev/null || { echo "instance not running at $API" >&2; exit 1; }

req() { # method path [json-body]
  local out code; out="$TMP/resp"
  if [ $# -ge 3 ]; then printf '%s' "$3" > "$TMP/body"
    code="$(curl -sS -X "$1" -o "$out" -w '%{http_code}' -H 'content-type: application/json' -d @"$TMP/body" "$API$2")"
  else code="$(curl -sS -X "$1" -o "$out" -w '%{http_code}' "$API$2")"; fi
  case "$code" in 2??) cat "$out" ;; *) echo "$1 $2: HTTP $code: $(head -c 800 "$out")" >&2; return 1 ;; esac
}

CID="$(req GET /api/companies | jq -r --arg n "$COMPANY_NAME" '.[]|select(.name==$n)|.id' | head -n1)"
if [ -z "$CID" ]; then
  CID="$(req POST /api/companies "$(jq -nc --arg n "$COMPANY_NAME" '{name:$n, description:"Rates job postings from the job sheet and drafts cover letters for the candidate."}')" | jq -r .id)"
  echo "created company $CID"
fi

# dir | name | role | model | timeoutSec | maxTurns
ROSTER="coordinator|Coordinator|pm|sonnet|1200|80
intake|Intake|researcher|sonnet|900|60
researcher|Researcher|researcher|sonnet|1200|80
fit-scorer|Fit Scorer|general|opus|900|50
letter-strategist|Letter Strategist|general|opus|900|50
letter-writer|Letter Writer|general|opus|1200|80
fact-checker|Fact-checker|qa|opus|900|60
proofreader|Proofreader|qa|sonnet|900|50"

agents="$(req GET "/api/companies/$CID/agents")"
echo '{}' > "$TMP/roster.json"
while IFS='|' read -r dir name role model timeout turns; do
  # No blanket permission bypass: each role gets an explicit allowlist (config/claude-settings/<dir>.json):
  # read anything, write only under jobs/, run only its own scripts; only the Coordinator writes the sheet.
  cfg="$(jq -nc --arg dir "$dir" --arg m "$model" --arg cwd "$JH" --arg f "$JH/agents/$dir/AGENTS.md" --arg root "$JH/agents/$dir" \
    --argjson t "$timeout" --argjson n "$turns" \
    '{model:$m, cwd:$cwd, instructionsFilePath:$f, instructionsBundleMode:"external", instructionsRootPath:$root,
      timeoutSec:$t, maxTurnsPerRun:$n, dangerouslySkipPermissions:false,
      extraArgs:["--settings", ($cwd + "/config/claude-settings/" + $dir + ".json")]}')"
  id="$(jq -r --arg n "$name" '[.[]|select(.name==$n)][0].id // empty' <<<"$agents")"
  if [ -z "$id" ]; then
    id="$(req POST "/api/companies/$CID/agents" "$(jq -nc --arg n "$name" --arg r "$role" --argjson c "$cfg" \
      '{name:$n, role:$r, title:$n, adapterType:"claude_local", adapterConfig:$c, desiredSkills:["paperclip"]}')" | jq -r .id)"
    echo "created agent $name ($id)"
  else
    req PATCH "/api/agents/$id" "$(jq -nc --argjson c "$cfg" '{adapterConfig:$c}')" >/dev/null
    echo "updated agent $name ($id)"
  fi
  # One run at a time per agent (the Coordinator shares sheet + body files between runs); no timer heartbeats.
  req PATCH "/api/agents/$id" '{"runtimeConfig":{"heartbeat":{"enabled":false,"maxConcurrentRuns":1}}}' >/dev/null
  jq --arg d "$dir" --arg i "$id" '.[$d]=$i' "$TMP/roster.json" > "$TMP/r2" && mv "$TMP/r2" "$TMP/roster.json"
done <<<"$ROSTER"
jq . "$TMP/roster.json" > "$JH/agents/_shared/roster.json"
echo "wrote agents/_shared/roster.json"

# Everyone reports to the Coordinator (org chart only).
COORD="$(jq -r .coordinator "$JH/agents/_shared/roster.json")"
for id in $(jq -r 'to_entries[]|select(.key!="coordinator")|.value' "$JH/agents/_shared/roster.json"); do
  req PATCH "/api/agents/$id" "$(jq -nc --arg m "$COORD" '{reportsTo:$m}')" >/dev/null
done

# Sheet-sync routine: hourly, 07:00-22:00 Europe/Berlin.
TITLE="Sync job sheet"
rid="$(req GET "/api/companies/$CID/routines" | jq -r --arg t "$TITLE" '.[]|select(.title==$t)|.id' | head -n1)"
if [ -z "$rid" ]; then
  rid="$(req POST "/api/companies/$CID/routines" "$(jq -nc --arg a "$COORD" --arg t "$TITLE" \
    '{title:$t, assigneeAgentId:$a, priority:"medium", concurrencyPolicy:"coalesce_if_active", catchUpPolicy:"skip_missed",
      description:"Sheet sync (Coordinator instructions, section A): read the job tab (documents/job-preferences.md §Sheet), open issues for new job rows (max 3 per run, max 5 open), and report."}')" | jq -r .id)"
  req POST "/api/routines/$rid/triggers" '{"kind":"schedule","label":"hourly, daytime","cronExpression":"0 7-22 * * *","timezone":"Europe/Berlin"}' >/dev/null
  echo "created routine $TITLE ($rid)"
else
  echo "routine $TITLE exists ($rid)"
fi
for tid in $(req GET "/api/routines/$rid" | jq -r '.triggers[]? | select(.kind=="schedule") | .id'); do
  req PATCH "/api/routine-triggers/$tid" '{"label":"hourly, daytime","cronExpression":"0 7-22 * * *","timezone":"Europe/Berlin"}' >/dev/null
done

# Full-refresh routine: NO schedule. It stays idle until the candidate presses "Sync now" on the Dashboard
# (plugins/sync-button) or runs scripts/sync-now.sh.
FTITLE="Full refresh"
fid="$(req GET "/api/companies/$CID/routines" | jq -r --arg t "$FTITLE" '.[]|select(.title==$t)|.id' | head -n1)"
if [ -z "$fid" ]; then
  fid="$(req POST "/api/companies/$CID/routines" "$(jq -nc --arg a "$COORD" --arg t "$FTITLE" \
    '{title:$t, assigneeAgentId:$a, priority:"high", concurrencyPolicy:"coalesce_if_active", catchUpPolicy:"skip_missed",
      description:"Full refresh (Coordinator instructions, section E): full sheet sync, check the candidate'"'"'s documents and CVs for changes, re-check letters affected by changed documents, report."}')" | jq -r .id)"
  echo "created routine $FTITLE ($fid)"
else
  echo "routine $FTITLE exists ($fid)"
fi
echo "company $CID ready: $API"
