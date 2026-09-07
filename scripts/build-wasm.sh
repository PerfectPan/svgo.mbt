#!/usr/bin/env bash
# Build the wasm-gc artifact and place it in the npm package (packages/svgo-mbt).
set -euo pipefail
cd "$(dirname "$0")/.."
moon build --target wasm-gc --release -q
WASM=$(find _build/wasm-gc/release/build -type f -path "*/wasm/wasm.wasm" | head -1)
cp "$WASM" packages/svgo-mbt/svgo.wasm
ls -la packages/svgo-mbt/svgo.wasm
