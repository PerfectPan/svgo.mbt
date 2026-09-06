// Build the static site into _build/app:
//   - copies the landing page, playground and styles
//   - copies the wasm build and its loader (packages/svgo-mbt)
//   - renders api.html from `moon doc` output (_build/doc/**/package_data.json)
//   - fills the before/after gallery on the landing page from svgo/testdata/
// Usage: scripts/build-wasm.sh && moon -C svgo doc && node app/build.mjs   (pnpm install once)
import { readFileSync, writeFileSync, mkdirSync, copyFileSync, readdirSync, existsSync } from "node:fs";
import { join } from "node:path";
import { spawnSync } from "node:child_process";
import { optimize, init } from "svgo-mbt";

const ROOT = new URL("..", import.meta.url).pathname;
const OUT = join(ROOT, "_build/app");
const REPO = "https://github.com/PerfectPan/svgo.mbt/blob/main/svgo";
mkdirSync(OUT, { recursive: true });

const esc = (s) => String(s).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");

// ---------- static files ----------
// Tailwind v4: app/src/style.css -> _build/app/style.css (needs `cd site && npm install` once)
const tw = spawnSync(join(ROOT, "app/node_modules/.bin/tailwindcss"), ["-i", join(ROOT, "app/src/style.css"), "-o", join(OUT, "style.css"), "--minify"], { stdio: "inherit" });
if (tw.status !== 0) {
  console.error("site: tailwind build failed (run `pnpm install` at the repo root)");
  process.exit(1);
}
for (const f of ["app.js", "playground.html", "playground.js", "favicon.svg", "data.json", "hero.mp4", "hero-poster.jpg"]) {
  if (existsSync(join(ROOT, "app", f))) copyFileSync(join(ROOT, "app", f), join(OUT, f));
  else console.warn(`site: ${f} missing (hero animation: pnpm -C app motion:render)`);
}
copyFileSync(join(ROOT, "packages/svgo-mbt/index.mjs"), join(OUT, "svgo.mjs"));
copyFileSync(join(ROOT, "packages/svgo-mbt/svgo.wasm"), join(OUT, "svgo.wasm"));
writeFileSync(join(OUT, ".nojekyll"), "");

// ---------- landing page gallery ----------
await init();
const shots = [];
for (const f of readdirSync(join(ROOT, "svgo/testdata")).filter((f) => f.endsWith(".svg")).sort()) {
  const src = readFileSync(join(ROOT, "svgo/testdata", f), "utf8");
  const r = await optimize(src);
  const pct = ((1 - r.size / r.originalSize) * 100).toFixed(0);
  shots.push(`<div class="shot"><div class="pair"><div>${src}</div><div>${r.data}</div></div>
    <div class="meta"><code>${esc(f)}</code><span>${r.originalSize} → <b>${r.size} B</b> · <span class="pill">−${pct}%</span></span></div></div>`);
}
let index = readFileSync(join(ROOT, "app/index.html"), "utf8").replace("<!--GALLERY-->", shots.join("\n"));
writeFileSync(join(OUT, "index.html"), index);

// ---------- API reference from moon doc ----------
const DOC = join(ROOT, "_build/doc/perfectpan/svgo");
function findPackages(dir, rel = "") {
  const out = [];
  if (existsSync(join(dir, "package_data.json"))) out.push({ dir, rel });
  for (const e of readdirSync(dir, { withFileTypes: true })) {
    if (e.isDirectory()) out.push(...findPackages(join(dir, e.name), rel ? `${rel}/${e.name}` : e.name));
  }
  return out;
}
const packages = existsSync(DOC) ? findPackages(DOC) : [];
const ORDER = ["", "xml", "path", "plugins", "wasm", "benchmark"];
packages.sort((a, b) => ORDER.indexOf(a.rel) - ORDER.indexOf(b.rel));

// signatures come with <a href="pkg#Name"> links; keep internal ones, unlink core
const anchor = (pkg, name) => `${pkg.replace(/\//g, "-") || "svgo"}-${name}`;
function sig(html) {
  return html.replace(/<a href="([^"]+)#([^"]+)">([^<]+)<\/a>/g, (_, pkg, name, text) =>
    pkg.startsWith("perfectpan/svgo")
      ? `<a href="#${anchor(pkg.replace("perfectpan/svgo", "").replace(/^\//, ""), name)}">${text}</a>`
      : text);
}
function doc(md) {
  if (!md || !md.trim()) return "";
  const paras = md.trim().split(/\n\s*\n/);
  return `<div class="doc">${paras.map((p) => `<p>${esc(p.replace(/\s*\n\s*/g, " ")).replace(/`([^`]+)`/g, "<code>$1</code>")}</p>`).join("")}</div>`;
}
const srcLink = (loc) => loc ? `<a class="src" href="${REPO}/${loc.path.replace("perfectpan/svgo", "").replace(/^\//, "") ? loc.path.replace("perfectpan/svgo", "").replace(/^\//, "") + "/" : ""}${loc.file}#L${loc.line}">source</a>` : "";

function member(pkg, kind, m) {
  const methods = (m.methods || []).map((f) => `
      <h4 id="${anchor(pkg, m.name + "::" + f.name)}">${esc(f.name)}</h4>
      <pre>${sig(f.signature)}</pre>${doc(f.docstring)}`).join("");
  const impls = (m.impls || []).map((i) => `<h4>impl ${sig(`<a href="${i.trait.path}#${i.trait.name}">${i.trait.name}</a>`)}</h4>`).join("");
  return `
  <div class="member" id="${anchor(pkg, m.name)}">
    <h3><span class="kind">${kind}</span>${esc(m.name)}${srcLink(m.loc)}</h3>
    <pre>${sig(m.signature)}</pre>
    ${doc(m.docstring)}
    ${methods || impls ? `<div class="methods">${methods}${impls}</div>` : ""}
  </div>`;
}

let side = "", main = "";
for (const { dir, rel } of packages) {
  if (rel === "benchmark") continue;
  const d = JSON.parse(readFileSync(join(dir, "package_data.json"), "utf8"));
  const title = rel ? `@${rel.split("/").pop()}` : "@svgo";
  const id = anchor(rel, "pkg");
  const items = [
    ...(d.types || []).map((t) => ["type", t]),
    ...(d.errors || []).map((t) => ["error", t]),
    ...(d.traits || []).map((t) => ["trait", t]),
    ...(d.values || []).map((t) => ["fn", t]),
  ];
  side += `<h4><a href="#${id}">${esc(title)}</a></h4>` + items.map(([, m]) => `<a href="#${anchor(rel, m.name)}">${esc(m.name)}</a>`).join("");
  const pkgdoc = existsSync(join(dir, "members.md")) && rel === ""
    ? "" // the root README is long; the landing page covers it
    : "";
  main += `<h2 id="${id}" class="display">perfectpan/svgo${rel ? "/" + rel : ""}</h2>${pkgdoc}` + items.map(([k, m]) => member(rel, k, m)).join("");
}

const nav = readFileSync(join(ROOT, "app/playground.html"), "utf8").match(/<nav class="nav">[\s\S]*?<\/nav>/)[0]
  .replace('font-medium text-muted">playground</small>', 'font-medium text-muted">API</small>')
  .replace(/(<a class="nav-link" href="playground.html") aria-current="page">/, "$1>")
  .replace(/(<a class="nav-link" href="api.html")>/, '$1 aria-current="page">');
const head = readFileSync(join(ROOT, "app/playground.html"), "utf8").match(/<head>[\s\S]*?<\/head>/)[0]
  .replace(/<title>.*<\/title>/, "<title>svgo.mbt API reference</title>")
  .replace(/<meta name="description"[^>]*>/, '<meta name="description" content="Public API of perfectpan/svgo: optimize, Config, Result, the xml, path and plugins packages.">');
writeFileSync(join(OUT, "api.html"), `<!doctype html>
<html lang="en">
${head}
<body>
${nav}
<div class="wrap grid gap-10 pb-20 pt-10 min-[901px]:grid-cols-[240px_1fr]">
  <aside class="api-side text-[13px] min-[901px]:sticky min-[901px]:top-20 min-[901px]:max-h-[calc(100vh-100px)] min-[901px]:self-start min-[901px]:overflow-auto">
    <p class="mb-1.5 text-xs text-muted">Generated from <code>moon doc</code>. Also on <a class="text-ink-2" href="https://mooncakes.io/docs/perfectpan/svgo">mooncakes.io</a>.</p>
    ${side}
  </aside>
  <main class="api-main min-w-0">
    ${main || "<p>Run <code>moon -C svgo doc</code> before building the site.</p>"}
  </main>
</div>
</body>
</html>
`);

console.log(`site: ${OUT} (${packages.length} packages documented, ${shots.length} gallery items)`);
