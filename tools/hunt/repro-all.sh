#!/bin/bash
# The bug hunt: run every repro test in tests/hunt/repro once, one process at a time (about 4 minutes for 100 files).
#   bash tools/hunt/repro-all.sh [out.tsv]        (from the repo root; default out: tests/out/hunt/repro-all.tsv)
# Writes file<TAB>exit<TAB>seconds<TAB>first line. Exit 1 = the bug still shows, 0 = fixed, 2 = cannot tell (the hunt
# itself changed). tests/hunt/KNOWN.md maps each file to its line on the shared bug list: a file that exits 1 while its
# line says "fixed" is either a regression or an outdated check, and somebody must judge which (22 Nov 2026: of eight
# such files one was a regression, HUNT-127). Cheap enough to run after every fix round.
# Needs WUBER_REC_DIR (a copy of the recorder addon) on the 2.4 tree; WUBER_LAB_DIR has a default here.
cd "$(dirname "$0")/../.." || exit 9
export WUBER_LAB_DIR="${WUBER_LAB_DIR:-$(pwd)/lab/WuberLab}"
LUA="${WUBER_LUA:-${LUA:-lua5.1}}"
OUT="${1:-tests/out/hunt/repro-all.tsv}"
mkdir -p "$(dirname "$OUT")"
: > "$OUT"
n=0
for f in tests/hunt/repro/*.lua; do
  t0=$(date +%s)
  line=$(timeout 300 "$LUA" "$f" 2>&1 | head -1 | tr '\t\r' '  ' | cut -c1-300; echo "exit=${PIPESTATUS[0]}")
  code=$(echo "$line" | grep -o 'exit=[0-9]*$' | tail -1 | cut -d= -f2)
  first=$(echo "$line" | head -1)
  t1=$(date +%s)
  printf '%s\t%s\t%s\t%s\n' "$(basename "$f")" "$code" "$((t1-t0))" "$first" >> "$OUT"
  n=$((n+1))
done
echo "ran $n repro tests; exit 1 (still failing): $(awk -F'\t' '$2==1' "$OUT" | wc -l); exit 0 (fixed): $(awk -F'\t' '$2==0' "$OUT" | wc -l); other: $(awk -F'\t' '$2!=0 && $2!=1' "$OUT" | wc -l)"
