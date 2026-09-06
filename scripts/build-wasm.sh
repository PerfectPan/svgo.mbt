#!/usr/bin/env bash
# Build the wasm-gc artifact and place it in the npm package (packages/svgo-mbt).
set -euo pipefail
cd "$(dirname "$0")/.."
moon build --target wasm-gc --release -q
cp _build/wasm-gc/release/build/wasm/wasm.wasm packages/svgo-mbt/svgo.wasm
ls -la packages/svgo-mbt/svgo.wasm
