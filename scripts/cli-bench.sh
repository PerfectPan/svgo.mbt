#!/usr/bin/env bash
# Cold-start comparison of the three command lines on one small file: the
# native binary, the Node build (packages/svgo-mbt/cli.mjs) and the svgo CLI
# from packages/compare's node_modules. Each is run RUNS times end to end in a
# fresh process; the mean and the fastest run are printed in milliseconds.
# These are the numbers quoted on the site and in the README.
#   scripts/cli-bench.sh [file] [runs]
set -euo pipefail
cd "$(dirname "$0")/.."
FILE=${1:-svgo/testdata/sketch-icon.svg}
RUNS=${2:-20}
moon build --target native --release -q
[ -f packages/svgo-mbt/cli.mjs ] || scripts/build-cli.sh >/dev/null
NATIVE=$(scripts/bin-path.sh)
SVGO=packages/compare/node_modules/svgo/bin/svgo.js
[ -f "$SVGO" ] || { echo "svgo CLI missing: run pnpm install" >&2; exit 1; }
python3 - "$FILE" "$RUNS" "$NATIVE" "$SVGO" <<'EOF'
import subprocess, sys, time
file, runs, native, svgo = sys.argv[1], int(sys.argv[2]), sys.argv[3], sys.argv[4]
commands = [
    ("svgo.mbt native", [native, file, "-o", "/dev/null"]),
    ("svgo.mbt node (cli.mjs)", ["node", "packages/svgo-mbt/cli.mjs", file, "-o", "/dev/null"]),
    ("svgo CLI (node)", ["node", svgo, "--quiet", file, "-o", "/dev/null"]),
]
print(f"{'command':28} {'mean ms':>9} {'min ms':>8}   ({runs} runs, {file})")
for name, cmd in commands:
    subprocess.run(cmd, check=True, capture_output=True)  # warm the page cache
    samples = []
    for _ in range(runs):
        t = time.perf_counter()
        subprocess.run(cmd, check=True, capture_output=True)
        samples.append((time.perf_counter() - t) * 1000)
    print(f"{name:28} {sum(samples)/len(samples):9.1f} {min(samples):8.1f}")
EOF
