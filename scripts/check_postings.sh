#!/usr/bin/env bash
# Is the job posting still online? One allowed command for the Coordinator's sheet sync:
#   scripts/check_postings.sh JOB-7 JOB-12 ...        (--all: also re-check jobs checked in the last 2 days)
# For each ticket it reads the URL from the job folder's posting.json, checks the HTTP status, renders the
# page (scripts/fetch_page.sh) and looks for "no longer available" notices and for the job title.
# Prints one line per ticket:
#   LIVE    JOB-7  <url>
#   CLOSED  JOB-7  <evidence>          (404/410, or a closed notice quoted from the page)
#   UNCLEAR JOB-7  <reason>            (bot block, login wall, title not on the page: no sheet change)
#   SKIP    JOB-7  <reason>            (checked recently, or no URL)
# Results are kept in jobs/.posting-checks.json (date + result per ticket); 6 pages are checked at once.
set -uo pipefail
JH="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE="$JH/jobs/.posting-checks.json"
[ -s "$STATE" ] || echo '{}' > "$STATE"
all=""; [ "${1:-}" = "--all" ] && { all=1; shift; }
[ $# -gt 0 ] || { echo "usage: check_postings.sh [--all] JOB-N ..." >&2; exit 2; }
today="$(date +%F)"; recent="$(date -d '2 days ago' +%F)"
out="$(mktemp -d)"; trap 'rm -rf "$out"' EXIT

check_one() {
  local t="$1" dir url title code eff txt hit word
  dir="$("$JH/scripts/job_dir.sh" "$t" 2>/dev/null)" || { echo "SKIP    $t  no job folder"; return; }
  url="$(jq -r '.url // empty' "$dir/posting.json" 2>/dev/null)"
  title="$(jq -r '.title // empty' "$dir/posting.json" 2>/dev/null)"
  [ -n "$url" ] || { echo "SKIP    $t  no URL in posting.json"; return; }
  read -r code eff < <(curl -sL --max-time 25 -o /dev/null -A "Mozilla/5.0 (X11; Linux x86_64) Chrome/130 Safari/537.36" \
    -w '%{http_code} %{url_effective}' "$url" 2>/dev/null || echo "000 -")
  case "$code" in 404|410) echo "CLOSED  $t  HTTP $code at $url"; return;; esac
  txt="$("$JH/scripts/fetch_page.sh" "$url" 60000 2>/dev/null)"
  if [ -z "$txt" ] || [[ "$txt" == FETCH_FAILED* ]]; then echo "UNCLEAR $t  page rendered no text (HTTP $code; bot block or login wall?)"; return; fi
  hit="$(grep -o -i -m1 -E "nicht mehr verfügbar|nicht mehr aktiv|nicht mehr online|nicht mehr ausgeschrieben|(stellen)?anzeige ist (leider )?(abgelaufen|deaktiviert)|stelle (ist )?(bereits )?besetzt|stellenangebot (wurde )?nicht gefunden|leider nicht mehr|no longer (available|accepting|active|open)|position has been filled|this job (has expired|is closed|is no longer)|job (is )?closed|job not found|posting (has )?(expired|closed)|vacancy (is )?not available" <<<"$txt")"
  if [ -n "$hit" ]; then echo "CLOSED  $t  page says \"$hit\" ($url)"; return; fi
  # The title must still be on the page (a redirect to a job list or the home page means the ad is gone).
  word="$(sed -E 's/\([^)]*\)//g; s/[–—|,:-]/ /g' <<<"$title" | tr ' ' '\n' | awk 'length($0)>=5' | head -n 2)"
  if [ -n "$word" ]; then
    while read -r w; do grep -qiF -- "$w" <<<"$txt" || { echo "UNCLEAR $t  title word \"$w\" not on the page (redirected to $eff?)"; return; }; done <<<"$word"
  fi
  echo "LIVE    $t  $url"
}
export -f check_one; export JH

todo=()
for t in "$@"; do
  last="$(jq -r --arg t "$t" '.[$t].date // ""' "$STATE")"
  if [ -z "$all" ] && [ -n "$last" ] && [[ "$last" > "$recent" || "$last" == "$recent" ]] \
     && [ "$(jq -r --arg t "$t" '.[$t].result' "$STATE" | cut -c1-6)" != "UNCLEA" ]; then
    echo "SKIP    $t  checked $last: $(jq -r --arg t "$t" '.[$t].result' "$STATE")"; continue
  fi
  todo+=("$t")
done
[ ${#todo[@]} -gt 0 ] && printf '%s\n' "${todo[@]}" | xargs -P 6 -I{} bash -c 'check_one "$1" > "'"$out"'/$1"' _ {}
for t in "${todo[@]}"; do
  line="$(cat "$out/$t" 2>/dev/null || echo "UNCLEAR $t  check crashed")"; echo "$line"
  jq --arg t "$t" --arg d "$today" --arg r "$line" '.[$t]={date:$d,result:$r}' "$STATE" > "$STATE.tmp" && mv "$STATE.tmp" "$STATE"
done
