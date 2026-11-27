#!/bin/bash
# Run the full suite serially from the worktree given as $1 (extra args go to run.lua).
# Queue: the portable slot lock of tools/suite-guard.sh (plain files, no flock: flock is missing from Git Bash).
#   WUBER_SUITE_LOCK  shared lock folder (default: ${TMPDIR:-/tmp}/wuber-suite-lock); up to WUBER_SUITE_SLOTS (default 3) suites at once.
# A lock that cannot be taken FAILS LOUDLY (exit 2 and a message); it never waits silently.
dir="$1"; shift
[ -n "$dir" ] && [ -d "$dir" ] || { echo "suite.sh: ERROR: usage: tools/suite.sh <worktree> [run.lua args]" >&2; exit 2; }
. "$(dirname "$0")/suite-guard.sh"
export WUBER_SUITE_LOCK="${WUBER_SUITE_LOCK:-${TMPDIR:-/tmp}/wuber-suite-lock}"
trap 'suite_lock_release' EXIT
suite_lock_acquire || { echo "suite.sh: ERROR: could not take the suite lock in $WUBER_SUITE_LOCK" >&2; exit 2; }
cd "$dir" && timeout 1800 "${WUBER_LUA:-${LUA:-lua5.1}}" tests/run.lua "$@"
