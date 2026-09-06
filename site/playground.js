// Playground: full plugin control, samples, file open, share links.
import { init, optimize, plugins } from "./svgo.mjs";

const $ = (s) => document.querySelector(s);
const fmt = (n) => n.toLocaleString("en-US");
const input = $("#in"), out = $("#out");

const SAMPLES = {
  "Sketch icon": `<?xml version="1.0" encoding="UTF-8"?>
<svg width="24px" height="24px" viewBox="0 0 24 24" version="1.1" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink">
    <!-- Generator: Sketch 60.1 (88133) - https://sketch.com -->
    <title>icon/action/close</title>
    <desc>Created with Sketch.</desc>
    <g id="icon/action/close" stroke="none" stroke-width="1" fill="none" fill-rule="evenodd">
        <g id="Group" transform="translate(2.000000, 2.000000)" fill="#FF0000" fill-rule="nonzero">
            <path d="M 4.000000,4.000000 L 16.000000,16.000000 M 16.000000,4.000000 L 4.000000,16.000000" id="Shape" stroke="#FF0000" stroke-width="2.000000" stroke-linecap="round"></path>
            <rect id="Rectangle" fill-opacity="1" x="0" y="0" width="20" height="20" rx="0"></rect>
        </g>
    </g>
</svg>`,
  "Illustrator logo": `<?xml version="1.0" encoding="utf-8"?>
<!-- Generator: Adobe Illustrator 27.0.0, SVG Export Plug-In . SVG Version: 6.00 Build 0)  -->
<svg version="1.1" id="Layer_1" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" x="0px" y="0px"
	 viewBox="0 0 200 200" style="enable-background:new 0 0 200 200;" xml:space="preserve">
<style type="text/css">
	.st0{fill:#1D1D1B;}
	.st1{fill:#E63312;}
</style>
<g id="logo">
	<path class="st0" d="M100,20c-44.2,0-80,35.8-80,80s35.8,80,80,80s80-35.8,80-80S144.2,20,100,20z M100,160c-33.1,0-60-26.9-60-60
		s26.9-60,60-60s60,26.9,60,60S133.1,160,100,160z"/>
	<circle class="st1" cx="100.000000" cy="100.000000" r="30.000000"/>
	<rect x="0" y="0" width="0" height="0" fill="none"/>
</g>
<g id="empty"></g>
</svg>`,
  "Paths & curves": `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
  <path d="M 10,10 L 20,10 L 20,20 L 10,20 L 10,10 Z" fill="rgb(255, 0, 0)"/>
  <path d="M0 0 C 10 10, 20 20, 30 30" stroke="#000000" stroke-width="1"/>
  <path d="M40 40 c 1 1 2 2 3 3 s 2 2 3 3 S 50 50 60 60" stroke="black" fill="none"/>
  <path d="M 1.23456 2.34567 l 0.00001 0 l 5 5" stroke="#00FF00"/>
  <path d="M50 50 A 10 10 0 1 0 70 50 a 0 5 0 0 1 10 10" fill="none" stroke="navy"/>
  <polygon points="80,80 90,80 90,90 80,90" fill="#333333"/>
  <ellipse cx="50" cy="80" rx="5" ry="5"/>
  <g transform="translate(0 0) scale(1)"><g><rect x="0" y="0" width="10" height="10" opacity="1"/></g></g>
</svg>`,
};

let ready = false, list = [];

function currentPlugins() {
  return [...document.querySelectorAll("[data-plugin]")].filter((c) => c.checked).map((c) => c.dataset.plugin);
}
function options() {
  return {
    plugins: currentPlugins(),
    precision: Number($("#precision").value),
    multipass: $("#multipass").checked,
    pretty: $("#pretty").checked,
  };
}

let timer;
async function run() {
  const src = input.value;
  $("#pin").innerHTML = src;
  if (!ready || !src.trim()) { out.value = ""; $("#pout").innerHTML = ""; return; }
  const t0 = performance.now();
  try {
    const r = await optimize(src, options());
    const ms = performance.now() - t0;
    out.value = r.data;
    $("#pout").innerHTML = r.data;
    $("#s-before").textContent = fmt(r.originalSize);
    $("#s-after").textContent = fmt(r.size);
    const pct = r.originalSize ? (1 - r.size / r.originalSize) * 100 : 0;
    $("#s-saved").textContent = `${pct >= 0 ? "−" : "+"}${Math.abs(pct).toFixed(1)}%`;
    $("#s-bar").style.width = `${Math.min(100, Math.max(2, (r.size / r.originalSize) * 100))}%`;
    $("#s-ms").textContent = ms < 1 ? ms.toFixed(2) : ms.toFixed(1);
    $("#s-applied").textContent = `${r.passes} pass${r.passes > 1 ? "es" : ""} · changed by: ${r.applied.join(", ") || "nothing"}`;
  } catch (e) {
    out.value = String(e.message || e);
    $("#pout").innerHTML = "";
    $("#s-saved").textContent = "error";
    $("#s-applied").textContent = "";
  }
}
const schedule = () => { clearTimeout(timer); timer = setTimeout(run, 80); };

function renderPlugins(enabledSet) {
  $("#plugins").innerHTML = list.map((p) => `
    <label class="pl"><input type="checkbox" data-plugin="${p.name}" ${enabledSet.has(p.name) ? "checked" : ""}>
      <span>${p.name}<small>${p.description}</small></span></label>`).join("");
}

// ---------- share links: #v1;precision;multipass;pretty;plugins;base64url(input) ----------
const b64 = {
  enc: (s) => btoa(String.fromCharCode(...new TextEncoder().encode(s))).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, ""),
  dec: (s) => new TextDecoder().decode(Uint8Array.from(atob(s.replace(/-/g, "+").replace(/_/g, "/")), (c) => c.charCodeAt(0))),
};
function readHash() {
  if (!location.hash.startsWith("#v1;")) return null;
  const [, precision, multipass, pretty, plugins, src] = location.hash.slice(1).split(";");
  return { precision, multipass: multipass === "1", pretty: pretty === "1", plugins: plugins ? plugins.split(",") : null, src: src ? b64.dec(src) : "" };
}
function writeHash() {
  const o = options();
  const src = input.value.length < 20000 ? b64.enc(input.value) : "";
  const h = `#v1;${o.precision};${o.multipass ? 1 : 0};${o.pretty ? 1 : 0};${o.plugins.join(",")};${src}`;
  history.replaceState(null, "", h);
  return location.href;
}

// ---------- wiring ----------
const sel = $("#sample");
Object.keys(SAMPLES).forEach((k) => sel.append(new Option(k, k)));
sel.onchange = () => { if (sel.value) { input.value = SAMPLES[sel.value]; run(); } };
$("#file").onchange = async (e) => { const f = e.target.files[0]; if (f) { input.value = await f.text(); run(); } };
input.addEventListener("input", schedule);
document.addEventListener("change", (e) => { if (e.target.closest("#plugins, #precision, #multipass, #pretty")) run(); });
$("#copy").onclick = async () => { try { await navigator.clipboard.writeText(out.value); $("#copy").textContent = "Copied"; setTimeout(() => ($("#copy").textContent = "Copy output"), 900); } catch {} };
$("#download").onclick = () => {
  const a = document.createElement("a");
  a.href = URL.createObjectURL(new Blob([out.value], { type: "image/svg+xml" }));
  a.download = "optimized.svg"; a.click(); URL.revokeObjectURL(a.href);
};
$("#share").onclick = async () => { try { await navigator.clipboard.writeText(writeHash()); $("#share").textContent = "Link copied"; setTimeout(() => ($("#share").textContent = "Share link"), 1200); } catch {} };
$("#reset").onclick = () => { renderPlugins(new Set(list.filter((p) => p.enabled).map((p) => p.name))); $("#precision").value = 3; $("#multipass").checked = true; $("#pretty").checked = false; run(); };
for (const ev of ["dragover", "dragleave", "drop"]) {
  document.addEventListener(ev, async (e) => {
    e.preventDefault();
    document.body.classList.toggle("drop", ev === "dragover");
    if (ev === "drop") { const f = e.dataTransfer.files[0]; if (f) { input.value = await f.text(); run(); } }
  });
}

const shared = readHash();
input.value = shared?.src || SAMPLES["Sketch icon"];
if (shared) { $("#precision").value = shared.precision; $("#multipass").checked = shared.multipass; $("#pretty").checked = shared.pretty; }
$("#pin").innerHTML = input.value;

await init(new URL("./svgo.wasm", import.meta.url));
list = await plugins();
renderPlugins(new Set(shared?.plugins ?? list.filter((p) => p.enabled).map((p) => p.name)));
ready = true;
run();
