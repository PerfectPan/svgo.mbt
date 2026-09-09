#!/usr/bin/env bash
# The whole verification suite in one command; CI runs the same steps.
#   scripts/verify.sh          fast: check, fmt, interface drift, tests on js and native
#   scripts/verify.sh --full   also builds wasm, compares sizes with svgo-js and
#                              renders every fixture to check for pixel diffs
set -euo pipefail
cd "$(dirname "$0")/.."

step() { printf '\n\033[1m== %s\033[0m\n' "$*"; }

step "no merge conflict markers"
if git grep -n -E '^(<<<<<<< |>>>>>>> )' -- . ':!node_modules'; then
  echo "unresolved merge conflict markers (see above)" >&2
  exit 1
fi
step "one version everywhere (scripts/sync-version.mjs)"
node scripts/sync-version.mjs --check
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
# Not wasm-gc: svgo/path/host_wasm.mbt imports Math and Number.parseFloat from
# the embedder, which moonrun does not provide. The wasm artifact is tested
# through node in --full (packages/svgo-mbt, including the fixture suite).
for target in js native; do
  step "moon test --target $target"
  moon test --target "$target" -q
done
step "fixtures are in sync with svgo/plugins/fixtures/*.txt"
python3 scripts/gen-fixtures.py --check

if [ "${1:-}" = "--full" ]; then
  step "JS build and comparison dependencies"
  pnpm install --frozen-lockfile --silent
  step "wasm artifact"
  scripts/build-wasm.sh
  step "npm package tests (node --test)"
  (cd packages/svgo-mbt && node --test)
  step "native CLI smoke test"
  moon build --target native --release -q
  "$(scripts/bin-path.sh)" svgo/testdata/sketch-icon.svg --json >/dev/null
  step "compare: sizes vs svgo-js, render diff, same-process speed"
  packages/compare/compare.sh
  node packages/compare/render-diff.mjs
  node packages/compare/wasm-speed.mjs
fi
printf '\n\033[32mall good\033[0m\n'
