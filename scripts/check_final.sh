#!/usr/bin/env bash
# Hand-off check for a job's final letters, in ONE allowed command (agents may not chain commands):
#   scripts/check_final.sh JOB-7
# For the angle folder named in letter-plan.md ("Folder: <name>"; older plans "Folder A:"/"Folder B:") it checks that the
# German and English .pdf + .docx exist (names from documents/sender.json), each PDF is 1 page, contains no
# placeholder, and names the posting's company. Prints the first lines of every PDF (addressee + subject)
# for the identity check, then "RESULT: PASS" or "RESULT: FAIL" with the reasons. Exit code 0 only on PASS.
set -uo pipefail
t="${1:?usage: check_final.sh JOB-N}"
JH="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
dir="$("$JH/scripts/job_dir.sh" "$t")" || exit 1
fails=()
first="$(jq -r '.first_name // .firstName // empty' "$JH/documents/sender.json" 2>/dev/null)"
last="$(jq -r '.last_name // .lastName // empty' "$JH/documents/sender.json" 2>/dev/null)"
if [ -z "$first" ] || [ -z "$last" ]; then
  name="$(jq -r '.name // empty' "$JH/documents/sender.json" 2>/dev/null)"
  first="${name%% *}"; last="${name##* }"
fi
prefix="${first}-${last}"
company="$(jq -r '.company // empty' "$dir/posting.json" 2>/dev/null)"
title="$(jq -r '.title // empty' "$dir/posting.json" 2>/dev/null)"
echo "Job: $t | $company | $title"
echo "Folder: $dir"

mapfile -t angles < <(grep -oE 'Folder( [AB])?: *[A-Za-z0-9-]+' "$dir/letter-plan.md" 2>/dev/null | sed -E 's/.*: *//' | awk '!seen[$0]++')
[ "${#angles[@]}" -ge 1 ] || fails+=("letter-plan.md names no folder (Folder: <Name>)")
# Company check uses the first word of the posting's company (e.g. "dmTECH GmbH" -> "dmTECH").
cword="${company%% *}"

for a in "${angles[@]}"; do
  for kind in Anschreiben Cover-Letter; do
    for ext in pdf docx; do
      f="$dir/final/$a/$prefix-$kind.$ext"
      [ -s "$f" ] || fails+=("missing: final/$a/$prefix-$kind.$ext")
    done
    p="$dir/final/$a/$prefix-$kind.pdf"
    [ -s "$p" ] || continue
    pages="$(pdfinfo "$p" 2>/dev/null | awk '/^Pages:/{print $2}')"
    [ "$pages" = "1" ] || fails+=("final/$a/$prefix-$kind.pdf has ${pages:-?} pages")
    txt="$(pdftotext "$p" - 2>/dev/null)"
    if grep -qE '\[[A-ZÄÖÜa-z _-]{3,}\]|TODO|XXX|GEHALT|SALARY' <<<"$txt"; then
      fails+=("placeholder in final/$a/$prefix-$kind.pdf")
    fi
    if [ -n "$cword" ] && ! grep -qiF "$cword" <<<"$txt"; then
      fails+=("final/$a/$prefix-$kind.pdf does not mention the company \"$cword\"")
    fi
    echo "== final/$a/$prefix-$kind.pdf ($pages page)"
    head -12 <<<"$txt" | grep -v '^\s*$'
  done
done
extra="$(ls "$dir/final" 2>/dev/null | grep -vxF -e "${angles[0]:-}" -e "${angles[1]:-}")"
[ -z "$extra" ] || echo "Note: other folders in final/: $extra"

if [ "${#fails[@]}" -eq 0 ]; then echo "RESULT: PASS"; exit 0; fi
echo "RESULT: FAIL"; printf -- '- %s\n' "${fails[@]}"; exit 2
