#!/usr/bin/env bash
# The job-hunt Paperclip instance: own ports, own data dir, isolated from every other instance.
#
# Usage: instance.sh {start|stop|restart|status|url}
# Fixed: instance job-hunt, port 3300, db port 54332, data under ~/.paperclip/instances/job-hunt.
#
# The Claude account every agent runs on is set in ONE place: config/claude-account.env
# (CLAUDE_CONFIG_DIR). It is exported into the server process; the claude_local adapter passes
# the server environment through to every agent run. Switch accounts with
# scripts/switch-claude-account.sh, never per agent.
#
# Start path: the dev runner (`pnpm dev:once` in paperclip/) with PAPERCLIP_CONFIG + PORT set.
# Stop: SIGTERM exactly the process group we started, then this instance's embedded Postgres.
# Never touches ~/.paperclip/instances/default, paperclip-enterprise, or ports 3100/3200.
set -euo pipefail

JH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTANCE="job-hunt"
PORT=3300
DB_PORT=54332
cmd="${1:-}"

ACCOUNT_ENV="$JH_DIR/config/claude-account.env"
[ -f "$ACCOUNT_ENV" ] || { echo "missing $ACCOUNT_ENV" >&2; exit 2; }
# shellcheck source=/dev/null
. "$ACCOUNT_ENV"
[ -n "${CLAUDE_CONFIG_DIR:-}" ] || { echo "CLAUDE_CONFIG_DIR not set in $ACCOUNT_ENV" >&2; exit 2; }
export CLAUDE_CONFIG_DIR
unset ANTHROPIC_API_KEY  # subscription only, never API billing

# Agents get a per-run API identity (PAPERCLIP_API_KEY) only when the server has a JWT secret;
# without it every agent call is recorded as the board user and wakes agents needlessly.
JWT_FILE="$HOME/.paperclip/instances/$INSTANCE/agent-jwt-secret"
if [ ! -s "$JWT_FILE" ]; then
  mkdir -p "$(dirname "$JWT_FILE")"
  (umask 077; head -c 48 /dev/urandom | base64 | tr -d '\n' > "$JWT_FILE")
fi
PAPERCLIP_AGENT_JWT_SECRET="$(cat "$JWT_FILE")"
export PAPERCLIP_AGENT_JWT_SECRET

ROOT="$HOME/.paperclip/instances/$INSTANCE"
CONFIG="$ROOT/config.json"
PIDFILE="$ROOT/instance.pid"
LOGFILE="$ROOT/logs/instance.log"
URL="http://127.0.0.1:$PORT"

healthy() { curl -sf --max-time 3 "$URL/api/health" >/dev/null 2>&1; }
alive() { [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; }

write_config() {
  mkdir -p "$ROOT/logs" "$ROOT/data/backups" "$ROOT/data/storage"
  sed -e "s|__ROOT__|$ROOT|g" -e "s|__PORT__|$PORT|g" -e "s|__DB_PORT__|$DB_PORT|g" \
      -e "s|__NOW__|$(date -u +%Y-%m-%dT%H:%M:%S.000Z)|g" \
      "$JH_DIR/templates/instance/config.template.json" > "$CONFIG"
}

do_start() {
  if [ -f "$CONFIG" ]; then
    local cp cd
    cp="$(jq -r .server.port "$CONFIG")"; cd="$(jq -r .database.embeddedPostgresPort "$CONFIG")"
    if [ "$cp" != "$PORT" ] || [ "$cd" != "$DB_PORT" ]; then
      echo "config $CONFIG has port=$cp db-port=$cd but flags say port=$PORT db-port=$DB_PORT; edit or remove the config to change them" >&2
      exit 2
    fi
  fi
  if alive; then
    echo "already running (pid $(cat "$PIDFILE")) at $URL (account dir $CLAUDE_CONFIG_DIR)"
    return 0
  fi
  [ -f "$CONFIG" ] || write_config
  mkdir -p "$ROOT/logs"
  (
    cd "$JH_DIR/paperclip"
    PAPERCLIP_INSTANCE_ID="$INSTANCE" PAPERCLIP_CONFIG="$CONFIG" PORT="$PORT" \
      setsid nohup pnpm dev:once >"$LOGFILE" 2>&1 </dev/null &
    echo $! >"$PIDFILE"
  )
  local i
  for i in $(seq 1 "${PAPERCLIP_INSTANCE_HEALTH_TIMEOUT:-120}"); do
    if healthy; then echo "started (pid $(cat "$PIDFILE")) at $URL"; return 0; fi
    if ! alive; then echo "server exited during startup; see $LOGFILE" >&2; do_stop; return 1; fi
    sleep 1
  done
  echo "timed out waiting for $URL/api/health; see $LOGFILE" >&2
  do_stop
  return 1
}

pg_pid() {
  local f="$ROOT/db/postmaster.pid"
  [ -f "$f" ] && head -n1 "$f" || true
}

do_stop() {
  local pid i
  if alive; then
    pid="$(cat "$PIDFILE")"
    kill -TERM -- "-$pid" 2>/dev/null || kill -TERM "$pid" 2>/dev/null || true
    for i in $(seq 1 30); do alive || break; sleep 1; done
    if alive; then kill -KILL -- "-$pid" 2>/dev/null || kill -KILL "$pid" 2>/dev/null || true; fi
  fi
  rm -f "$PIDFILE"
  # Embedded Postgres of this instance only (pid taken from its own data dir).
  local pg; pg="$(pg_pid)"
  if [ -n "$pg" ] && kill -0 "$pg" 2>/dev/null; then
    kill -TERM "$pg" 2>/dev/null || true
    for i in $(seq 1 20); do kill -0 "$pg" 2>/dev/null || break; sleep 1; done
  fi
  echo "stopped $INSTANCE"
}

do_status() {
  local state=stopped health=down
  alive && state=running
  healthy && health=ok
  echo "instance=$INSTANCE state=$state health=$health url=$URL claude_config_dir=$CLAUDE_CONFIG_DIR"
  [ "$state" = running ]
}

case "$cmd" in
  start) do_start ;;
  restart) do_stop; do_start ;;
  stop) do_stop ;;
  status) do_status ;;
  url) echo "$URL" ;;
  *) echo "usage: $0 {start|stop|restart|status|url}" >&2; exit 2 ;;
esac
