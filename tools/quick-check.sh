#!/bin/bash
# The quick check the lead (and a group) runs after a change or a merge. Job 2690 (23 Nov 2026): it checks what the change TOUCHES.
# Usage: bash tools/quick-check.sh [repo or worktree] [--since <ref>] [--layout] [--build-map] [--list] [--no-ratchet]
#   --since <ref>  the diff base (default QC_BASE, else HEAD~1: after a merge, everything the merge brought in);
#                  the working tree and untracked files count too.
#   --layout       also the layout sweep of only the screens the changed files draw (tools/layout-check.lua --quick --files);
#                  a shared UI file (Core, Theme, Kit, Window, Fold ...) = the FULL sweep, as the finish stage runs it.
#   --build-map    build the coverage map once (tools/coverage-map.lua, 8 shards, below-normal, hidden by the caller) and
#                  cache it; a round does this once on its base. Cache: tests/out/coverage-map.txt here and a shared copy
#                  in QC_CACHE (optional).
#   --list         print what would run (the selected test names and parts), run nothing
#   --surface / --no-surface   the "surface" group (below) on / off; QC_SURFACE=0|1|auto does the same (auto = on when a Wuber/ Lua file changed)
#   --no-ratchet   skip the click-path ratchet (tools/click-ratchet.lua: a test file whose direct clicks rose, or a new one, fails; a second)
# What runs (at most QC_JOBS = 8 processes at once; Lua 5.1 only, never LuaJIT: the maintainer has not approved a LuaJIT trial):
#   1. tools/check.lua and the cheap whole-repo tests (TOC files, HAVE_UI, TOC order, headers, Media, metadata ...), as before;
#   2. every test the coverage map says ran code of a changed Wuber/ file (tests/run.lua --names=<file>, in balanced chunks);
#   3. a changed Wuber file the map has never seen, a changed test file, the TOC / xml / Media: the file-name map of
#      tools/tests-for.lua (whole test parts, run.lua --files=). No map at all: step 3 for every changed file.
#   4. a change to tests/run.lua, tests/lib, the harness, fakes, fixtures, transcripts: it prints "FULL SUITE NEEDED" (never
#      silent) and still runs 1.
# The "surface" group (tests/surface-guard.lua): the tests selected in 2 and 3 run a second time with WUBER_SURFACE=1, so the fake game
#   refuses what the real client refuses (undocumented or protected calls, secret values). Hits show as "surface: <test>" failures; the
#   hardware-click rule stays off (WUBER_SURFACE_HW=on tries it). Allowed names, with a reason each: tests/surface/allow.lua.
# Prints ONE last line: "quick-check: PASS (<n> tests, <f> changed files, <s> s)" or "quick-check: FAIL: <what failed>"; exit 0 / 1.
# NOT the finish: the finish stage, the gauntlet, fresh-suite and every judged run stay the full suite and the full layout sweep.
# It does not run map.lua --check (ARCHITECTURE.md may be stale in a round) and writes no transcript.
dir=""; since="${QC_BASE:-}"; layout=0; build=0; list=0; surface="${QC_SURFACE:-auto}"; ratchet=1
while [ $# -gt 0 ]; do
  case "$1" in
    --since) since="$2"; shift ;;
    --layout) layout=1 ;;
    --build-map) build=1 ;;
    --list) list=1 ;;
    --surface) surface=1 ;;
    --no-surface) surface=0 ;;
    --no-ratchet) ratchet=0 ;;
    *) dir="$1" ;;
  esac
  shift
done
[ -n "$dir" ] || dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LUA="${WUBER_LUA:-${LUA:-lua5.1}}"
export WUBER_LAB_DIR="${WUBER_LAB_DIR:-$(cd "$(dirname "$0")/.." && pwd)/lab/WuberLab}"
JOBS="${QC_JOBS:-8}"
[ "$JOBS" -gt 8 ] && JOBS=8
CACHE="${QC_CACHE:-${TMPDIR:-/tmp}/wuber-qc-cache}"
cd "$dir" || { echo "quick-check: FAIL: no such directory $dir"; exit 1; }
tmp="tests/out/quick-check"
mkdir -p "$tmp"   # a folder every run reuses (no folder deletes); only its own files are removed below

if [ "$build" = 1 ]; then
  rm -f tests/out/coverage-map.*.txt
  for k in $(seq 1 "$JOBS"); do nice -n 10 "$LUA" tools/coverage-map.lua --shard "$k/$JOBS" > "tests/out/cm-$k.log" 2>&1 & done
  wait
  "$LUA" tools/coverage-map.lua --join "$JOBS" > tests/out/cm-join.log 2>&1 || { echo "quick-check: FAIL: coverage map join"; exit 1; }
  mkdir -p "$CACHE" && cp tests/out/coverage-map.txt "$CACHE/coverage-map.txt" && git rev-parse HEAD > "$CACHE/coverage-map.commit"
  echo "quick-check: coverage map built ($(wc -l < tests/out/coverage-map.txt) tests) and cached in $CACHE"
  exit 0
fi

rm -f "$tmp"/*.out "$tmp"/names-*.txt "$tmp"/cmd-*.sh "$tmp"/s-hits-*.tsv
start=$SECONDS
t0=$(date +%s.%N)

# is tests/<folder>/ one run.lua loads file by file? (the folder list is gone: run.lua finds every folder of tests/ itself, except those in its NOT_AUTO table)
folder_part() { [ -d "tests/$1" ] && ! awk '/NOT_AUTO = \{/,/\}/' tests/run.lua | grep -qw "$1"; }
# the changed files: against the base, the working tree, and untracked files
if [ -z "$since" ]; then git rev-parse --verify -q HEAD~1 >/dev/null && since="HEAD~1" || since="HEAD"; fi
changed=$( { git diff --name-only "$since" 2>/dev/null; git ls-files --others --exclude-standard 2>/dev/null; } | sort -u )
nchanged=$(printf '%s\n' "$changed" | grep -c .)
wfiles=$(printf '%s\n' "$changed" | grep -E '^Wuber/.*\.lua$')
otherfiles=$(printf '%s\n' "$changed" | grep -E '^(tests/|Wuber/.*\.(toc|xml)$|Wuber/Media/)')

MAP=""
for c in "${QC_MAP:-}" "tests/out/coverage-map.txt" "$CACHE/coverage-map.txt"; do
  [ -n "$c" ] && [ -f "$c" ] && { MAP="$c"; break; }
done

ALWAYS=( "every TOC file exists and parses" "tests/lib/files.lua accounts for every Wuber TOC file" "HAVE_UI is true:"
  "tools/check.lua passes:" "TOC order: SPEC3's list" "tools/map.lua lists" "module headers: every hook slot"
  "every Media texture the Lua names exists" "every effect sheet FX.lua names exists" "TOC metadata: Author" )

cmds=()      # one shell command per job
labels=()
notes=()
selnote=""
parts=""
unmapped_files="$wfiles"
if [ -n "$MAP" ]; then
  alw=(); for a in "${ALWAYS[@]}"; do alw+=("--always=$a"); done
  sel=$("$LUA" tools/quick-select.lua --map="$MAP" --out="$tmp" --jobs=$((JOBS - 1)) --times=tests/fixtures/test-times.txt "${alw[@]}" $wfiles)
  selnote=$(printf '%s\n' "$sel" | grep '^selected')
  unmapped_files=$(printf '%s\n' "$sel" | sed -n 's/^unmapped: //p')
  for f in $(printf '%s\n' "$sel" | sed -n 's/^nofilter: //p'); do notes+=("map has no test named like: $f"); done
  for nf in "$tmp"/names-*.txt; do
    [ -f "$nf" ] || continue
    i=$(basename "$nf" .txt); i=${i#names-}
    cmds+=("timeout 300 \"$LUA\" tests/run.lua --names=$nf > $tmp/n$i.out 2>&1"); labels+=("tests chunk $i")
  done
else
  notes+=("no coverage map: file-name map only (bash tools/quick-check.sh --build-map builds it)")
  for k in "${!ALWAYS[@]}"; do
    cmds+=("timeout 120 \"$LUA\" tests/run.lua \"${ALWAYS[$k]}\" > $tmp/f$k.out 2>&1"); labels+=("${ALWAYS[$k]}")
  done
fi
# a changed test in one of the folders run.lua loads file by file (tests/r49/..._test.lua): run.lua --files= takes it as <folder>/<name>
foldertests=""; restfiles=""
for f in $otherfiles; do
  if [[ "$f" =~ ^tests/([A-Za-z0-9_]+)/([A-Za-z0-9_]+_test)\.lua$ ]] && folder_part "${BASH_REMATCH[1]}"; then
    foldertests="$foldertests${BASH_REMATCH[1]}/${BASH_REMATCH[2]},"
  else restfiles="$restfiles $f"; fi
done
# the file-name map (tools/tests-for.lua) for what the coverage map cannot say
tf=$("$LUA" tools/tests-for.lua --quiet $unmapped_files $restfiles 2>&1)
if printf '%s' "$tf" | grep -q "full suite needed"; then
  notes+=("FULL SUITE NEEDED: $(printf '%s\n' $restfiles | grep -E '^tests/(run|lib/|harness|fixtures/|transcripts/)' | head -3 | tr '\n' ' ')changed test machinery")
fi
parts=$(printf '%s\n' "$tf" | sed -n 's/^tests: --files=//p')
# a changed Wuber file's own test parts too (its Test: line, the part named for it, a part that names its module): the map says what ran
# its code, this says what is written for it
if [ -n "$wfiles" ]; then
  sp=$("$LUA" tools/tests-for.lua --quiet --strict $wfiles 2>&1 | sed -n 's/^tests: --files=//p')
  [ -n "$sp" ] && parts="${parts:+$parts,}$sp"
fi
# every small test part whose text names the file (FlightPins, Trips ...): the tests the map cannot see (a test that made a world and
# called nothing after its boot) are found by their words; a word that names more than 15 parts (Window, Base) is left to the map
for f in $wfiles; do
  b=$(basename "$f" .lua)
  hits=$(grep -rlw --include='*.lua' "$b" tests 2>/dev/null | grep -v -E '^tests/(out|lib|hunt|fixtures|transcripts|layout|preview|rec)/|^tests/(run|harness)' )
  [ "$(printf '%s\n' "$hits" | grep -c .)" -gt 15 ] && continue
  for h in $hits; do
    if [[ "$h" =~ ^tests/([A-Za-z0-9_]+)/([A-Za-z0-9_]+_test)\.lua$ ]] && folder_part "${BASH_REMATCH[1]}"; then parts="${parts:+$parts,}${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"
    elif [[ "$h" =~ ^tests/([A-Za-z0-9_/]+)\.lua$ ]] && grep -q "\"${BASH_REMATCH[1]}\"" tests/run.lua; then parts="${parts:+$parts,}${BASH_REMATCH[1]}"; fi
  done
done
if [ -n "$foldertests" ]; then parts="$foldertests$parts"; fi
parts=$(printf '%s' "$parts" | tr ',' '\n' | grep . | sort -u | paste -sd, -)
if [ -n "$parts" ]; then
  cmds+=("timeout 600 \"$LUA\" tests/run.lua --files=$parts > $tmp/p.out 2>&1"); labels+=("test parts $parts")
fi
# the surface group: the same selected tests again with the guard on (a copy of each --names= / --files= command, its own .out)
case "$surface" in
  0|off) surface=0 ;;
  1|on) surface=1 ;;
  *) surface=0; [ -n "$wfiles" ] && surface=1; printf '%s\n' "$otherfiles" | grep -qE '^tests/(surface|harness|fixtures/surface)' && surface=1 ;;
esac
[ -f tests/surface-guard.lua ] || surface=0
if [ "$surface" = 1 ]; then
  for k in "${!cmds[@]}"; do
    case "${cmds[$k]}" in
      *"tests/run.lua --names="*|*"tests/run.lua --files="*)
        twin="${cmds[$k]//> $tmp\//> $tmp/s-}"
        cmds+=("WUBER_SURFACE=1 WUBER_SURFACE_LOG=$tmp/s-hits-$k.tsv $twin"); labels+=("surface of ${labels[$k]}") ;;
    esac
  done
fi
cmds+=("\"$LUA\" tools/check.lua > $tmp/check.out 2>&1"); labels+=("tools/check.lua")
# ARCHITECTURE.md is generated by the maintainer after the last merge: a branch that touches it fails here (tools/arch-guard.lua)
cmds+=("\"$LUA\" tools/arch-guard.lua --base origin/main > $tmp/arch.out 2>&1"); labels+=("tools/arch-guard.lua")
# the click-path ratchet (Fable item 5): a test that clicks by calling OnClick skips the hit test; its count may only fall
if [ "$ratchet" = 1 ] && [ -f tools/click-ratchet.lua ]; then cmds+=("\"$LUA\" tools/click-ratchet.lua > $tmp/ratchet.out 2>&1"); labels+=("tools/click-ratchet.lua"); fi

if [ "$list" = 1 ]; then
  echo "changed since $since: $nchanged files; map: ${MAP:-none}"; echo "$selnote"; for n in "${notes[@]}"; do echo "note: $n"; done
  echo "parts: ${parts:-none}"; cat "$tmp"/names-*.txt 2>/dev/null; exit 0
fi

# run them, at most JOBS at once
pids=(); running=0
for k in "${!cmds[@]}"; do
  [ "$running" -ge "$JOBS" ] && { wait -n; running=$((running - 1)); }
  ( eval "${cmds[$k]}" ) & pids[$k]=$!
  running=$((running + 1))
done
bad=(); ntests=0
for k in "${!cmds[@]}"; do
  wait "${pids[$k]}"; rc=$?
  if [ "${labels[$k]}" = "tools/check.lua" ] && [ $rc -ne 0 ]; then bad+=("tools/check.lua"); echo "--- tools/check.lua"; grep -v "^lab:" "$tmp/check.out" | tail -15; fi
  if [ "${labels[$k]}" = "tools/click-ratchet.lua" ] && [ $rc -ne 0 ]; then bad+=("tools/click-ratchet.lua: a test clicks without the hit test"); echo "--- tools/click-ratchet.lua"; cat "$tmp/ratchet.out"; fi
  if [ "${labels[$k]}" = "tools/arch-guard.lua" ] && [ $rc -ne 0 ]; then bad+=("tools/arch-guard.lua: the branch changes ARCHITECTURE.md"); echo "--- tools/arch-guard.lua"; cat "$tmp/arch.out"; fi
done
# collect the test outputs (n*.out chunks, f*.out filters, p.out parts)
for o in "$tmp"/n*.out "$tmp"/f*.out "$tmp"/p.out; do
  [ -f "$o" ] || continue
  p=$(sed -n 's/^\([0-9]*\) passed, \([0-9]*\) failed.*/\1 \2/p' "$o" | tail -1)
  np=${p% *}; nf=${p#* }
  ntests=$((ntests + ${np:-0}))
  if [ -z "$p" ] || [ "${nf:-1}" != 0 ] || [ "${np:-0}" = 0 ]; then
    b=$(basename "$o" .out); case "$b" in n*) b="tests chunk ${b#n}";; f*) b="whole-repo test ${b#f}";; p) b="test parts $parts";; esac; bad+=("$b"); echo "--- $o"; grep -v "^PASS" "$o" | head -15
  fi
done
# the surface group's outputs: a failing test here (and not in the plain run) is a guard hit; they do not count in ntests
nsurf=0
for o in "$tmp"/s-n*.out "$tmp"/s-p.out; do
  [ -f "$o" ] || continue
  p=$(sed -n 's/^\([0-9]*\) passed, \([0-9]*\) failed.*/\1 \2/p' "$o" | tail -1)
  np=${p% *}; nf=${p#* }
  nsurf=$((nsurf + ${np:-0}))
  if [ -z "$p" ] || [ "${nf:-1}" != 0 ]; then
    bad+=("surface: $(basename "$o" .out | sed 's/^s-//')"); echo "--- surface group $o (the guard's lines say API name and file:line)"; grep -v "^PASS" "$o" | head -15
  fi
done
[ "$surface" = 1 ] && notes+=("surface group: $nsurf tests ran again with WUBER_SURFACE=1")
secs=$(awk "BEGIN{printf \"%.1f\", $(date +%s.%N) - $t0}")

if [ "$layout" = 1 ]; then
  scope=$("$LUA" tools/quick-select.lua --layout-scope $wfiles)
  case "$scope" in
    none*) notes+=("layout: no Wuber file changed, nothing to draw") ;;
    narrow*) notes+=("layout: only the screens of the changed files (--quick)")
      lo=$("$LUA" tools/layout-check.lua --quick --files $wfiles 2>&1 | tail -4)
      printf '%s\n' "$lo" | grep -q "GAUNTLET layout result=pass\|nothing to check" || { bad+=("layout"); echo "--- layout"; printf '%s\n' "$lo"; } ;;
    *) notes+=("layout: a shared UI file changed ($scope): the FULL sweep")
      lo=$("$LUA" tools/layout-check.lua 2>&1 | tail -4)
      printf '%s\n' "$lo" | grep -q "GAUNTLET layout result=pass" || { bad+=("layout"); echo "--- layout"; printf '%s\n' "$lo"; } ;;
  esac
  secs=$(awk "BEGIN{printf \"%.1f\", $(date +%s.%N) - $t0}")
fi
for n in "${notes[@]}"; do echo "note: $n"; done
[ -n "$selnote" ] && echo "$selnote"
if [ ${#bad[@]} -gt 0 ]; then
  ( IFS=';'; echo "quick-check: FAIL: ${bad[*]}" )
  exit 1
fi
echo "quick-check: PASS ($ntests tests, $nchanged changed files, $secs s)"
