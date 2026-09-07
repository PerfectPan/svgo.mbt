// Rasterize every SVG in a directory before and after optimization and report the
// number of differing pixels. Usage: node packages/compare/render-diff.mjs [dir]
// (default: svgo/testdata; try packages/compare/corpus for the big files)
import { readFileSync, readdirSync } from "node:fs";
import { join, resolve } from "node:path";

const ROOT = new URL("../../", import.meta.url).pathname;
const TESTDATA = process.argv[2] ? resolve(process.argv[2]) : join(ROOT, "svgo/testdata");
import { execFileSync } from "node:child_process";
import { Resvg } from "@resvg/resvg-js";
import pixelmatch from "pixelmatch";
import { PNG } from "pngjs";

const bin = execFileSync(join(ROOT, "scripts/bin-path.sh"), { encoding: "utf8" }).trim();
const files = readdirSync(TESTDATA).filter((f) => f.endsWith(".svg"));
const render = (svg) => {
  const r = new Resvg(svg, { fitTo: { mode: "width", value: 256 } });
  return PNG.sync.read(r.render().asPng());
};
let failed = 0;
for (const f of files) {
  const src = readFileSync(join(TESTDATA, f), "utf8");
  const out = execFileSync(bin, [join(TESTDATA, f)], { encoding: "utf8" }).trim();
  const a = render(src);
  const b = render(out);
  if (a.width !== b.width || a.height !== b.height) {
    console.log(`${f}: size mismatch ${a.width}x${a.height} vs ${b.width}x${b.height}`);
    failed++;
    continue;
  }
  const diff = pixelmatch(a.data, b.data, null, a.width, a.height, { threshold: 0.1 });
  const pct = ((diff / (a.width * a.height)) * 100).toFixed(3);
  console.log(`${f.padEnd(26)} ${String(src.length).padStart(7)} -> ${String(out.length).padStart(7)} bytes  diff pixels: ${diff} (${pct}%)`);
  if (diff > a.width * a.height * 0.001) failed++;
}
process.exit(failed ? 1 : 0);
