#!/usr/bin/env bash
# Build the wasm-gc artifact and place it in the npm package directory.
set -euo pipefail
cd "$(dirname "$0")/.."
moon build --target wasm-gc --release -q
cp _build/wasm-gc/release/build/wasm/wasm.wasm npm/svgo.wasm
ls -la npm/svgo.wasm
