#!/bin/bash
# Makes the behaviour-transcript baseline (tests/transcripts/baseline.txt, about 110 MB, never committed) the safe way:
# TWO full runs on a fresh clone of one commit, and the file is kept only when both transcripts are byte-identical.
# Usage: bash tools/make-baseline.sh <repo> <commit-ish> [shards=8] [out-file]
#   <repo>      a git repo or worktree that has the commit (for example origin/main of your checkout)
#   out-file    default <repo>/tests/transcripts/baseline.txt (gitignored); the commit it was made from goes beside it
#               in <out-file>.commit, and a run on another tree compares with it through WUBER_BASELINE=<out-file>
# Env: WUBER_FRESH_ROOT (where the fresh clone lives; default under TMPDIR, see tools/fresh-suite.sh), and the suite's
# own WUBER_SUITE_LOCK / WUBER_SUITE_SLOTS. Nothing is deleted: an existing out-file is moved to <out-file>.old.
# Exit 0: the two runs gave the same transcript and the baseline is written. 1: they differ or a run failed (no file written).
# Each run only RECORDS the transcript (--record-transcript); tools/fresh-suite.sh refuses --update-transcript on purpose.
if [ "$1" = "--help" ] || [ -z "$1" ] || [ -z "$2" ]; then
  sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//'
  exit 2
fi
repo="$1"; commit="$2"; shards="${3:-8}"
here="$(cd "$(dirname "$0")" && pwd)"
out="${4:-$repo/tests/transcripts/baseline.txt}"
sha=$(git -C "$repo" rev-parse "$commit") || exit 2
clone_root="${WUBER_FRESH_ROOT:-${TMPDIR:-/tmp}/wuber-fresh}"
clone="$clone_root/$(basename "$repo")"
sums=()
for run in 1 2; do
  echo "make-baseline: run $run of 2 on $sha"
  WUBER_BASELINE="$clone_root/no-baseline-for-this-run.txt" bash "$here/fresh-suite.sh" "$repo" "$sha" "$shards" --record-transcript || { echo "make-baseline: run $run failed: no baseline written"; exit 1; }
  t="$clone/tests/out/transcript.txt"
  [ -s "$t" ] || { echo "make-baseline: run $run left no transcript"; exit 1; }
  sums+=("$(sha256sum "$t" | cut -d' ' -f1)")
  if [ "$run" = 1 ]; then cp "$t" "$t.run1" || exit 1; mv "$t.run1" "$clone_root/transcript.run1.txt" || exit 1; fi
done
echo "make-baseline: run 1 sha256 ${sums[0]}"
echo "make-baseline: run 2 sha256 ${sums[1]}"
if [ "${sums[0]}" != "${sums[1]}" ]; then
  echo "make-baseline: the two transcripts differ: no baseline written (a test depends on time, order or the machine)"
  exit 1
fi
mkdir -p "$(dirname "$out")" || exit 2
[ -e "$out" ] && mv "$out" "$out.old"
cp "$clone/tests/out/transcript.txt" "$out" || exit 2
echo "$sha" > "$out.commit"
echo "make-baseline: two byte-identical runs; baseline written: $out ($(wc -c < "$out") bytes, commit $sha, sha256 ${sums[0]})"
