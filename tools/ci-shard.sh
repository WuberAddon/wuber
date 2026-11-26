#!/bin/bash
# One shard of the suite for CI (.github/workflows/ci.yml): runs tests/run.lua --shard K/N (the same split as
# tools/suite-par.sh, balanced by tests/fixtures/test-times.txt), keeps its log and writes the names of its
# failing tests, one per line, to tests/out/failed-K-of-N.txt (empty file = none failed).
# Usage: tools/ci-shard.sh K N        Lua is $WUBER_LUA, else lua5.1.   A filter may follow: tools/ci-shard.sh K N "text"
# Exit: the shard's own exit code, or 2 when the shard died without printing its "shard K/N:" summary line.
k="$1"; n="$2"; shift 2
LUA="${WUBER_LUA:-lua5.1}"
export WUBER_LAB_DIR="${WUBER_LAB_DIR:-$(cd "$(dirname "$0")/.." && pwd)/lab/WuberLab}"
cd "$(dirname "$0")/.." || exit 2
mkdir -p tests/out
log="tests/out/shard-$k-of-$n.log"
list="tests/out/failed-$k-of-$n.txt"
start=$SECONDS
"$LUA" tests/run.lua "$@" --shard "$k/$n" 2>&1 | tee "$log"
code=${PIPESTATUS[0]}
grep -E '^FAIL  ' "$log" | sed 's/^FAIL  //' > "$list"
if ! grep -qE "^shard $k/$n: [0-9]+ passed, [0-9]+ failed" "$log"; then
  echo "ci-shard: shard $k/$n did not finish (no summary line, exit $code)"
  echo "SHARD $k/$n DID NOT FINISH (exit $code)" >> "$list"
  [ "$code" = 0 ] && code=2
fi
echo "ci-shard: shard $k/$n: exit $code, $(grep -c . "$list") failing, $((SECONDS - start)) s"
exit $code
