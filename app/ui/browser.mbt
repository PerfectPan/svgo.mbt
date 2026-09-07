///|
/// Small browser bindings the framework does not wrap. The js backend
/// compiles these to plain JavaScript.
extern "js" fn perf_now() -> Double = "() => performance.now()"

///|
extern "js" fn download_text(name : String, text : String) -> Unit =
  #|(name, text) => {
  #|  const a = document.createElement("a");
  #|  a.href = URL.createObjectURL(new Blob([text], { type: "image/svg+xml" }));
  #|  a.download = name;
  #|  a.click();
  #|  URL.revokeObjectURL(a.href);
  #|}

///|
extern "js" fn copy_text(text : String) -> Unit =
  #|(text) => { navigator.clipboard && navigator.clipboard.writeText(text); }

///|
/// Read the first file of an `<input type=file>` and hand its text to `cb`
/// (empty string when nothing is selected).
extern "js" fn read_first_file(
  input_id : String,
  cb : (String) -> Unit,
) -> Unit =
  #|(id, cb) => {
  #|  const el = document.getElementById(id);
  #|  const f = el && el.files && el.files[0];
  #|  if (!f) { cb(""); return; }
  #|  f.text().then(cb, () => cb(""));
  #|}

///|
extern "js" fn b64_encode(s : String) -> String =
  #|(s) => btoa(String.fromCharCode(...new TextEncoder().encode(s)))
  #|  .replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "")

///|
extern "js" fn b64_decode(s : String) -> String =
  #|(s) => {
  #|  try {
  #|    return new TextDecoder().decode(
  #|      Uint8Array.from(atob(s.replace(/-/g, "+").replace(/_/g, "/")), (c) => c.charCodeAt(0)));
  #|  } catch { return ""; }
  #|}

///|
extern "js" fn location_href() -> String = "() => location.href"

///|
extern "js" fn replace_url(url : String) -> Unit =
  #|(url) => history.replaceState(null, "", url)

///|
extern "js" fn to_fixed(d : Double, digits : Int) -> String =
  #|(d, n) => d.toFixed(n)

///|
extern "js" fn with_commas(n : Int) -> String =
  #|(n) => n.toLocaleString("en-US")

///|
/// Milliseconds with a sensible number of digits.
pub fn fmt_ms(ms : Double) -> String {
  if ms < 1.0 {
    to_fixed(ms, 2)
  } else if ms < 10.0 {
    to_fixed(ms, 1)
  } else {
    to_fixed(ms, 0)
  }
}

///|
pub fn fmt_kb(bytes : Int) -> String {
  if bytes >= 20000 {
    "\{bytes / 1024} KB"
  } else if bytes >= 1024 {
    "\{to_fixed(bytes.to_double() / 1024.0, 1)} KB"
  } else {
    "\{bytes} B"
  }
}

///|
pub fn fmt_int(n : Int) -> String {
  with_commas(n)
}

///|
pub fn fmt_pct(p : Double, digits? : Int = 1) -> String {
  to_fixed(p, digits)
}

///|
/// Decorative motion: scroll-triggered reveals (`.reveal` gets `.in` when it
/// enters the viewport) and number count-ups (`data-count`). Installed once;
/// a MutationObserver picks up nodes the app renders later. Adds `motion` to
/// <html> so the stylesheet only hides `.reveal` elements while this runs,
/// and does nothing when the visitor prefers reduced motion.
extern "js" fn install_motion() -> Unit =
  #|() => {
  #|  if (!("IntersectionObserver" in window) || matchMedia("(prefers-reduced-motion: reduce)").matches) return;
  #|  document.documentElement.classList.add("motion");
  #|  const count = (el) => {
  #|    const raw = el.dataset.count, target = parseFloat(raw), final = el.textContent;
  #|    if (!target || el.dataset.counted) return;
  #|    el.dataset.counted = "1";
  #|    const dec = (raw.split(".")[1] || "").length, t0 = performance.now(), dur = 1400;
  #|    const tick = (now) => {
  #|      const k = Math.min(1, (now - t0) / dur), e = 1 - Math.pow(1 - k, 3);
  #|      el.textContent = k >= 1 ? final : final.replace(raw, (target * e).toFixed(dec));
  #|      if (k < 1) requestAnimationFrame(tick);
  #|    };
  #|    requestAnimationFrame(tick);
  #|  };
  #|  const io = new IntersectionObserver((entries) => {
  #|    for (const e of entries) {
  #|      if (!e.isIntersecting) continue;
  #|      io.unobserve(e.target);
  #|      e.target.classList.add("in");
  #|      if (e.target.dataset.count) count(e.target);
  #|      e.target.querySelectorAll("[data-count]").forEach(count);
  #|    }
  #|  }, { rootMargin: "0px 0px -8% 0px", threshold: 0.1 });
  #|  const scan = (root) => {
  #|    if (root.nodeType !== 1) return;
  #|    if (root.classList.contains("reveal") && !root.classList.contains("in")) io.observe(root);
  #|    root.querySelectorAll(".reveal:not(.in)").forEach((el) => io.observe(el));
  #|  };
  #|  scan(document.documentElement);
  #|  new MutationObserver((ms) => ms.forEach((m) => m.addedNodes.forEach(scan)))
  #|    .observe(document.body, { childList: true, subtree: true });
  #|}

///|
/// Call once before mounting the app.
pub fn start_motion() -> Unit {
  install_motion()
}
