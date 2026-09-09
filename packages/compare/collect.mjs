// Collect the numbers the site shows: sizes (original / svgo.mbt / svgo-js)
// and same-process timings (wasm-gc vs svgo-js) for every corpus file.
// Writes app/website/data.json. Usage: node packages/compare/collect.mjs
// Requires scripts/build-wasm.sh and `pnpm install`.
import { readFileSync, writeFileSync, readdirSync, statSync } from "node:fs";
import { join } from "node:path";
import { optimize as jsOptimize } from "svgo";
import { optimize as mbtOptimize, init, plugins } from "svgo-mbt";

const ROOT = new URL("../../", import.meta.url).pathname;
await init();

const files = [
  ...readdirSync(join(ROOT, "svgo/testdata")).filter((f) => f.endsWith(".svg")).map((f) => join(ROOT, "svgo/testdata", f)),
  ...readdirSync(join(ROOT, "packages/compare/corpus")).filter((f) => f.endsWith(".svg") && !f.includes("x12")).map((f) => join(ROOT, "packages/compare/corpus", f)),
];
const bytes = (s) => Buffer.byteLength(s, "utf8");
const time = async (fn, n) => {
  await fn();
  const t0 = performance.now();
  for (let i = 0; i < n; i++) await fn();
  return (performance.now() - t0) / n;
};
const rows = [];
for (const f of files) {
  const src = readFileSync(f, "utf8");
  const size = statSync(f).size;
  const runs = size > 40000 ? 20 : size > 3000 ? 100 : 300;
  const mbt = await mbtOptimize(src);
  const js = jsOptimize(src, { multipass: true }).data;
  const mbtMs = await time(() => mbtOptimize(src), runs);
  const jsMs = await time(() => Promise.resolve(jsOptimize(src, { multipass: true })), runs);
  const row = {
    file: f.split("/").pop(),
    original: bytes(src),
    mbt: mbt.size,
    js: bytes(js),
    mbtMs: +mbtMs.toFixed(3),
    jsMs: +jsMs.toFixed(3),
    passes: mbt.passes,
  };
  rows.push(row);
  console.log(`${row.file.padEnd(34)} ${String(row.original).padStart(7)} -> ${String(row.mbt).padStart(7)} (js ${String(row.js).padStart(7)})  ${row.mbtMs.toFixed(3)} ms vs ${row.jsMs.toFixed(3)} ms`);
}
const data = {
  generated: new Date().toISOString().slice(0, 10),
  node: process.version,
  svgoVersion: JSON.parse(readFileSync(join(ROOT, "packages/compare/node_modules/svgo/package.json"), "utf8")).version,
  wasmBytes: statSync(join(ROOT, "packages/svgo-mbt/svgo.wasm")).size,
  plugins: await plugins(),
  rows,
};
writeFileSync(join(ROOT, "app/website/data.json"), JSON.stringify(data, null, 2) + "\n");
console.log("wrote app/website/data.json");
