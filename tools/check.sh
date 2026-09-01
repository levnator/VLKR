#!/usr/bin/env bash
set -euo pipefail
CHROME="${CHROME:-/Applications/Google Chrome.app/Contents/MacOS/Google Chrome}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

OUT=$("$CHROME" --headless --disable-gpu --allow-file-access-from-files \
  --virtual-time-budget=10000 --dump-dom "file://$ROOT/tools/selftest.html" 2>/dev/null \
  | python3 -c "
import sys, re, html
m = re.search(r'<pre id=\"results\">(.*?)</pre>', sys.stdin.read(), re.S)
print(html.unescape(m.group(1)) if m else 'FAIL  kein Testergebnis im DOM')
")

echo "$OUT"
if echo "$OUT" | grep -q "FAIL"; then exit 1; fi
if ! echo "$OUT" | grep -q "ALL PASS"; then echo "FAIL  Selbsttest lieferte kein Ergebnis"; exit 1; fi
