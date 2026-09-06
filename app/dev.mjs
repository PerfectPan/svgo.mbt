// Dev server: build once, serve _build/app, rebuild when anything in app/
// (or the wasm/loader) changes. Usage: pnpm -C app dev   → http://localhost:4173
import { createServer } from "node:http";
import { readFile, stat } from "node:fs/promises";
import { watch } from "node:fs";
import { join, extname } from "node:path";
import { spawn } from "node:child_process";

const ROOT = new URL("..", import.meta.url).pathname;
const OUT = join(ROOT, "_build/app");
const PORT = Number(process.env.PORT || 4173);
const TYPES = { ".html": "text/html; charset=utf-8", ".css": "text/css", ".js": "text/javascript", ".mjs": "text/javascript",
  ".json": "application/json", ".wasm": "application/wasm", ".svg": "image/svg+xml", ".mp4": "video/mp4", ".jpg": "image/jpeg", ".png": "image/png" };

let building = null;
function build() {
  if (building) return building;
  building = new Promise((resolve) => {
    const t0 = Date.now();
    const p = spawn(process.execPath, [join(ROOT, "app/build.mjs")], { stdio: "inherit" });
    p.on("exit", (code) => { console.log(code ? `build failed (${code})` : `built in ${Date.now() - t0} ms`); building = null; resolve(); });
  });
  return building;
}

let timer;
const rebuild = (file) => { clearTimeout(timer); timer = setTimeout(() => { console.log(`changed: ${file}`); build(); }, 150); };
for (const dir of ["app", "packages/svgo-mbt"]) {
  watch(join(ROOT, dir), { recursive: true }, (_, file) => {
    if (!file || file.includes("node_modules") || file.startsWith("motion/")) return;
    rebuild(`${dir}/${file}`);
  });
}

createServer(async (req, res) => {
  let path = decodeURIComponent(new URL(req.url, "http://x").pathname);
  if (path.endsWith("/")) path += "index.html";
  const file = join(OUT, path);
  try {
    await building;
    const s = await stat(file);
    if (!s.isFile()) throw new Error("dir");
    res.writeHead(200, { "content-type": TYPES[extname(file)] || "application/octet-stream", "cache-control": "no-store" });
    res.end(await readFile(file));
  } catch {
    res.writeHead(404, { "content-type": "text/plain" });
    res.end("not found");
  }
}).listen(PORT, async () => {
  await build();
  console.log(`\n  svgo.mbt site → http://localhost:${PORT}/   (playground.html, api.html)\n  watching app/ and packages/svgo-mbt/ for changes\n`);
});
