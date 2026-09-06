// Landing page behaviour: live demo, benchmark charts, plugin grid.
import { init, optimize, plugins } from "./svgo.mjs";

const $ = (s, el = document) => el.querySelector(s);
const fmt = (n) => n.toLocaleString("en-US");
const esc = (s) => String(s).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");

// ---------- samples for the hero demo ----------
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
  "Figma export": `<svg width="120" height="120" viewBox="0 0 120 120" fill="none" xmlns="http://www.w3.org/2000/svg">
<g clip-path="url(#clip0_1_2)">
<rect width="120" height="120" rx="24" fill="#5B8DEF"/>
<path d="M36 60C36 46.7452 46.7452 36 60 36C73.2548 36 84 46.7452 84 60C84 73.2548 73.2548 84 60 84" stroke="white" stroke-width="8" stroke-linecap="round"/>
<circle cx="60" cy="84" r="6" fill="#FFFFFF" fill-opacity="1"/>
</g>
<defs>
<clipPath id="clip0_1_2">
<rect width="120" height="120" fill="white"/>
</clipPath>
</defs>
</svg>`,
  "Inkscape drawing": `<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<!-- Created with Inkscape (http://www.inkscape.org/) -->
<svg
   width="64mm"
   height="64mm"
   viewBox="0 0 64 64"
   version="1.1"
   id="svg1"
   inkscape:version="1.3.2 (091e20e, 2023-11-25)"
   sodipodi:docname="drawing.svg"
   xmlns:inkscape="http://www.inkscape.org/namespaces/inkscape"
   xmlns:sodipodi="http://sodipodi.sourceforge.net/DTD/sodipodi-0.dtd"
   xmlns="http://www.w3.org/2000/svg"
   xmlns:svg="http://www.w3.org/2000/svg">
  <sodipodi:namedview
     id="namedview1"
     pagecolor="#ffffff"
     bordercolor="#000000"
     inkscape:zoom="2.8284271"
     inkscape:cx="120.91525"
     inkscape:current-layer="layer1" />
  <defs
     id="defs1" />
  <g
     inkscape:label="Layer 1"
     inkscape:groupmode="layer"
     id="layer1">
    <path
       style="fill:#ff7f2a;stroke:#000000;stroke-width:1.5;stroke-linejoin:round"
       d="m 12.000001,44.000001 c 0,-12 8,-24 20,-24 12,0 20,12 20,24 0,4 -4,8 -8,8 H 20.000001 c -4,0 -8,-4 -8,-8 z"
       id="path1"
       sodipodi:nodetypes="csssssc" />
    <circle
       style="fill:#ffffff;stroke:#000000;stroke-width:1.5"
       id="path2"
       cx="24.000000"
       cy="36.000000"
       r="3.0000000" />
    <circle
       style="fill:#ffffff;stroke:#000000;stroke-width:1.5"
       id="path3"
       cx="40.000000"
       cy="36.000000"
       r="3.0000000" />
  </g>
</svg>`,
};

// ---------- hero demo ----------
async function demo() {
  const tabs = $("#samples");
  const input = $("#in");
  const out = $("#out");
  let ready = false;

  Object.keys(SAMPLES).forEach((name, i) => {
    const b = document.createElement("button");
    b.className = "chip";
    b.role = "tab";
    b.textContent = name;
    b.setAttribute("aria-selected", i === 0);
    b.onclick = () => {
      tabs.querySelectorAll(".chip").forEach((c) => c.setAttribute("aria-selected", c === b));
      input.value = SAMPLES[name];
      run();
    };
    tabs.append(b);
  });
  // ?sample=Inkscape%20drawing preselects a tab
  const wanted = new URLSearchParams(location.search).get("sample");
  const initial = wanted && SAMPLES[wanted] ? wanted : "Sketch icon";
  input.value = SAMPLES[initial];
  tabs.querySelectorAll(".chip").forEach((c) => c.setAttribute("aria-selected", c.textContent === initial));

  let timer;
  async function run() {
    const src = input.value;
    $("#pin").innerHTML = src;
    if (!ready) return;
    const t0 = performance.now();
    try {
      const r = await optimize(src);
      const ms = performance.now() - t0;
      out.value = r.data;
      $("#pout").innerHTML = r.data;
      $("#s-before").textContent = fmt(r.originalSize);
      $("#s-after").textContent = fmt(r.size);
      const pct = r.originalSize ? (1 - r.size / r.originalSize) * 100 : 0;
      $("#s-saved").textContent = `−${pct.toFixed(1)}%`;
      $("#s-bar").style.width = `${Math.max(2, (r.size / r.originalSize) * 100)}%`;
      $("#s-ms").textContent = ms < 1 ? ms.toFixed(2) : ms.toFixed(1);
      $("#s-passes").textContent = `${r.passes} pass${r.passes > 1 ? "es" : ""} · ${r.applied.length} plugins changed something`;
    } catch (e) {
      out.value = String(e.message || e);
      $("#s-saved").textContent = "parse error";
    }
  }
  input.addEventListener("input", () => { clearTimeout(timer); timer = setTimeout(run, 80); });

  // drag and drop an .svg onto the card
  const card = $("#demo");
  card.addEventListener("dragover", (e) => { e.preventDefault(); card.classList.add("drop"); });
  card.addEventListener("dragleave", () => card.classList.remove("drop"));
  card.addEventListener("drop", async (e) => {
    e.preventDefault(); card.classList.remove("drop");
    const f = e.dataTransfer.files[0];
    if (f) { input.value = await f.text(); run(); }
  });

  run();
  await init(new URL("./svgo.wasm", import.meta.url));
  ready = true;
  run();
}

// ---------- numbers ----------
async function numbers() {
  const data = await (await fetch("data.json")).json();
  document.querySelectorAll("[data-wasm-kb]").forEach((el) => (el.textContent = Math.round(data.wasmBytes / 1024)));
  document.querySelectorAll("[data-svgo-version]").forEach((el) => (el.textContent = data.svgoVersion));
  const rows = data.rows.slice().sort((a, b) => a.original - b.original);
  const ratios = rows.map((r) => r.jsMs / r.mbtMs).sort((a, b) => a - b);
  const median = ratios[Math.floor(ratios.length / 2)];
  document.querySelectorAll("[data-kpi-speed]").forEach((el) => (el.textContent = `${median.toFixed(1)}×`));

  // log-scale bars: width ∝ log(ms / min) so 0.04 ms and 50 ms both stay visible
  const all = rows.flatMap((r) => [r.mbtMs, r.jsMs]);
  const lo = Math.min(...all) / 1.5, hi = Math.max(...all) * 1.15;
  const width = (ms) => `${(Math.log(ms / lo) / Math.log(hi / lo)) * 78}%`;
  const kb = (n) => (n >= 1024 ? `${(n / 1024).toFixed(n > 20000 ? 0 : 1)} KB` : `${n} B`);
  $("#bench-rows").innerHTML = rows.map((r) => `
    <div class="row">
      <div class="name" title="${r.file}">${r.file.replace(/_/g, " ").replace(".svg", "")}<small>${kb(r.original)}</small></div>
      <div class="bars">
        <div class="bar bar-a" style="width:${width(r.mbtMs)}" data-label="${r.mbtMs.toFixed(r.mbtMs < 1 ? 2 : 1)} ms"></div>
        <div class="bar bar-b" style="width:${width(r.jsMs)}" data-label="${r.jsMs.toFixed(r.jsMs < 1 ? 2 : 1)} ms"></div>
      </div>
      <div class="ratio">${(r.jsMs / r.mbtMs).toFixed(1)}×</div>
    </div>`).join("");

  $("#size-rows").innerHTML = `<tr><th>file</th><th>original</th><th>svgo.mbt</th><th>svgo-js</th></tr>` +
    rows.map((r) => {
      const cls = r.mbt < r.js ? "win" : r.mbt > r.js ? "lose" : "";
      return `<tr><td>${r.file.replace(/_/g, " ").replace(".svg", "")}</td><td>${fmt(r.original)}</td><td class="${cls}">${fmt(r.mbt)}</td><td>${fmt(r.js)}</td></tr>`;
    }).join("");

  // plugin grid comes from the same JSON so it always matches the build
  $("#plugin-grid").innerHTML = data.plugins.map((p) =>
    `<div class="plugin${p.enabled ? "" : " plugin-optional"}"><code>${esc(p.name)}</code><p>${esc(p.description)}</p></div>`).join("");
  document.querySelectorAll("[data-plugin-count]").forEach((el) => (el.textContent = data.plugins.filter((p) => p.enabled).length));
}

// ---------- copy buttons ----------
document.querySelectorAll("[data-copy]").forEach((b) => {
  b.addEventListener("click", async () => {
    try { await navigator.clipboard.writeText(b.dataset.copy); b.style.color = "var(--good)"; setTimeout(() => (b.style.color = ""), 900); } catch {}
  });
});

numbers();
demo();
