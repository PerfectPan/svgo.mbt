// Build the static site into _build/site:
//   - copies the landing page, playground and styles
//   - copies the wasm build and its loader (npm/)
//   - renders api.html from `moon doc` output (_build/doc/**/package_data.json)
//   - fills the before/after gallery on the landing page from testdata/
// Usage: scripts/build-wasm.sh && moon doc && node site/build.mjs
import { readFileSync, writeFileSync, mkdirSync, copyFileSync, readdirSync, existsSync } from "node:fs";
import { join } from "node:path";
import { optimize, init } from "../npm/index.mjs";

const ROOT = new URL("..", import.meta.url).pathname;
const OUT = join(ROOT, "_build/site");
const REPO = "https://github.com/PerfectPan/svgo.mbt/blob/main";
mkdirSync(OUT, { recursive: true });

const esc = (s) => String(s).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");

// ---------- static files ----------
for (const f of ["style.css", "app.js", "playground.html", "playground.js", "favicon.svg", "data.json", "hero.mp4", "hero-poster.jpg"]) {
  if (existsSync(join(ROOT, "site", f))) copyFileSync(join(ROOT, "site", f), join(OUT, f));
  else console.warn(`site: ${f} missing (hero animation: cd site/motion && npm install && npm run render)`);
}
copyFileSync(join(ROOT, "npm/index.mjs"), join(OUT, "svgo.mjs"));
copyFileSync(join(ROOT, "npm/svgo.wasm"), join(OUT, "svgo.wasm"));
writeFileSync(join(OUT, ".nojekyll"), "");

// ---------- landing page gallery ----------
await init(new URL("../npm/svgo.wasm", import.meta.url));
const shots = [];
for (const f of readdirSync(join(ROOT, "testdata")).filter((f) => f.endsWith(".svg")).sort()) {
  const src = readFileSync(join(ROOT, "testdata", f), "utf8");
  const r = await optimize(src);
  const pct = ((1 - r.size / r.originalSize) * 100).toFixed(0);
  shots.push(`<div class="shot"><div class="pair"><div>${src}</div><div>${r.data}</div></div>
    <div class="meta"><code>${esc(f)}</code><span>${r.originalSize} → <b>${r.size} B</b> · <span class="pill">−${pct}%</span></span></div></div>`);
}
let index = readFileSync(join(ROOT, "site/index.html"), "utf8").replace("<!--GALLERY-->", shots.join("\n"));
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

const nav = readFileSync(join(ROOT, "site/playground.html"), "utf8").match(/<nav class="nav">[\s\S]*?<\/nav>/)[0]
  .replace('<small>playground</small>', '<small>API</small>')
  .replace('<a href="playground.html" aria-current="page">', '<a href="playground.html">')
  .replace('<a href="api.html">', '<a href="api.html" aria-current="page">');
const head = readFileSync(join(ROOT, "site/playground.html"), "utf8").match(/<head>[\s\S]*?<\/head>/)[0]
  .replace(/<title>.*<\/title>/, "<title>svgo.mbt API reference</title>")
  .replace(/<meta name="description"[^>]*>/, '<meta name="description" content="Public API of perfectpan/svgo: optimize, Config, Result, the xml, path and plugins packages.">');
writeFileSync(join(OUT, "api.html"), `<!doctype html>
<html lang="en">
${head}
<body>
${nav}
<div class="wrap api">
  <aside class="api-side">
    <p class="muted" style="font-size:12px;margin-bottom:6px">Generated from <code>moon doc</code>. Also on <a href="https://mooncakes.io/docs/perfectpan/svgo">mooncakes.io</a>.</p>
    ${side}
  </aside>
  <main class="api-main">
    ${main || "<p>Run <code>moon doc</code> before building the site.</p>"}
  </main>
</div>
</body>
</html>
`);

console.log(`site: ${OUT} (${packages.length} packages documented, ${shots.length} gallery items)`);
