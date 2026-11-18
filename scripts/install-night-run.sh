#!/usr/bin/env bash
# Lets the scheduled job search run unattended at night.
#
#   install-night-run.sh autostart   systemd user service: the instance starts with the user's session
#                                    (and at boot, when lingering can be enabled). No root needed.
#   install-night-run.sh wake        system timer (needs sudo): wakes the computer from suspend shortly
#                                    before the "Find jobs" schedule, keeps it awake until the chunk is
#                                    scouted and reviewed, then suspends it again.
#   install-night-run.sh remove      removes both.
#
# WAKE_AT must be a few minutes before the routine's schedule (scripts/provision.sh, find-jobs cron).
# The computer has to be suspended, not shut down: a powered-off or encrypted machine cannot start unattended.
set -euo pipefail

JH="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WAKE_AT="01:55:00"
UNIT_DIR="$HOME/.config/systemd/user"
ROOT_LIB="/usr/local/lib/job-hunt"

autostart() {
  mkdir -p "$UNIT_DIR"
  cat > "$UNIT_DIR/job-hunt.service" <<EOF
[Unit]
Description=Job-hunt Paperclip instance (:3300)
After=network-online.target

[Service]
Type=forking
Environment=PATH=$PATH
ExecStart=$JH/scripts/instance.sh start
ExecStop=$JH/scripts/instance.sh stop
PIDFile=$HOME/.paperclip/instances/job-hunt/instance.pid
TimeoutStartSec=240
TimeoutStopSec=90
Restart=on-failure
RestartSec=30

[Install]
WantedBy=default.target
EOF
  systemctl --user daemon-reload
  systemctl --user enable job-hunt.service
  loginctl enable-linger "$USER" 2>/dev/null || echo "note: lingering not enabled; the instance starts at login instead of at boot"
  echo "autostart installed. Hand a running instance over with: scripts/instance.sh stop; systemctl --user start job-hunt"
}

wake() {
  sudo install -D -o root -g root -m 755 "$JH/config/systemd/night-wake.sh" "$ROOT_LIB/night-wake.sh"
  sudo tee /etc/systemd/system/job-hunt-wake.service >/dev/null <<EOF
[Unit]
Description=Keep the computer awake for the nightly job search (job-hunt)

[Service]
Type=oneshot
ExecStart=$ROOT_LIB/night-wake.sh $USER $JH
TimeoutStartSec=4500
EOF
  sudo tee /etc/systemd/system/job-hunt-wake.timer >/dev/null <<EOF
[Unit]
Description=Wake the computer for the nightly job search (job-hunt)

[Timer]
OnCalendar=*-*-* $WAKE_AT
WakeSystem=true
AccuracySec=1s

[Install]
WantedBy=timers.target
EOF
  sudo systemctl daemon-reload
  sudo systemctl enable --now job-hunt-wake.timer
  systemctl list-timers job-hunt-wake.timer --no-pager
}

remove() {
  systemctl --user disable --now job-hunt.service 2>/dev/null || true
  rm -f "$UNIT_DIR/job-hunt.service"
  systemctl --user daemon-reload
  sudo systemctl disable --now job-hunt-wake.timer 2>/dev/null || true
  sudo rm -f /etc/systemd/system/job-hunt-wake.timer /etc/systemd/system/job-hunt-wake.service "$ROOT_LIB/night-wake.sh"
  sudo systemctl daemon-reload
  echo "removed"
}

case "${1:-}" in
  autostart) autostart ;;
  wake) wake ;;
  remove) remove ;;
  *) echo "usage: $0 {autostart|wake|remove}" >&2; exit 2 ;;
esac
