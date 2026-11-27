#!/bin/bash
# Full Wuber suite on a many-core PC (Git Bash). Usage: tools/suite-win.sh <repo or worktree> [run.lua flags]
# No queue: the PC has 16 cores. Lua 5.1 is lua5.1 on the PATH (or $LUA) unless WUBER_LUA says otherwise.
dir="$1"; shift
LUA="${WUBER_LUA:-${LUA:-lua5.1}}"
export WUBER_LAB_DIR="${WUBER_LAB_DIR:-$(cd "$(dirname "$0")/.." && pwd)/lab/WuberLab}"
cd "$dir" && timeout 2400 "$LUA" tests/run.lua "$@"
