// Same-process comparison: svgo.mbt (wasm-gc) vs svgo (JS) on the corpus.
// Usage: node packages/compare/wasm-speed.mjs   (after scripts/build-wasm.sh)
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { optimize as jsOptimize } from "svgo";
import { optimize as mbtOptimize, init } from "svgo-mbt";

const ROOT = new URL("../../", import.meta.url).pathname;
await init();
const files = [
  ["svgo/testdata/sketch-icon.svg", 200],
  ["svgo/testdata/inkscape-drawing.svg", 200],
  ["packages/compare/corpus/SVG_logo.svg", 100],
  ["packages/compare/corpus/Tux.svg", 20],
  ["packages/compare/corpus/Ghostscript_Tiger.svg", 20],
  ["packages/compare/corpus/World_map_-_low_resolution.svg", 20],
];
const time = async (fn, n) => {
  await fn();
  const t0 = performance.now();
  for (let i = 0; i < n; i++) await fn();
  return (performance.now() - t0) / n;
};
console.log("file".padEnd(34), "wasm-gc".padStart(10), "svgo-js".padStart(10), "  ratio");
for (const [f, n] of files) {
  const src = readFileSync(join(ROOT, f), "utf8");
  const a = await time(() => mbtOptimize(src), n);
  const b = await time(() => Promise.resolve(jsOptimize(src, { multipass: true })), n);
  console.log(f.padEnd(34), `${a.toFixed(3)} ms`.padStart(10), `${b.toFixed(3)} ms`.padStart(10), `  ${(b / a).toFixed(1)}x`);
}
