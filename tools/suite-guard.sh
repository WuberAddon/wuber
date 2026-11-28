#!/bin/bash
# Helpers sourced by tools/suite-par.sh: a machine-wide queue for full suites, a result cache, the shard count.
# Nothing here kills a process; a stale lock is moved aside, never deleted by name.
#   WUBER_SUITE_LOCK   folder shared by every checkout on the PC. Unset = no queue (one run per tree only).
#                      Holds "held.<pid>" (one file per running suite: "<pid> <start epoch>"; the old single "held" counts as
#                      one taken slot) and "wait.<pid>" (queued suites). Up to WUBER_SUITE_SLOTS (default 3) run at once.
#                      Stale = dead pid (kill -0, works from PowerShell and Git Bash) or older than 60 minutes.
#   slots.txt          optional file in the lock folder holding a number 1-8: it wins over WUBER_SUITE_SLOTS and is re-read at every wait poll.
#   WUBER_SUITE_SLOTS  how many full suites may run at once (default 3; 8 shards each fit this PC's 90% CPU cap).
#   WUBER_SUITE_WAIT_MAX  seconds to wait in line before running anyway (default 2700 = 45 min).
#   WUBER_SUITE_POLL   seconds between lock checks (default 5).
#   WUBER_SUITE_CACHE  folder for the "this code already passed" files (default tests/out/cache of the tree). Key = git tree hash of the
#                      working tree + sha256 of the lua5.1 executable + run.lua arguments (suite_key); never used for --fresh/--force/judged runs.
#   WUBER_CORES        core count to use instead of nproc / NUMBER_OF_PROCESSORS.

suite_pid_alive() { [[ "$1" =~ ^[0-9]+$ ]] && kill -0 "$1" 2>/dev/null; }

# cores of this machine, at most 16 (4 when it cannot be told)
suite_cores() {
  local c="${WUBER_CORES:-}"
  [ -n "$c" ] || c=$(nproc 2>/dev/null)
  [[ "$c" =~ ^[0-9]+$ ]] || c="${NUMBER_OF_PROCESSORS:-}"
  if ! [[ "$c" =~ ^[0-9]+$ ]] || [ "$c" -lt 1 ]; then c=4; fi
  [ "$c" -gt 16 ] && c=16
  echo "$c"
}

# how many OTHER suites (running or queued, live pid) the lock folder shows
suite_others() {
  local n=0 f p
  [ -n "$WUBER_SUITE_LOCK" ] || { echo 0; return; }
  for f in "$WUBER_SUITE_LOCK"/held "$WUBER_SUITE_LOCK"/held.[0-9]* "$WUBER_SUITE_LOCK"/wait.*; do
    [ -f "$f" ] || continue
    p=""; read -r p _ < "$f"
    [ "$p" = "$$" ] && continue
    suite_pid_alive "$p" && n=$((n + 1))
  done
  echo "$n"
}

# shard count when none was given: the core count (max 16), at most half of it when other suites are queued or running
suite_default_shards() {
  local c; c=$(suite_cores)
  if [ "$(suite_others)" -gt 0 ]; then c=$((c / 2)); [ "$c" -lt 1 ] && c=1; fi
  echo "$c"
}

# --- slot lock: up to WUBER_SUITE_SLOTS (default 3) full suites at once ---
# Each holder owns a file held.<pid> ("<pid> <start epoch>") in the lock folder. The old single file "held" (older
# copies of this script) counts as one taken slot. The count-and-take step runs under a short mutex file, slots.mutex.
# Order: "$WUBER_SUITE_LOCK/slots.txt" (a number 1-8; re-read at every wait poll, so a running queue picks up a change) wins,
# then WUBER_SUITE_SLOTS, then 3. A value outside 1-8 or not a number in the file is ignored.
suite_slots() {
  local s="" v=""
  if [ -n "$WUBER_SUITE_LOCK" ] && [ -f "$WUBER_SUITE_LOCK/slots.txt" ]; then
    read -r v _ < "$WUBER_SUITE_LOCK/slots.txt" 2>/dev/null
    v="${v//$'\r'/}"
    if [[ "$v" =~ ^[0-9]+$ ]] && [ "${#v}" -le 2 ] && [ "$((10#$v))" -ge 1 ] && [ "$((10#$v))" -le 8 ]; then echo "$((10#$v))"; return; fi
  fi
  s="${WUBER_SUITE_SLOTS:-3}"
  { [[ "$s" =~ ^[0-9]+$ ]] && [ "$s" -ge 1 ]; } || s=3
  echo "$s"
}

# 0 when a holder file is stale: dead pid, older than 60 minutes, or unreadable and the file itself older than that
suite_holder_stale() {
  local f="$1" p="" t="" now mt; now=$(date +%s)
  read -r p t < "$f" 2>/dev/null
  if ! [[ "$p" =~ ^[0-9]+$ ]]; then
    mt=$(stat -c %Y "$f" 2>/dev/null || echo "$now"); [ $((now - mt)) -ge 3600 ]; return
  fi
  suite_pid_alive "$p" || return 0
  { [[ "$t" =~ ^[0-9]+$ ]] && [ $((now - t)) -ge 3600 ]; } && return 0
  return 1
}

# short mutex around count-and-take; a mutex file older than 30 s is moved aside
suite_mutex_take() {
  local m="$WUBER_SUITE_LOCK/slots.mutex" mt now i
  for i in 1 2 3 4 5 6 7 8 9 10; do
    if ( set -C; echo "$$ $(date +%s)" > "$m" ) 2>/dev/null; then return 0; fi
    now=$(date +%s); mt=$(stat -c %Y "$m" 2>/dev/null || echo "$now")
    [ $((now - mt)) -ge 30 ] && mv "$m" "$m.stale.$$" 2>/dev/null
    sleep 0.3
  done
  return 1
}
suite_mutex_free() { local p=""; read -r p _ < "$WUBER_SUITE_LOCK/slots.mutex" 2>/dev/null; [ "$p" = "$$" ] && rm -f "$WUBER_SUITE_LOCK/slots.mutex"; }

SUITE_HELD=0
# wait in line for a free slot; after the wait cap run anyway
suite_lock_acquire() {
  [ -n "$WUBER_SUITE_LOCK" ] || return 0
  mkdir -p "$WUBER_SUITE_LOCK" 2>/dev/null && [ -d "$WUBER_SUITE_LOCK" ] && [ -w "$WUBER_SUITE_LOCK" ] || { echo "suite-par: ERROR: cannot use WUBER_SUITE_LOCK=$WUBER_SUITE_LOCK (not a writable folder); refusing to run without the lock" >&2; return 2; }
  local mine="$WUBER_SUITE_LOCK/held.$$" waitf="$WUBER_SUITE_LOCK/wait.$$" slots
  local start=$SECONDS max="${WUBER_SUITE_WAIT_MAX:-2700}" poll="${WUBER_SUITE_POLL:-5}" said=-9999 live lpid lstart first f moved mp
  echo "$$ $(date +%s)" > "$waitf"
  while :; do
    first=""; slots=$(suite_slots)   # re-read every poll: slots.txt may change while queued
    if suite_mutex_take; then
      live=0
      for f in "$WUBER_SUITE_LOCK"/held "$WUBER_SUITE_LOCK"/held.[0-9]*; do
        [ -f "$f" ] || continue
        lpid=""; lstart=""; read -r lpid lstart < "$f" 2>/dev/null
        if suite_holder_stale "$f"; then
          moved="$WUBER_SUITE_LOCK/stale.$$.${f##*/}"
          if mv "$f" "$moved" 2>/dev/null; then
            echo "suite-par: note: taking over a stale suite lock (pid ${lpid:-?}, started ${lstart:-?}); old file kept as $moved"
          fi
        else
          live=$((live + 1)); [ -n "$first" ] || first="$lpid"
        fi
      done
      if [ "$live" -lt "$slots" ]; then
        echo "$$ $(date +%s)" > "$mine"
        SUITE_HELD=1; rm -f "$waitf"; suite_mutex_free; return 0
      fi
      suite_mutex_free
    fi
    if [ $((SECONDS - start)) -ge "$max" ]; then
      echo "suite-par: waited $((SECONDS - start)) s for a suite slot (all $slots taken, held by ${first:-?}): running anyway"
      return 0
    fi
    if [ $((SECONDS - said)) -ge 300 ]; then
      echo "suite-par: waiting for suite lock held by ${first:-?} (all $slots slots taken)"
      said=$SECONDS
    fi
    sleep "$poll"
  done
}

suite_lock_release() {
  [ -n "$WUBER_SUITE_LOCK" ] || return 0
  rm -f "$WUBER_SUITE_LOCK/wait.$$"
  if [ "$SUITE_HELD" = 1 ]; then
    local p=""; read -r p _ < "$WUBER_SUITE_LOCK/held.$$" 2>/dev/null
    [ "$p" = "$$" ] && rm -f "$WUBER_SUITE_LOCK/held.$$"
  fi
}

# path of folder $1 relative to the work tree top $2 when it lies inside it (so it can be left out of the key), else nothing
suite_inside() {
  local t pre; mkdir -p "$1" 2>/dev/null
  t=$(git -C "$1" rev-parse --show-toplevel 2>/dev/null) || return 0
  [ "$t" = "$2" ] || return 0
  pre=$(git -C "$1" rev-parse --show-prefix 2>/dev/null); echo "${pre%/}"
}

# key of the code under test: the git TREE HASH of the working tree (tracked and untracked files, so a new file counts;
# not tests/out, nor the lock or cache folder when they lie inside the tree), the sha256 of the Lua executable
# (its -v text when the hash cannot be made) and the run.lua arguments (not the shard count). Prints nothing and fails
# without a git work tree, so such a run is real.
suite_key() {
  local top idx t rc luabin lh x skip=() sk
  top=$(git rev-parse --show-toplevel 2>/dev/null) || return 1
  git check-ignore -q tests/out/.x 2>/dev/null || skip+=(':(exclude)tests/out')
  for x in "${WUBER_SUITE_CACHE:-}" "${WUBER_SUITE_LOCK:-}"; do
    [ -n "$x" ] && { sk=$(suite_inside "$x" "$top"); [ -n "$sk" ] && skip+=(":(exclude)$sk"); }
  done
  idx=$(mktemp -u 2>/dev/null) || return 1
  GIT_INDEX_FILE="$idx" git -C "$top" add -A -- . "${skip[@]}" >/dev/null 2>&1 || { rm -f "$idx"; return 1; }
  t=$(GIT_INDEX_FILE="$idx" git -C "$top" write-tree 2>/dev/null); rc=$?
  rm -f "$idx"
  { [ "$rc" = 0 ] && [ -n "$t" ]; } || return 1
  luabin=$(command -v "$LUA" 2>/dev/null); lh=""
  [ -n "$luabin" ] && lh=$(sha256sum "$luabin" 2>/dev/null | cut -d' ' -f1)
  [ -n "$lh" ] || lh="v:$("$LUA" -v 2>&1 | head -n 1)"
  printf 'tree=%s\nlua=%s\nargs=%s\n' "$t" "$lh" "$*" | sha256sum | cut -c1-40
}

suite_cache_dir() { echo "${WUBER_SUITE_CACHE:-tests/out/cache}"; }

# prints "same code already passed (<time>)" and returns 0 when the key has a pass file
suite_cache_hit() {
  local f; f="$(suite_cache_dir)/$1.pass"
  [ -f "$f" ] || return 1
  local t; read -r t _ < "$f"
  [[ "$t" =~ ^[0-9]+$ ]] && t=$(date -d "@$t" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "$t")
  echo "suite-par: CACHE HIT: same code already passed ($t); NO test was run now. --fresh (or --force) runs again."
  sed -n '2,$p' "$f"
  return 0
}

suite_cache_save() {
  local d; d=$(suite_cache_dir)
  mkdir -p "$d" 2>/dev/null || return 0
  printf '%s\n%s\n' "$(date +%s)" "$2" > "$d/$1.pass"
}
