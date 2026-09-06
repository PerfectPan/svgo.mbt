#!/usr/bin/env bash
# Run the MoonBit micro benchmarks and print one line per benchmark.
# Usage: scripts/bench.sh [target] [file]   (default: native, bench_test.mbt)
set -euo pipefail
cd "$(dirname "$0")/.."
TARGET=${1:-native}
FILE=${2:-bench_test.mbt}
moon bench --target "$TARGET" --release -p perfectpan/svgo/benchmark -f "$FILE" 2>&1 |
  awk '
    /^\[perfectpan\/svgo\] bench/ { match($0, /\("[^"]*"\)/); name = substr($0, RSTART + 2, RLENGTH - 4); next }
    /^time \(mean/ { next }
    /±/ && name != "" && $1 ~ /^[0-9.]+$/ { printf "%-32s %s %s\n", name, $1, $2; name = ""; next }
    /^[A-Za-z][A-Za-z0-9_]* +[0-9.]+ +[µmn]?s +±/ { printf "%-32s %s %s\n", $1, $2, $3 }
  '
