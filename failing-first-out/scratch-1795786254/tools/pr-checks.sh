#!/bin/bash
# tools/pr-checks.sh: the checks AGENTS.md asks for before a pull request, in one command, with a short summary
# (job 2749; made so a helper runs one command instead of many steps). Runs, in this order, one at a time:
#   1. lua5.1 tools/check.lua
#   2. the full suite, 16 shards (tools/suite-par.sh); --baseline <file> compares the transcript with that file
#      (WUBER_BASELINE, --compare-transcript); --record <file> records this tree's transcript and copies it there
#   3. the layout check: --layout full (default: every shot and the route walks), quick (--quick), none
#   4. the scrub check on what is COMMITTED (git archive HEAD, so tests/out and local files are not scanned):
#      the public list always, and --private <patterns file> (a list kept outside the repository) when given
# Usage: bash tools/pr-checks.sh <repo or worktree> [--baseline FILE | --record FILE] [--layout full|quick|none]
#                                [--private FILE] [--shards N] [--no-suite]
# Lua 5.1: lua5.1 on the PATH, or LUA / WUBER_LUA. Python: python, or PYTHON.
# Every step's full output goes to tests/out/pr-checks-<step>.txt; the LAST line printed is the summary:
#   pr-checks: check=<ok|FAIL> suite=<passed>/<failed> transcript=<same|DIFF|recorded|-> layout=<problems|-> scrub=<0|HITS>/<0|HITS|-> => PASS|FAIL
# Exit 0 when everything passed.
if [ "$1" = "--help" ] || [ -z "$1" ]; then sed -n '2,16p' "$0"; exit 0; fi
dir="$1"; shift
baseline=""; record=""; layout="full"; private=""; shards=16; suite=1
while [ $# -gt 0 ]; do
  case "$1" in
    --baseline) baseline="$2"; shift ;;
    --record) record="$2"; shift ;;
    --layout) layout="$2"; shift ;;
    --private) private="$2"; shift ;;
    --shards) shards="$2"; shift ;;
    --no-suite) suite=0 ;;
    *) echo "pr-checks: unknown option $1"; exit 2 ;;
  esac
  shift
done
LUA="${WUBER_LUA:-${LUA:-lua5.1}}"
PY="${PYTHON:-python}"
here="$(cd "$(dirname "$0")" && pwd)"
cd "$dir" || exit 2
mkdir -p tests/out
out=tests/out
fail=0
# the lab addon checked is the worktree's own (suite-par.sh would take the one beside the script that runs it)
export WUBER_LAB_DIR="$PWD/lab/WuberLab"
# 1. check.lua
if "$LUA" tools/check.lua > "$out/pr-checks-check.txt" 2>&1; then chk=ok; else chk=FAIL; fail=1; fi
# 2. the suite
st="-"; tr="-"
if [ "$suite" = 1 ]; then
  flags=()
  if [ -n "$baseline" ]; then flags=(--compare-transcript); export WUBER_BASELINE="$baseline"; fi
  if [ -n "$record" ]; then flags=(--record-transcript); fi
  WUBER_LUA="$LUA" bash tools/suite-par.sh . "$shards" "${flags[@]}" > "$out/pr-checks-suite.txt" 2>&1
  code=$?
  counts=$(grep -E '[0-9]+ passed, [0-9]+ failed' "$out/pr-checks-suite.txt" | tail -n 1)
  p=$(echo "$counts" | sed -n 's/^\([0-9]*\) passed.*/\1/p'); f=$(echo "$counts" | sed -n 's/.* \([0-9]*\) failed.*/\1/p')
  st="${p:-?}/${f:-?}"
  if [ -n "$baseline" ]; then
    if grep -qiE 'transcript.*(differ|DIFFERENT|changed)' "$out/pr-checks-suite.txt"; then tr=DIFF; else tr=same; fi
  fi
  if [ -n "$record" ]; then cp "$out/transcript.txt" "$record" && tr=recorded || tr=FAIL; fi
  if [ "$code" != 0 ] || [ "${f:-1}" != 0 ] || [ "$tr" = DIFF ] || [ "$tr" = FAIL ]; then fail=1; fi
fi
# 3. the layout check
lay="-"
if [ "$layout" != "none" ]; then
  lflags=()
  [ "$layout" = quick ] && lflags=(--quick)
  "$LUA" tools/layout-check.lua "${lflags[@]}" > "$out/pr-checks-layout.txt" 2>&1
  lcode=$?
  lay=$(grep -oE 'problems=[0-9]+' "$out/pr-checks-layout.txt" | tail -n 1 | cut -d= -f2)
  lay="${lay:-?}"
  [ "$lcode" != 0 ] && { fail=1; lay="$lay(exit $lcode)"; }
fi
# 4. the scrub check on the committed tree
tmp="$out/pr-checks-archive"
rm -rf "$tmp"; mkdir -p "$tmp"
git archive HEAD | tar -x -C "$tmp"
if "$PY" scrub-check.py "$tmp" --patterns scrub-patterns.public.txt > "$out/pr-checks-scrub-public.txt" 2>&1; then pub=0; else pub=HITS; fi
prv="-"
if [ -n "$private" ]; then
  if "$PY" scrub-check.py "$tmp" --patterns "$private" > "$out/pr-checks-scrub-private.txt" 2>&1; then prv=0; else prv=HITS; fi
fi
rm -rf "$tmp"
[ "$pub" != 0 ] && fail=1
[ -n "$private" ] && [ "$prv" != 0 ] && fail=1
verdict=PASS; [ "$fail" = 1 ] && verdict=FAIL
echo "pr-checks: check=$chk suite=$st transcript=$tr layout=$lay scrub=$pub/$prv => $verdict"
exit $fail
