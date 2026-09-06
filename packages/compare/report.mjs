// Build an HTML report showing every testdata SVG before/after optimisation
// side by side with sizes and pixel diffs. Output: _build/compare/report.html
import { readFileSync, readdirSync, writeFileSync, mkdirSync } from "node:fs";
import { join } from "node:path";

const ROOT = new URL("../../", import.meta.url).pathname;
const TESTDATA = join(ROOT, "svgo/testdata");
import { execFileSync } from "node:child_process";
import { Resvg } from "@resvg/resvg-js";
import pixelmatch from "pixelmatch";
import { PNG } from "pngjs";

const bin = join(ROOT, "_build/native/release/build/cmd/main/main.exe");
mkdirSync(join(ROOT, "_build/compare"), { recursive: true });
const files = readdirSync(TESTDATA).filter((f) => f.endsWith(".svg"));
const render = (svg) => PNG.sync.read(new Resvg(svg, { fitTo: { mode: "width", value: 256 } }).render().asPng());
const esc = (s) => s.replace(/&/g, "&amp;").replace(/</g, "&lt;");
let rows = "";
for (const f of files) {
  const src = readFileSync(join(TESTDATA, f), "utf8");
  const ours = execFileSync(bin, [join(TESTDATA, f)], { encoding: "utf8" }).trim();
  let js = "";
  try { js = execFileSync("node", [join(ROOT, "packages/compare/node_modules/svgo/bin/svgo"), "-q", "-i", join(TESTDATA, f), "-o", "-"], { encoding: "utf8" }).trim(); } catch {}
  const a = render(src), b = render(ours);
  const diffPng = new PNG({ width: a.width, height: a.height });
  const diff = pixelmatch(a.data, b.data, diffPng.data, a.width, a.height, { threshold: 0.1 });
  const pct = (n) => ((1 - n / src.length) * 100).toFixed(1);
  rows += `
  <section>
    <h2>${f} <small>${src.length} B → <b>${ours.length} B</b> (−${pct(ours.length)}%)${js ? ` · svgo-js ${js.length} B (−${pct(js.length)}%)` : ""} · diff pixels: <b>${diff}</b></small></h2>
    <div class="row">
      <figure><figcaption>original</figcaption><div class="box">${src}</div></figure>
      <figure><figcaption>svgo.mbt</figcaption><div class="box">${ours}</div></figure>
      <figure><figcaption>pixel diff (red = changed)</figcaption><div class="box"><img src="data:image/png;base64,${PNG.sync.write(diffPng).toString("base64")}"></div></figure>
    </div>
    <details><summary>source</summary><div class="code"><pre>${esc(src)}</pre><pre>${esc(ours)}</pre></div></details>
  </section>`;
}
const html = `<!doctype html><meta charset="utf-8"><title>svgo.mbt report</title>
<style>
body{font:14px/1.5 -apple-system,system-ui,sans-serif;margin:32px;color:#222;background:#fafafa}
h2{font-size:16px;margin:32px 0 8px} small{font-weight:normal;color:#666}
.row{display:grid;grid-template-columns:repeat(3,1fr);gap:16px}
figure{margin:0} figcaption{color:#666;margin-bottom:4px}
.box{background:#fff url('data:image/svg+xml,<svg xmlns=%22http://www.w3.org/2000/svg%22 width=%2216%22 height=%2216%22><rect width=%228%22 height=%228%22 fill=%22%23eee%22/><rect x=%228%22 y=%228%22 width=%228%22 height=%228%22 fill=%22%23eee%22/></svg>');border:1px solid #ddd;height:260px;display:flex;align-items:center;justify-content:center;overflow:hidden}
.box svg,.box img{max-width:240px;max-height:240px;width:auto;height:auto}
.code{display:grid;grid-template-columns:1fr 1fr;gap:12px} pre{background:#fff;border:1px solid #ddd;padding:8px;overflow:auto;font-size:11px;white-space:pre-wrap;word-break:break-all}
</style><h1>svgo.mbt: before / after</h1><p>Left: input as exported by the editor. Middle: output of <code>svgo.mbt</code>. Right: pixel difference of the two renderings (resvg, 256px wide).</p>${rows}`;
writeFileSync(join(ROOT, "_build/compare/report.html"), html);
console.log("wrote _build/compare/report.html");
