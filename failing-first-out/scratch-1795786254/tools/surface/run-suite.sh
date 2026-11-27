#!/bin/bash
# run-suite.sh: the whole suite with the API surface guard on, a few shards at a time, results written to disk per shard.
# usage: bash tools/surface/run-suite.sh [--shards N] [--only K,L,..] [--parallel P] [--out DIR] [--min-free-gb G]
#   --shards N       split the suite in N shards (default 8)
#   --only K,L,..    run only these shards of the N (to redo shards that died)
#   --parallel P     at most P shards at once (default 2, never more than 2: each one is a heavy Lua process)
#   --out DIR        where the logs go (default tests/out/surface): shard-K.log (the test output), hits-K.tsv (kind TAB name TAB where)
#   --min-free-gb G  wait before starting each shard while less than G GB of RAM is free (default 12)
# Prints one line per finished shard and, at the end, the totals and the hits by kind and name. Windows (Git Bash) and Linux.
shards=8; par=2; out=""; minfree=12; only=""
while [ $# -gt 0 ]; do
  case "$1" in
    --shards) shards="$2"; shift ;; --only) only="$2"; shift ;; --parallel) par="$2"; shift ;; --out) out="$2"; shift ;; --min-free-gb) minfree="$2"; shift ;;
    -h|--help) sed -n 2,10p "$0"; exit 0 ;;
    *) echo "unknown option $1"; exit 2 ;;
  esac
  shift
done
[ "$par" -gt 2 ] && par=2
cd "$(dirname "$0")/../.." || exit 1
LUA="${WUBER_LUA:-lua5.1}"
export WUBER_LAB_DIR="${WUBER_LAB_DIR:-$PWD/lab/WuberLab}"
out="${out:-tests/out/surface}"; mkdir -p "$out"
free_gb() {
  if command -v powershell >/dev/null 2>&1; then
    powershell -NoProfile -Command "[int]((Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory / 1048576)" | tr -d '\r'
  else awk '/MemAvailable/ {print int($2/1048576)}' /proc/meminfo; fi
}
wait_ram() {
  while [ "$(free_gb)" -lt "$minfree" ]; do echo "free RAM $(free_gb) GB < $minfree GB: waiting 60 s"; sleep 60; done
}
list=$(seq 1 "$shards"); [ -n "$only" ] && list=$(echo "$only" | tr ',' ' ')
for k in $list; do
  wait_ram
  while [ "$(jobs -rp | wc -l)" -ge "$par" ]; do sleep 5; done
  ( rm -f "$out/hits-$k.tsv"; WUBER_SURFACE=1 WUBER_SURFACE_LOG="$PWD/$out/hits-$k.tsv" "$LUA" tests/run.lua --shard "$k/$shards" > "$out/shard-$k.log" 2>&1
    echo "shard $k/$shards done: $(grep -E '^shard [0-9]+/[0-9]+: ' "$out/shard-$k.log" | tail -1)" ) &
done
wait
echo "== totals"; grep -hE '^shard [0-9]+/[0-9]+: ' "$out"/shard-*.log
echo "== hits by kind and name (count)"; cat "$out"/hits-*.tsv 2>/dev/null | cut -f1,2 | sort | uniq -c | sort -rn | head -60
