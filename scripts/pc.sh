#!/usr/bin/env bash
# Paperclip API helper for the job-hunt agents. Agents use this instead of raw curl, because
# their permission allowlist cannot approve commands that expand $PAPERCLIP_* variables.
# It adds the Authorization and X-Paperclip-Run-Id headers from the run environment.
#
# Usage:
#   scripts/pc.sh GET  /api/issues/<id>
#   scripts/pc.sh POST /api/issues/<id>/comments <body.json>     body from a file, or
#   scripts/pc.sh POST /api/issues/<id>/comments <<'EOF'          body from stdin (quoted heredoc)
#   {"body": "..."}
#   EOF
#   scripts/pc.sh env     prints this run's context (agent, company, task, wake reason; no secrets)
set -euo pipefail
: "${PAPERCLIP_API_URL:?PAPERCLIP_API_URL is not set (only available inside an agent run)}"

if [ "${1:-}" = env ]; then
  for v in PAPERCLIP_AGENT_ID PAPERCLIP_COMPANY_ID PAPERCLIP_RUN_ID PAPERCLIP_TASK_ID PAPERCLIP_WAKE_REASON \
           PAPERCLIP_WAKE_COMMENT_ID PAPERCLIP_APPROVAL_ID PAPERCLIP_APPROVAL_STATUS PAPERCLIP_LINKED_ISSUE_IDS; do
    printf '%s=%s\n' "$v" "${!v:-}"
  done
  [ -n "${PAPERCLIP_WAKE_PAYLOAD_JSON:-}" ] && printf 'PAPERCLIP_WAKE_PAYLOAD_JSON=%s\n' "$PAPERCLIP_WAKE_PAYLOAD_JSON"
  exit 0
fi

method="${1:?usage: pc.sh METHOD /api/path [body.json] | pc.sh env}"
path="${2:?usage: pc.sh METHOD /api/path [body.json]}"
case "$path" in /api/*) ;; *) echo "path must start with /api/" >&2; exit 2 ;; esac

# Without the per-run agent key, the local_trusted server would treat the call as the board user (the candidate).
: "${PAPERCLIP_API_KEY:?PAPERCLIP_API_KEY is missing: refusing to call the API as the board user}"
args=(-sS --max-time 60 -X "$method" -H "Accept: application/json" -H "Authorization: Bearer $PAPERCLIP_API_KEY")
[ -n "${PAPERCLIP_RUN_ID:-}" ] && args+=(-H "X-Paperclip-Run-Id: $PAPERCLIP_RUN_ID")
if [ -n "${3:-}" ] && [ "${3:0:1}" = "{" ]; then
  args+=(-H "Content-Type: application/json" --data-binary "$3")   # inline JSON body
elif [ -n "${3:-}" ]; then
  [ -f "$3" ] || { echo "body file not found: $3" >&2; exit 2; }
  args+=(-H "Content-Type: application/json" --data-binary @"$3")
elif [ "$method" != GET ] && [ ! -t 0 ]; then
  args+=(-H "Content-Type: application/json" --data-binary @-)
fi
out="$(mktemp)"; trap 'rm -f "$out"' EXIT
code="$(curl "${args[@]}" -o "$out" -w '%{http_code}' "${PAPERCLIP_API_URL%/}$path")"
cat "$out"; echo
case "$code" in 2??) ;; *) echo "HTTP $code" >&2; exit 1 ;; esac
