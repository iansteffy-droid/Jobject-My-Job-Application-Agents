#!/bin/sh
# Root side of the nightly job search (installed root-owned by scripts/install-night-run.sh).
# Usage: night-wake.sh <user> <repo dir>
#
# The wake timer resumed the computer (or it was awake anyway). Keep it awake, also with the lid
# closed, until the job search is done; then suspend again, but only if this timer woke it and
# nobody is using it.
woke=0
journalctl -k --since -5min --no-pager 2>/dev/null | grep -q "PM: suspend exit" && woke=1

systemd-inhibit --what=sleep:idle:handle-lid-switch --who=job-hunt --why="nightly job search" --mode=block \
  runuser -u "$1" -- /usr/bin/python3 -I "$2/scripts/night-run.py" || true

[ "$woke" = 1 ] || exit 0
for s in $(loginctl list-sessions --no-legend | awk '{print $1}'); do
  case "$(loginctl show-session "$s" -p Type --value)" in x11|wayland) ;; *) continue ;; esac
  [ "$(loginctl show-session "$s" -p Class --value)" = user ] || continue
  # an unlocked, non-idle desktop session: somebody is at the computer
  [ "$(loginctl show-session "$s" -p LockedHint --value)" = no ] &&
    [ "$(loginctl show-session "$s" -p IdleHint --value)" = no ] && exit 0
done
systemctl suspend
