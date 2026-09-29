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
/// Copies `text`; the confirmation is the caller's toast (`toast_success`).
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
/// Wires the playground's drag-and-drop: dropping a file anywhere over
/// `#<container_id>` reads its text and hands it to `on_file`, showing
/// `#<overlay_id>` (hidden by default) while a file is dragged over and
/// hiding it again on drop or drag-leave. Delegated on `document` — so it
/// keeps working across playground re-renders without re-attaching to a
/// specific node — and idempotent across route changes: calling it again
/// (the playground page is re-created per route visit, see app.mbt) just
/// rebinds `on_file` to the current page's callback instead of stacking a
/// second set of listeners.
extern "js" fn install_dropzone(
  container_id : String,
  overlay_id : String,
  on_file : (String) -> Unit,
) -> Unit =
  #|(containerId, overlayId, onFile) => {
  #|  window.__pgDropzoneOnFile = onFile;
  #|  if (window.__pgDropzoneInstalled) return;
  #|  window.__pgDropzoneInstalled = true;
  #|  let depth = 0;
  #|  const inZone = (e) => e.target && e.target.closest && e.target.closest("#" + containerId);
  #|  const hasFiles = (e) => e.dataTransfer && Array.prototype.indexOf.call(e.dataTransfer.types || [], "Files") !== -1;
  #|  const setOverlay = (hidden) => { const o = document.getElementById(overlayId); if (o) o.hidden = hidden; };
  #|  document.addEventListener("dragenter", (e) => {
  #|    if (!inZone(e) || !hasFiles(e)) return;
  #|    e.preventDefault();
  #|    depth++;
  #|    setOverlay(false);
  #|  });
  #|  document.addEventListener("dragover", (e) => { if (inZone(e) && hasFiles(e)) e.preventDefault(); });
  #|  document.addEventListener("dragleave", (e) => {
  #|    if (!inZone(e) || !hasFiles(e)) return;
  #|    depth = Math.max(0, depth - 1);
  #|    if (depth === 0) setOverlay(true);
  #|  });
  #|  document.addEventListener("drop", (e) => {
  #|    if (!inZone(e) || !hasFiles(e)) return;
  #|    e.preventDefault();
  #|    depth = 0;
  #|    setOverlay(true);
  #|    const f = e.dataTransfer.files && e.dataTransfer.files[0];
  #|    if (f) f.text().then((t) => window.__pgDropzoneOnFile(t), () => {});
  #|  });
  #|}

///|
/// Carries `dropzone_sub`'s arguments through `@sub.custom_sub`'s `Error`
/// payload (see the built-in subscriptions in rabbita's `sub` package for
/// the same pattern with keydown/resize/etc.) so the drop callback below
/// gets a live `&Scheduler` to dispatch through — calling `msg(text)` on its
/// own only builds a `Cmd` description; nothing runs it unless a scheduler
/// is asked to (`scheduler.add`), which is exactly what a subscription's
/// loader is handed.
priv suberror DropzoneSub {
  Install(String, String, @cmd.Emit[String])
}

///|
fn dropzone_sub_loader(
  payload : Error,
  scheduler : &@cmd.Scheduler,
) -> @sub.RunningSub? {
  match payload {
    DropzoneSub::Install(container_id, overlay_id, msg) => {
      install_dropzone(container_id, overlay_id, text => {
        scheduler.add(msg(text))
      })
      Some({ unload: _ => (), update_tagger: _ => (), })
    }
    _ => None
  }
}

///|
/// Subscription wrapper for `install_dropzone`: dropping a file over
/// `#<container_id>` dispatches `msg` with its text content. Install once
/// from a page's `subscriptions` callback (see `playground_page`) rather
/// than calling `install_dropzone` directly — a bare `emit(msg)` builds a
/// `Cmd` but never runs it outside the update loop, so the drop handler
/// would silently do nothing.
pub fn dropzone_sub(
  container_id : String,
  overlay_id : String,
  msg : @cmd.Emit[String],
) -> @sub.Sub {
  @sub.custom_sub(
    "playground-dropzone",
    Local,
    DropzoneSub::Install(container_id, overlay_id, msg),
    dropzone_sub_loader,
  )
}

///|
/// Tweens the text of a byte-count element from `from` to `to` over 250 ms
/// (the playground's stats bar, on an option change — typing or loading a
/// new file snaps instead, see pg_update). `from` and `to` come from the
/// model, not the DOM: the vdom has usually already patched the element to
/// `to` by the time this runs, so reading its current text back out would
/// find no change to animate.
extern "js" fn tween_int(id : String, from : Int, to : Int) -> Unit =
  #|(id, from, to) => {
  #|  const el = document.getElementById(id);
  #|  if (!el || from === to || matchMedia("(prefers-reduced-motion: reduce)").matches) return;
  #|  const t0 = performance.now(), dur = 250;
  #|  const tick = (now) => {
  #|    const k = Math.min(1, (now - t0) / dur);
  #|    const v = Math.round(from + (to - from) * k);
  #|    el.textContent = (k >= 1 ? to : v).toLocaleString("en-US");
  #|    if (k < 1) requestAnimationFrame(tick);
  #|  };
  #|  requestAnimationFrame(tick);
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
/// a MutationObserver picks up nodes the app renders later. The inline
/// bootstrap script in `public/index.html` sets `motion` on `<html>`
/// synchronously (before first paint, alongside the theme/lang bootstrap) so
/// `.reveal` and the hero keyframes are already hidden in the first frame;
/// this only wires the IntersectionObserver on top of that class and does
/// nothing when the visitor prefers reduced motion (no `motion` class).
extern "js" fn install_motion() -> Unit =
  #|() => {
  #|  if (!("IntersectionObserver" in window) || !document.documentElement.classList.contains("motion")) return;
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
  #|  }, { rootMargin: "0px 0px -25% 0px", threshold: 0.2 });
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
/// Sliding selection for segmented controls, tab rows and the API table of
/// contents: every `[data-slide]` group gets the offset and size of its
/// pressed/selected/current child as `--thumb-x/-y/-w/-h`, which its `::before` (the thumb, see
/// `[data-slide]` in style.css) animates between. `data-ready` is set only
/// after the first placement, so the thumb never slides in from 0 on load
/// and the pressed child keeps its own fill until then. Re-placed on any
/// pressed/selected change, text change (a language switch resizes the
/// items) or resize; the group's `style` is left alone by the vdom since
/// no view sets it.
extern "js" fn install_slides() -> Unit =
  #|() => {
  #|  const place = (g) => {
  #|    const a = g.querySelector(':scope > [aria-pressed="true"], :scope > [aria-selected="true"], :scope > [aria-current="true"]');
  #|    if (!a) { g.removeAttribute("data-ready"); return; }
  #|    g.style.setProperty("--thumb-x", a.offsetLeft + "px");
  #|    g.style.setProperty("--thumb-y", a.offsetTop + "px");
  #|    g.style.setProperty("--thumb-w", a.offsetWidth + "px");
  #|    g.style.setProperty("--thumb-h", a.offsetHeight + "px");
  #|    if (!g.hasAttribute("data-ready")) requestAnimationFrame(() => g.setAttribute("data-ready", ""));
  #|  };
  #|  const ro = new ResizeObserver((es) => es.forEach((e) => place(e.target)));
  #|  const seen = new WeakSet();
  #|  const all = () => document.querySelectorAll("[data-slide]").forEach((g) => {
  #|    if (!seen.has(g)) { seen.add(g); ro.observe(g); }
  #|    place(g);
  #|  });
  #|  let queued = false;
  #|  new MutationObserver(() => {
  #|    if (queued) return;
  #|    queued = true;
  #|    requestAnimationFrame(() => { queued = false; all(); });
  #|  }).observe(document.body, { subtree: true, childList: true, characterData: true, attributes: true, attributeFilter: ["aria-pressed", "aria-selected", "aria-current"] });
  #|  document.fonts && document.fonts.ready.then(all);
  #|  all();
  #|}

///|
/// Call once before mounting the app.
pub fn start_motion() -> Unit {
  install_motion()
  install_slides()
  install_page_transitions()
}

///|
/// Counts an element's text from `from` down (or up) to `to`, once, in
/// place — the hero byte counter. The element is server-rendered showing
/// `to` (its reduced-motion end state), so as soon as this finds it it
/// switches the text to `from` immediately — Nib and the counter are still
/// fading/scaling in at that point (see `.hero-visual` in style.css), so
/// this never flashes the final value before counting down to it. The
/// visible count itself starts 450 ms after the id mounts and runs 720 ms
/// on an easeOutCubic curve; once the value is within 0.5% of `to` it snaps
/// there instead of riding the easing curve's flat tail out, so the count
/// lands crisply. Does nothing under `prefers-reduced-motion` (the element
/// keeps showing `to` throughout). Retries `requestAnimationFrame` until the
/// id mounts, the same pattern as `scroll_to_id`.
extern "js" fn animate_count(id : String, from : Int, to : Int) -> Unit =
  #|(id, from, to) => {
  #|  if (matchMedia("(prefers-reduced-motion: reduce)").matches) return;
  #|  let tries = 60;
  #|  const run = (el) => {
  #|    const span = Math.abs(to - from) || 1;
  #|    const t0 = performance.now(), dur = 720;
  #|    const tick = (now) => {
  #|      const k = Math.min(1, (now - t0) / dur);
  #|      const eased = 1 - Math.pow(1 - k, 3);
  #|      const v = from + (to - from) * eased;
  #|      const done = k >= 1 || Math.abs(to - v) / span <= 0.005;
  #|      el.textContent = (done ? to : Math.round(v)).toLocaleString("en-US");
  #|      if (!done) requestAnimationFrame(tick);
  #|    };
  #|    requestAnimationFrame(tick);
  #|  };
  #|  const start = () => {
  #|    const el = document.getElementById(id);
  #|    if (!el) { if (--tries > 0) requestAnimationFrame(start); return; }
  #|    el.textContent = from.toLocaleString("en-US");
  #|    setTimeout(() => run(el), 450);
  #|  };
  #|  start();
  #|}

///|
pub fn start_count(id : String, from : Int, to : Int) -> Unit {
  animate_count(id, from, to)
}

///|
/// Scroll the element with `id` to the top of the viewport (its
/// `scroll-margin-top` keeps it clear of the fixed nav). The element may not
/// exist yet when a route has just changed, so this retries for up to a second.
extern "js" fn scroll_to_id(id : String) -> Unit =
  #|(id) => {
  #|  let tries = 60;
  #|  const attempt = () => {
  #|    const el = document.getElementById(id);
  #|    if (el) { el.scrollIntoView({ block: "start" }); return; }
  #|    if (--tries > 0) requestAnimationFrame(attempt);
  #|  };
  #|  attempt();
  #|}

///|
/// Flashes the `.api-anchor-flash` background (600ms, see style.css) on the
/// element an API TOC link or deep link points at, so landing mid-page reads
/// as "here" rather than a silent jump. A no-op under reduced motion (the
/// element still scrolls into view via `scroll_to_id`, just without the
/// flash). Retries like `scroll_to_id` since the target may not be mounted
/// yet on a route change; removes and re-adds the class so revisiting the
/// same anchor replays the animation instead of no-op'ing (the class would
/// otherwise already be present with its animation finished).
extern "js" fn highlight_id(id : String) -> Unit =
  #|(id) => {
  #|  if (matchMedia("(prefers-reduced-motion: reduce)").matches) return;
  #|  let tries = 60;
  #|  const attempt = () => {
  #|    const el = document.getElementById(id);
  #|    if (!el) { if (--tries > 0) requestAnimationFrame(attempt); return; }
  #|    el.classList.remove("api-anchor-flash");
  #|    void el.offsetWidth;
  #|    el.classList.add("api-anchor-flash");
  #|  };
  #|  attempt();
  #|}

///|
/// Keep the API sidebar in step with the page: the sidebar link whose
/// `data-target` names the member nearest the top of the viewport gets
/// `aria-current="true"`. Runs on scroll (one pass per frame) and whenever
/// the API view is (re)rendered.
extern "js" fn install_scrollspy() -> Unit =
  #|() => {
  #|  let queued = false;
  #|  const update = () => {
  #|    queued = false;
  #|    const members = document.querySelectorAll(".api-main .member[id]");
  #|    if (!members.length) return;
  #|    let current = members[0];
  #|    for (const m of members) {
  #|      if (m.getBoundingClientRect().top <= 110) current = m; else break;
  #|    }
  #|    const side = document.querySelector(".api-side");
  #|    document.querySelectorAll(".api-side a[data-target]").forEach((a) => {
  #|      if (a.dataset.target === current.id) {
  #|        a.setAttribute("aria-current", "true");
  #|        if (side) {
  #|          const sr = side.getBoundingClientRect();
  #|          const ar = a.getBoundingClientRect();
  #|          if (ar.top < sr.top || ar.bottom > sr.bottom) {
  #|            a.scrollIntoView({ block: "nearest" });
  #|          }
  #|        }
  #|      } else {
  #|        a.removeAttribute("aria-current");
  #|      }
  #|    });
  #|  };
  #|  const schedule = () => { if (!queued) { queued = true; requestAnimationFrame(update); } };
  #|  addEventListener("scroll", schedule, { passive: true });
  #|  addEventListener("resize", schedule);
  #|  new MutationObserver(schedule).observe(document.body, { childList: true, subtree: true });
  #|  schedule();
  #|}

///|
pub fn start_scrollspy() -> Unit {
  install_scrollspy()
}

///|
extern "js" fn load_pref(key : String) -> String =
  #|(key) => { try { return localStorage.getItem(key) || ""; } catch (e) { return ""; } }

///|
extern "js" fn save_pref(key : String, value : String) -> Unit =
  #|(key, value) => { try { localStorage.setItem(key, value); } catch (e) {} }

///|
extern "js" fn browser_lang() -> String =
  #|() => (navigator.language || "en").toLowerCase()

///|
/// `set_theme` for the nav toggle: the new theme spreads as a circle from the
/// visible theme button (a View Transition on the root, animated on its
/// `::view-transition-new` with the site's `--ease-out-soft`). Browsers
/// without View Transitions, and reduced motion, switch at once.
extern "js" fn switch_theme(dark : Bool) -> Unit =
  #|(dark) => {
  #|  const root = document.documentElement;
  #|  const apply = () => { root.dataset.theme = dark ? "dark" : "light"; };
  #|  if (!document.startViewTransition || matchMedia("(prefers-reduced-motion: reduce)").matches) { apply(); return; }
  #|  const b = [...document.querySelectorAll(".icon-btn")].find((e) => e.offsetParent);
  #|  const r = b ? b.getBoundingClientRect() : { left: innerWidth, top: 0, width: 0, height: 0 };
  #|  const x = r.left + r.width / 2, y = r.top + r.height / 2;
  #|  const end = Math.hypot(Math.max(x, innerWidth - x), Math.max(y, innerHeight - y));
  #|  root.classList.add("vt-theme");
  #|  const t = document.startViewTransition(apply);
  #|  t.ready.then(() => root.animate(
  #|    { clipPath: [`circle(0px at ${x}px ${y}px)`, `circle(${end}px at ${x}px ${y}px)`] },
  #|    { duration: 520, easing: getComputedStyle(root).getPropertyValue("--ease-out-soft").trim() || "ease-out", pseudoElement: "::view-transition-new(root)" },
  #|  ));
  #|  t.finished.finally(() => root.classList.remove("vt-theme"));
  #|}

///|
/// Marks `<html>` `routed` on the first hash change, so the page entrance
/// (`.page` in style.css: each page's content fades in rising as it mounts)
/// plays when navigating between pages but not on the first load, where
/// the hero has its own entrance.
extern "js" fn install_page_transitions() -> Unit =
  #|() => {
  #|  addEventListener("hashchange", () => document.documentElement.classList.add("routed"), { once: true });
  #|}

///|
/// `data-theme` on <html> drives the dark palette (see src/style.css); the
/// shell applies the stored value before the first paint.
extern "js" fn set_theme(dark : Bool) -> Unit =
  #|(dark) => { document.documentElement.dataset.theme = dark ? "dark" : "light"; }

///|
/// `lang` on <html> follows the UI language (screen readers, hyphenation,
/// font selection); the shell applies the stored value before the first paint.
extern "js" fn set_document_lang(code : String) -> Unit =
  #|(code) => { document.documentElement.lang = code; }
