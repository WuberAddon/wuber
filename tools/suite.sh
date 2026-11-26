#!/bin/bash
# Run the full suite from the worktree given as $1 (extra args go to run.lua).
# Two slots (the machine has 2 cores), so at most two suites run at once.
dir="$1"; shift
while true; do
  for s in 1 2; do
    exec 9>"/tmp/wuber-suite-slot$s.lock"
    if flock -n 9; then
      cd "$dir" && timeout 1800 "$${WUBER_LUA:-${LUA:-lua5.1}}" tests/run.lua "$@"
      exit $?
    fi
    exec 9>&-
  done
  sleep 10
done
