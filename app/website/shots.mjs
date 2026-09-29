// Full-page screenshots of the built site (_build/app) for design review.
// Usage: node app/website/shots.mjs <out-dir> [route ...]
//   routes default to "/", "/playground", "/api"; each is shot at 1440 and
//   390 px, light and dark, English and Chinese (SHOTS_LANGS / SHOTS_THEMES /
//   SHOTS_WIDTHS narrow it, e.g. SHOTS_LANGS=en SHOTS_THEMES=light).
// Headless Chrome over the DevTools protocol, no npm dependencies. Motion is
// switched off (html.motion removed) so the page is shot as a reader sees it settled.
import { spawn } from "node:child_process";
import { createServer } from "node:http";
import { mkdirSync, readFileSync, writeFileSync, existsSync, mkdtempSync } from "node:fs";
import { join, extname } from "node:path";
import { tmpdir } from "node:os";

const ROOT = new URL("../..", import.meta.url).pathname;
const SITE = join(ROOT, "_build/app");
const CHROME = process.env.CHROME ?? "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome";
if (!process.argv[2] || process.argv[2].startsWith("-")) {
  console.log("usage: node app/website/shots.mjs <out-dir> [route ...]  (see the comment at the top)");
  process.exit(process.argv[2] ? 0 : 1);
}
const out = process.argv[2];
const routes = process.argv.slice(3).length ? process.argv.slice(3) : ["/", "/playground", "/api"];
const list = (name, dflt) => (process.env[name] ?? dflt).split(",").filter(Boolean);
const widths = list("SHOTS_WIDTHS", "1440,390").map(Number);
const themes = list("SHOTS_THEMES", "light,dark");
const langs = list("SHOTS_LANGS", "en,zh");
const FREEZE = `*,*::before,*::after{animation-duration:0s!important;animation-delay:0s!important;transition:none!important}
html{scroll-behavior:auto!important}.reveal{opacity:1!important;translate:none!important;transform:none!important}`;

const TYPES = { ".html": "text/html", ".js": "text/javascript", ".css": "text/css", ".svg": "image/svg+xml",
  ".wasm": "application/wasm", ".jpg": "image/jpeg", ".png": "image/png", ".mp4": "video/mp4", ".woff2": "font/woff2", ".webp": "image/webp" };
const server = createServer((req, res) => {
  let p = decodeURIComponent(req.url.split("?")[0]);
  if (p.endsWith("/")) p += "index.html";
  const f = join(SITE, p);
  if (!f.startsWith(SITE) || !existsSync(f)) { res.writeHead(404); res.end(); return; }
  res.writeHead(200, { "content-type": TYPES[extname(f)] ?? "application/octet-stream" });
  res.end(readFileSync(f));
}).listen(0);
const port = server.address().port;

const profile = mkdtempSync(join(tmpdir(), "shots-"));
const chrome = spawn(CHROME, ["--headless=new", "--remote-debugging-port=0", `--user-data-dir=${profile}`,
  "--hide-scrollbars", "--no-first-run", "--force-color-profile=srgb", "about:blank"], { stdio: ["ignore", "ignore", "pipe"] });
const wsUrl = await new Promise((resolve, reject) => {
  let buf = "";
  chrome.stderr.on("data", (d) => { buf += d; const m = buf.match(/ws:\/\/\S+/); if (m) resolve(m[0]); });
  chrome.on("exit", () => reject(new Error("chrome exited: " + buf)));
});
const ws = new WebSocket(wsUrl);
await new Promise((r) => ws.addEventListener("open", r, { once: true }));
let id = 0;
const pending = new Map();
ws.addEventListener("message", (e) => {
  const msg = JSON.parse(e.data);
  if (msg.id && pending.has(msg.id)) { pending.get(msg.id)(msg); pending.delete(msg.id); }
});
const send = (method, params = {}, sessionId) => new Promise((resolve, reject) => {
  const i = ++id;
  pending.set(i, (m) => (m.error ? reject(new Error(`${method}: ${m.error.message}`)) : resolve(m.result)));
  ws.send(JSON.stringify({ id: i, method, params, sessionId }));
});
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

mkdirSync(out, { recursive: true });
const { targetId } = await send("Target.createTarget", { url: "about:blank" });
const { sessionId } = await send("Target.attachToTarget", { targetId, flatten: true });
const s = (m, p) => send(m, p, sessionId);
await s("Page.enable");
await s("Runtime.enable");
const written = [];
for (const route of routes) {
  for (const width of widths) {
    for (const theme of themes) {
      for (const lang of langs) {
        await s("Emulation.setDeviceMetricsOverride", { width, height: width < 800 ? 844 : 900, deviceScaleFactor: 1, mobile: width < 800 });
        await s("Emulation.setEmulatedMedia", { features: [{ name: "prefers-color-scheme", value: theme }, { name: "prefers-reduced-motion", value: "no-preference" }] });
        await s("Page.navigate", { url: `http://127.0.0.1:${port}/` });
        await sleep(300);
        await s("Runtime.evaluate", { expression: `localStorage.setItem("svgo-theme", ${JSON.stringify(theme)}); localStorage.setItem("svgo-lang", ${JSON.stringify(lang)});` });
        // a new query string forces a reload, so the pre-paint script sees the stored prefs
        await s("Page.navigate", { url: `http://127.0.0.1:${port}/?shot=${written.length}#${route}` });
        await sleep(1500);
        await s("Runtime.evaluate", { expression: `(() => { const st = document.createElement("style"); st.textContent = ${JSON.stringify(FREEZE)}; document.head.append(st);
          document.documentElement.classList.remove("motion"); // no hidden .reveal states in a still
          window.scrollTo(0, document.documentElement.scrollHeight); })()` });
        await sleep(600);
        await s("Runtime.evaluate", { expression: "window.scrollTo(0, 0)" });
        await sleep(400);
        const { cssContentSize } = await s("Page.getLayoutMetrics");
        const height = Math.min(Math.ceil(cssContentSize.height), 16000);
        const { data } = await s("Page.captureScreenshot", { format: "png", captureBeyondViewport: true,
          clip: { x: 0, y: 0, width, height, scale: 1 } });
        const name = `${route.replace(/\W+/g, "_").replace(/^_|_$/g, "") || "home"}-${width}-${theme}-${lang}.png`;
        writeFileSync(join(out, name), Buffer.from(data, "base64"));
        written.push(name);
      }
    }
  }
}
console.log(written.map((n) => join(out, n)).join("\n"));
ws.close();
chrome.kill();
server.close();
