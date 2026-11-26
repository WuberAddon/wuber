#!/bin/bash
# The full Wuber suite split over N processes at once (tests/lib/shard.lua), then joined into the
# result a serial run gives: the same counts, failures and tests/out/transcript.txt, byte for byte.
# Usage: tools/suite-par.sh <repo or worktree> [N] [filter] [run.lua flags, e.g. --compare-transcript]
# N defaults to the core count, at most 16, and at most half of it while other suites are queued or running
# (WUBER_SHARDS overrides; 16 is only right for a fast PC). --force or --fresh (or WUBER_SUITE_FRESH=1) runs even when the same code already passed.
# A full suite waits in line for WUBER_SUITE_LOCK (a folder shared by all checkouts) and a pass is cached in
# WUBER_SUITE_CACHE: see tools/suite-guard.sh (the ONE place of the slot lock and the result cache). Unset, the lock is off
# and the cache is tests/out/cache. A run that finds every slot taken waits, then exits 5. A cached pass prints "CACHE HIT"
# and starts no test; it is never used for --fresh, --force, --compare-transcript or --update-transcript.
# Shard K logs to tests/out/shard-K.log; the join's
# output (every failure, the counts, the transcript check, the report) is printed here.
# Exit code: non-zero on any failure, a transcript difference, or a shard that did not finish.
# Lua 5.1 is lua5.1 on the PATH (or $LUA) unless WUBER_LUA says otherwise. tools/suite-win.sh is the serial run.
# How many: the run takes about (all tests' CPU) / N, but never less than its longest test. Until the speed
# round that was drive.book's "Get Wuber" (a day of game frames, about 120 s); it is now five tests of under
# 5 s and the slowest test (lab photo) is about 25-45 s, so the run is CPU-bound: 16 shards (this PC's 16
# cores) took 83-95 s on 21 Nov (1275 tests), 12 took 106 s, 8 took 156 s. When other runs share the CPU, fewer. The 5 slowest tests of the run are printed at the end.
# LuaJIT (WUBER_LUA=.../luajit) runs the suite about 1.5x faster but is NOT a substitute: its pairs() order
# and math.random differ from Lua 5.1, which changes what Wuber does in some tests (another crew member
# whispered first, one test fails), so its transcript never matches. Use Lua 5.1 (BRIEF21 S3).
# One run per tree: tests/out/.suite-lock holds "<pid> <start epoch>". A second run in the same tree refuses
# (exit 3, one line) while that pid is alive (kill -0 only tests, nothing is ever killed) and the lock is under
# 30 minutes old; a stale lock (dead pid, or older) is taken over with a note. The lock goes on exit.
# An UNFILTERED run whose joined summary shows "N skipped" with N > 0 prints "REJECTED: unfiltered run skipped N
# tests" first and exits 4: a full run that skipped tests proves nothing (a missing fixture or recorder copy).
# The bash running this script, as a path Lua's io.popen (cmd.exe on Windows) can run: tests that start
# bash use it (WUBER_BASH) and never the "bash" on PATH, which on Windows can be WSL's.
if [ -z "$WUBER_BASH" ] && [ -n "$BASH" ]; then
  WUBER_BASH="$BASH"
  case "$(uname -s 2>/dev/null)" in
    MINGW*|MSYS*|CYGWIN*)
      # $BASH is /usr/bin/bash here: make it a drive-letter path ending in usr/bin/bash.exe (pwd -W is built in, so no cygpath on PATH needed)
      if [[ "$BASH" == /* ]]; then
        WUBER_BASH="$(cd / && pwd -W)$BASH"
        [[ "$WUBER_BASH" == *.exe ]] || WUBER_BASH="$WUBER_BASH.exe"
      fi ;;
  esac
fi
export WUBER_BASH
dir="$1"; shift
n="${WUBER_SHARDS:-}"
if [[ "$1" =~ ^[0-9]+$ ]]; then n="$1"; shift; fi
force=0; [ "${WUBER_SUITE_FRESH:-0}" = 1 ] && force=1
rest=()
# --force and --fresh (not passed on to run.lua) and a judged run (transcript compare/update) never use a cached pass
for a in "$@"; do
  case "$a" in
    --force|--fresh) force=1 ;;
    --compare-transcript|--update-transcript) force=1; rest+=("$a") ;;
    *) rest+=("$a") ;;
  esac
done
set -- "${rest[@]}"
LUA="${WUBER_LUA:-${LUA:-lua5.1}}"
. "$(dirname "$0")/suite-guard.sh"
export WUBER_LAB_DIR="${WUBER_LAB_DIR:-$(cd "$(dirname "$0")/.." && pwd)/lab/WuberLab}"
cd "$dir" || exit 2
mkdir -p tests/out
# a suite started BY a test of a running suite (tests/lessons/l25) has no queue and no cache: it would wait for its own parent
nested=""; [ -n "$WUBER_SUITE_PARENT$WUBER_SUITE_NESTED" ] && { nested=1; WUBER_SUITE_LOCK=""; }
export WUBER_SUITE_PARENT=$$
key=""; [ -n "$nested" ] || key=$(suite_key "$@") || key=""
if [ "$force" = 0 ] && [ -n "$key" ] && suite_cache_hit "$key"; then echo "suite-par: cached, 0 s, exit 0"; exit 0; fi
lock="tests/out/.suite-lock"
if [ -f "$lock" ]; then
  read -r lpid lstart < "$lock"
  now=$(date +%s)
  if [[ "$lpid" =~ ^[0-9]+$ && "$lstart" =~ ^[0-9]+$ ]] && kill -0 "$lpid" 2>/dev/null && [ $((now - lstart)) -lt 1800 ]; then
    echo "suite-par: REFUSED: another suite run (pid $lpid, started $((now - lstart)) s ago) holds $dir/$lock"
    exit 3
  fi
  echo "suite-par: note: taking over a stale lock (pid $lpid, started $lstart)"
fi
echo "$$ $(date +%s)" > "$lock"
trap 'rm -f "$lock"; suite_lock_release' EXIT
suite_lock_acquire || exit 2
# a suite that passed while this one waited in line may have made the run unnecessary
if [ "$force" = 0 ] && [ -n "$key" ] && suite_cache_hit "$key"; then exit 0; fi
[ -n "$n" ] || n=$(suite_default_shards)
# a shard that dies before it opens its files must not leave an older run's files to be joined
rm -f tests/out/results.*-of-"$n".txt tests/out/transcript.*-of-"$n".txt tests/out/shard-*.log
start=$SECONDS
pids=()
for k in $(seq 1 "$n"); do
  timeout 2400 "$LUA" tests/run.lua "$@" --shard "$k/$n" > "tests/out/shard-$k.log" 2>&1 &
  pids+=("$!")
done
for k in $(seq 1 "$n"); do
  wait "${pids[$((k - 1))]}"
  code=$?
  echo "shard $k/$n: exit $code at $((SECONDS - start)) s: $(tail -n 1 "tests/out/shard-$k.log")"
done
filtered=0
for a in "$@"; do [[ "$a" != --* ]] && filtered=1; done
timeout 600 "$LUA" tests/run.lua "$@" --join "$n" | tee tests/out/join.log
code=${PIPESTATUS[0]}
if [ "$filtered" = 0 ]; then
  skipped=$(grep -E '[0-9]+ passed, [0-9]+ failed' tests/out/join.log | tail -n 1 | sed -n 's/.* \([0-9][0-9]*\) skipped.*/\1/p')
  if [ -n "$skipped" ] && [ "$skipped" -gt 0 ]; then
    echo "REJECTED: unfiltered run skipped $skipped tests"
    code=4
  fi
fi
echo "slowest tests (CPU s):"
awk -F'\t' '$1 == "T" { print $5 "\t" $6 }' tests/out/results.*-of-"$n".txt 2>/dev/null | sort -rn | head -n 5 | cut -c1-150 | sed 's/^/  /'
echo "suite-par: $n shards, $((SECONDS - start)) s, exit $code"
[ "$code" = 0 ] && [ -n "$key" ] && suite_cache_save "$key" "$(grep -E '[0-9]+ passed, [0-9]+ failed' tests/out/join.log | tail -n 1)"
exit $code