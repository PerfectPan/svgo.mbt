#!/usr/bin/env bash
# The whole verification suite in one command; CI runs the same steps.
#   scripts/verify.sh          fast: check, fmt, interface drift, tests on 3 backends
#   scripts/verify.sh --full   also builds wasm, compares sizes with svgo-js and
#                              renders every fixture to check for pixel diffs
set -euo pipefail
cd "$(dirname "$0")/.."

step() { printf '\n\033[1m== %s\033[0m\n' "$*"; }

step "moon check"
moon check -q
step "moon fmt --check"
moon fmt --check
step "moon info (interface files must be committed up to date)"
moon info -q
if ! git diff --quiet -- '*.mbti'; then
  echo "generated .mbti files changed; review and commit them:" >&2
  git --no-pager diff --stat -- '*.mbti' >&2
  exit 1
fi
for target in wasm-gc js native; do
  step "moon test --target $target"
  moon test --target "$target" -q
done
step "fixtures are in sync with svgo/plugins/fixtures/*.txt"
python3 scripts/gen-fixtures.py --check

if [ "${1:-}" = "--full" ]; then
  step "wasm artifact"
  scripts/build-wasm.sh
  step "native CLI smoke test"
  moon build --target native --release -q
  _build/native/release/build/cmd/main/main.exe svgo/testdata/sketch-icon.svg --json >/dev/null
  step "compare: sizes vs svgo-js, render diff, same-process speed"
  pnpm install --frozen-lockfile --silent
  packages/compare/compare.sh
  node packages/compare/render-diff.mjs
  node packages/compare/wasm-speed.mjs
fi
printf '\n\033[32mall good\033[0m\n'
