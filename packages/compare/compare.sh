#!/usr/bin/env bash
# Compare svgo.mbt against the reference svgo (Node) on every file in svgo/testdata/.
set -euo pipefail
cd "$(dirname "$0")/../.."
moon build --target native --release -q
BIN=_build/native/release/build/cmd/main/main.exe
mkdir -p _build/compare
printf "%-26s %9s %9s %9s\n" file original svgo.mbt svgo-js
for f in svgo/testdata/*.svg; do
  name=$(basename "$f")
  "$BIN" "$f" -o "_build/compare/$name"
  node packages/compare/node_modules/svgo/bin/svgo -q -i "$f" -o "_build/compare/js-$name" 2>/dev/null || true
  printf "%-26s %9d %9d %9d\n" "$name" "$(wc -c <"$f")" "$(wc -c <"_build/compare/$name")" "$(wc -c <"_build/compare/js-$name" 2>/dev/null || echo 0)"
done
