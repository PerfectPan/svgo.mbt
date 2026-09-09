#!/usr/bin/env bash
# Build the js-target CLI and place it in the npm package (packages/svgo-mbt).
set -euo pipefail
cd "$(dirname "$0")/.."
moon build --target js --release -q
JS=$(find _build/js/release/build -type f -path "*/svgo-cli/svgo-cli.js" | head -1)
{
  printf '#!/usr/bin/env node\n'
  printf 'import { createRequire } from "node:module";\n'
  printf 'const require = createRequire(import.meta.url);\n'
  cat "$JS"
} > packages/svgo-mbt/cli.mjs
chmod +x packages/svgo-mbt/cli.mjs
ls -la packages/svgo-mbt/cli.mjs
