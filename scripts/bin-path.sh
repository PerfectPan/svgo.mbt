#!/usr/bin/env bash
# Print the path of the release native CLI binary. moon's output layout has
# changed between versions (with or without the module path), so look it up.
set -euo pipefail
cd "$(dirname "$0")/.."
find _build/native/release/build -type f -name main.exe -path '*cmd/main/*' -not -path '*dSYM*' | head -1
