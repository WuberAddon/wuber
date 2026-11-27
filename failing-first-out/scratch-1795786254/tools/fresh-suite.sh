#!/bin/bash
# The final full run from a FRESH clone, so no leftover of any earlier run (tests/out, times, locks) can shape it.
# Usage: tools/fresh-suite.sh [--dry] <repo> <commit-ish> [shards=16] [extra suite-par args, never --update-transcript]
# Makes (first time: git clone) or reuses $WUBER_FRESH_ROOT/<repo folder name>; then git fetch, git checkout -f
# --detach <commit>, git clean -fdx (so tests/out is empty; nothing is ever rm -rf'd), and runs
#   bash tools/suite-par.sh <clone> <shards> --compare-transcript [extra]
# It prints first "fresh clone: <path> at <sha>, tests/out empty: yes". A fresh-clone final run only COMPARES the
# transcript: --update-transcript is refused. --dry prints what it would do and touches nothing.
# Env: WUBER_FRESH_ROOT (default $TMPDIR/wuber-fresh), and the two the suite may use (WUBER_LAB_DIR, default
# the repo's lab/WuberLab; WUBER_REC_DIR is optional).
dry=0
if [ "$1" = "--dry" ]; then dry=1; shift; fi
repo="$1"; commit="$2"
if [ -z "$repo" ] || [ -z "$commit" ]; then
  echo "usage: tools/fresh-suite.sh [--dry] <repo> <commit-ish> [shards=16] [extra suite-par args]"
  exit 2
fi
shift 2
shards=16
if [[ "$1" =~ ^[0-9]+$ ]]; then shards="$1"; shift; fi
for a in "$@"; do
  if [ "$a" = "--update-transcript" ]; then
    echo "fresh-suite: REFUSED: --update-transcript (a fresh-clone final run only compares the transcript)"
    exit 2
  fi
done
root="${WUBER_FRESH_ROOT:-${TMPDIR:-/tmp}/wuber-fresh}"
clone="$root/$(basename "$repo")"
export WUBER_LAB_DIR="${WUBER_LAB_DIR:-$(cd "$(dirname "$0")/.." && pwd)/lab/WuberLab}"
here="$(cd "$(dirname "$0")" && pwd)"
if [ "$dry" = 1 ]; then
  sha=$(git -C "$repo" rev-parse "$commit" 2>/dev/null) || { echo "fresh-suite: no such commit $commit in $repo"; exit 2; }
  if [ -d "$clone/.git" ]; then echo "would reuse $clone: git fetch, git checkout -f --detach $commit, git clean -fdx"
  else echo "would git clone $repo $clone, then git checkout -f --detach $commit"; fi
  echo "fresh clone: $clone at $sha, tests/out empty: yes (dry: not made)"
  echo "would run: bash tools/suite-par.sh $clone $shards --compare-transcript $*"
  exit 0
fi
mkdir -p "$root" || exit 2
if [ -d "$clone/.git" ]; then
  git -C "$clone" fetch "$repo" || exit 2
else
  # the repo is kept with LF endings (core.autocrlf false); a clone made under a global autocrlf=true gets CRLF
  # files and fails the transcript compare and the TOC tests on the clone alone (job 2525 found it on its own first run)
  git -c core.autocrlf=false clone --no-checkout "$repo" "$clone" || exit 2
fi
# the commit may be a branch of the source repo that the clone has not seen by that name
sha=$(git -C "$repo" rev-parse "$commit") || exit 2
git -C "$clone" fetch "$repo" "$sha" 2>/dev/null
git -C "$clone" config core.autocrlf false
git -C "$clone" config core.eol lf
git -C "$clone" checkout -f --detach "$sha" || exit 2
# an older clone may still hold CRLF files from before the setting: re-read every file from the commit
if [ -n "$(git -C "$clone" ls-files --eol | grep -m1 'i/lf.*w/crlf')" ]; then
  git -C "$clone" rm -q -r --cached . >/dev/null && git -C "$clone" reset -q --hard "$sha" || exit 2
fi
# -ff: a test (arch guard self-test) leaves a nested git repo in tests/out, which a single -f keeps (job 2947)
git -C "$clone" clean -ffdx -q || exit 2
if [ -e "$clone/tests/out" ] && [ -n "$(ls -A "$clone/tests/out")" ]; then
  echo "fresh-suite: tests/out is not empty in $clone"; exit 2
fi
crlf=$(git -C "$clone" ls-files --eol | grep -c 'i/lf.*w/crlf')
if [ "$crlf" != "0" ]; then echo "fresh-suite: $crlf files have CRLF endings in $clone (the source repo has LF)"; exit 2; fi
echo "fresh clone: $clone at $(git -C "$clone" rev-parse HEAD), tests/out empty: yes, LF endings: yes"
exec "${BASH:-bash}" "$here/suite-par.sh" "$clone" "$shards" --compare-transcript "$@"
