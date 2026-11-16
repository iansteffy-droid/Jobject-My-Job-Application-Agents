#!/usr/bin/env bash
# Render a job posting with headless Chrome (handles JavaScript-only job boards) and print its
# visible text. Use when WebFetch returns an empty shell, a cookie wall or too little text.
# Usage: scripts/fetch_page.sh <url> [max-chars, default 60000]
set -euo pipefail
url="${1:?usage: fetch_page.sh <url> [max-chars]}"; max="${2:-60000}"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
google-chrome --headless=new --disable-gpu --no-first-run --user-data-dir="$tmp/profile" \
  --virtual-time-budget=15000 --timeout=45000 --dump-dom "$url" 2>/dev/null > "$tmp/page.html" || true
python3 -I - "$tmp/page.html" "$max" <<'PY'
import html, re, sys
raw = open(sys.argv[1], encoding="utf-8", errors="replace").read()
raw = re.sub(r"(?is)<(script|style|noscript|svg|head)[^>]*>.*?</\1>", " ", raw)
raw = re.sub(r"(?i)<br\s*/?>|</(p|div|li|h[1-6]|tr|section)>", "\n", raw)
text = html.unescape(re.sub(r"<[^>]+>", " ", raw))
lines = [re.sub(r"[ \t ]+", " ", l).strip() for l in text.splitlines()]
out = "\n".join(l for l in lines if l)
print(out[: int(sys.argv[2])] if out else "FETCH_FAILED: page rendered no text (login wall or bot block?)")
PY
