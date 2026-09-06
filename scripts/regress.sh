#!/usr/bin/env bash
# Compare the native CLI output for every fixture against a reference
# directory produced by an earlier build. Usage: scripts/regress.sh <ref-dir>
set -euo pipefail
cd "$(dirname "$0")/.."
REF=${1:?reference directory}
moon build --target native --release -q
BIN=_build/native/release/build/cmd/main/main.exe
status=0
for f in svgo/testdata/*.svg packages/compare/corpus/*.svg; do
  name=$(basename "$f")
  [ -f "$REF/$name" ] || continue
  out=$("$BIN" "$f")
  if [ "$out" != "$(cat "$REF/$name")" ]; then
    echo "DIFF $name ($(printf %s "$out" | wc -c) vs $(wc -c <"$REF/$name") bytes)"
    status=1
  else
    echo "same $name"
  fi
done
exit $status
