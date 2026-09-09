#!/usr/bin/env bash
# Build the wasm-gc artifact and place it in the npm package (packages/svgo-mbt).
set -euo pipefail
cd "$(dirname "$0")/.."
moon build --target wasm-gc --release -q
WASM=$(find _build/wasm-gc/release/build -type f -path "*/wasm/wasm.wasm" | head -1)
# Keep the optimizer pinned in package.json/pnpm-lock.yaml. These are the
# features already used by MoonBit's output; no relaxed floating-point passes.
# --converge repeats the pass pipeline until the size stops shrinking (a few
# hundred bytes here); the producers section is metadata nobody reads.
pnpm exec wasm-opt "$WASM" -Oz --converge --strip-producers \
  --enable-gc --enable-reference-types --enable-multivalue \
  --enable-bulk-memory --enable-nontrapping-float-to-int --enable-sign-ext \
  -o packages/svgo-mbt/svgo.wasm
ls -la packages/svgo-mbt/svgo.wasm
