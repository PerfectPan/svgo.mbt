// In-process throughput of the reference svgo on the same corpus.
// Usage: node harness/speed.mjs <runs> files...
import { readFileSync } from "node:fs";
import { optimize } from "svgo";
const [runs, ...files] = process.argv.slice(2);
const n = Number(runs);
for (const f of files) {
  const src = readFileSync(f, "utf8");
  optimize(src, { multipass: true }); // warm up
  const t0 = performance.now();
  for (let i = 0; i < n; i++) optimize(src, { multipass: true });
  const ms = performance.now() - t0;
  console.log(`${f}: ${n} runs in ${ms.toFixed(1)} ms, ${(ms / n).toFixed(3)} ms/run (svgo-js, multipass)`);
}
