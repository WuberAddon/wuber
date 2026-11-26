#!/bin/bash
# Usage: tools/tdiff.sh <transcript.txt> [baseline]  -> tests whose transcript differs after ignoring frame ids and widget counts
T="$1"; B="${2:-tests/transcripts/baseline.txt}"
norm() { sed -E 's/\bf [0-9]+ /f N /; s/\^[0-9]+/^N/g; /^    widgets [0-9]+ /d' "$1" | awk '/^=== /{name=$0} {print name "\t" $0}'; }
diff <(norm "$B") <(norm "$T") | grep -E '^[<>]' | cut -f1 | sed -E 's/^[<>] //' | sort | uniq -c | sort -rn
