// Same-process comparison: svgo.mbt (wasm-gc) vs svgo (JS) on the corpus.
// Usage: node harness/wasm-speed.mjs
import { readFileSync } from "node:fs";
import { optimize as jsOptimize } from "svgo";
import { optimize as mbtOptimize, init } from "../npm/index.mjs";

await init(new URL("../npm/svgo.wasm", import.meta.url));
const files = [
  ["testdata/sketch-icon.svg", 200],
  ["testdata/inkscape-drawing.svg", 200],
  ["harness/corpus/SVG_logo.svg", 100],
  ["harness/corpus/Tux.svg", 20],
  ["harness/corpus/Ghostscript_Tiger.svg", 20],
  ["harness/corpus/World_map_-_low_resolution.svg", 20],
];
const time = async (fn, n) => {
  await fn();
  const t0 = performance.now();
  for (let i = 0; i < n; i++) await fn();
  return (performance.now() - t0) / n;
};
console.log("file".padEnd(34), "wasm-gc".padStart(10), "svgo-js".padStart(10), "  ratio");
for (const [f, n] of files) {
  const src = readFileSync(f, "utf8");
  const a = await time(() => mbtOptimize(src), n);
  const b = await time(() => Promise.resolve(jsOptimize(src, { multipass: true })), n);
  console.log(f.padEnd(34), `${a.toFixed(3)} ms`.padStart(10), `${b.toFixed(3)} ms`.padStart(10), `  ${(b / a).toFixed(1)}x`);
}
