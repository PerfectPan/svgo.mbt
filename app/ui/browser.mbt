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
extern "js" fn set_palette(name : String) -> Unit =
  #|(name) => {
  #|  if (name === "emerald") delete document.documentElement.dataset.palette;
  #|  else document.documentElement.dataset.palette = name;
  #|  try { localStorage.setItem("svgo-palette", name === "emerald" ? "" : name); } catch (e) {}
  #|}

///|
extern "js" fn get_palette() -> String =
  #|() => document.documentElement.dataset.palette || "emerald"
