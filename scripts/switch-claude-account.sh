#!/usr/bin/env bash
# Switch the Claude account all job-hunt agents run on.
#
# Usage: switch-claude-account.sh <config-dir>
#   <config-dir>  a Claude config directory, e.g. ~/.claude (default login) or
#                 ~/.claude-jobhunt (a separate account). It is created and logged in if needed.
#
# Steps: log the directory in if it is not yet, verify a headless run works, write it to
# config/claude-account.env, restart the instance. Tickets, history and documents live in
# Paperclip's database and this repo, so nothing is lost by switching.
#
# After switching: run /mcp in a Claude Code session on the NEW account and connect
# "claude.ai Google Sheets" (with the candidate's Google account) — the agents read and write the
# job sheet through that connector, and connectors belong to the Claude account.
set -euo pipefail

JH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIR="${1:-}"
[ -n "$DIR" ] || { sed -n '2,15p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 2; }
DIR="$(realpath -m "${DIR/#\~/$HOME}")"
mkdir -p "$DIR"

check() { env -u ANTHROPIC_API_KEY CLAUDE_CONFIG_DIR="$DIR" claude -p "reply with ok" --max-turns 1 >/dev/null 2>&1; }

if ! check; then
  echo "Not logged in at $DIR. Starting claude login (choose the subscription account)..."
  env -u ANTHROPIC_API_KEY CLAUDE_CONFIG_DIR="$DIR" claude login
  check || { echo "headless check still fails for $DIR" >&2; exit 1; }
fi
echo "login ok: $DIR"

# Store $HOME-relative when possible so the file stays readable.
stored="$DIR"; case "$DIR" in "$HOME"/*) stored="\$HOME/${DIR#"$HOME"/}" ;; "$HOME") stored="\$HOME" ;; esac
sed -i "s|^CLAUDE_CONFIG_DIR=.*|CLAUDE_CONFIG_DIR=\"$stored\"|" "$JH_DIR/config/claude-account.env"
grep '^CLAUDE_CONFIG_DIR=' "$JH_DIR/config/claude-account.env"

"$JH_DIR/scripts/instance.sh" restart
echo
echo "Done. Last step: in a Claude Code session on this account run /mcp and connect"
echo "\"claude.ai Google Sheets\" so the agents can reach the job sheet."
