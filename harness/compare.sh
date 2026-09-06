#!/usr/bin/env bash
# Compare svgo.mbt against the reference svgo (Node) on every file in testdata/.
set -euo pipefail
cd "$(dirname "$0")/.."
moon build --target native -q
BIN=_build/native/debug/build/cmd/main/main.exe
mkdir -p _build/harness
printf "%-26s %9s %9s %9s\n" file original svgo.mbt svgo-js
for f in testdata/*.svg; do
  name=$(basename "$f")
  "$BIN" "$f" -o "_build/harness/$name"
  npx --yes svgo -q -i "$f" -o "_build/harness/js-$name" 2>/dev/null || true
  printf "%-26s %9d %9d %9d\n" "$name" "$(wc -c <"$f")" "$(wc -c <"_build/harness/$name")" "$(wc -c <"_build/harness/js-$name" 2>/dev/null || echo 0)"
done
