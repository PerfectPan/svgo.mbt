///|
/// Micro benchmarks: `moon bench --target native --release` (or wasm-gc / js).
/// Each entry of the corpus is optimized end to end; the parser and the path
/// optimizer are also measured on their own so regressions can be located.
fn corpus_item(name : String) -> String {
  for item in corpus {
    if item.0 == name {
      return item.1
    }
  }
  abort("missing corpus item \{name}")
}

///|
test "optimize sketch-icon" (b : @bench.T) {
  let src = corpus_item("sketch-icon.svg")
  b.bench(() => b.keep(@svgo.optimize(src) catch { _ => abort("optimize") }))
}

///|
test "optimize Tux" (b : @bench.T) {
  let src = corpus_item("Tux.svg")
  b.bench(() => b.keep(@svgo.optimize(src) catch { _ => abort("optimize") }))
}

///|
test "optimize Ghostscript_Tiger" (b : @bench.T) {
  let src = corpus_item("Ghostscript_Tiger.svg")
  b.bench(() => b.keep(@svgo.optimize(src) catch { _ => abort("optimize") }))
}

///|
test "optimize World_map" (b : @bench.T) {
  let src = corpus_item("World_map.svg")
  b.bench(() => b.keep(@svgo.optimize(src) catch { _ => abort("optimize") }))
}

///|
test "xml parse Tiger" (b : @bench.T) {
  let src = corpus_item("Ghostscript_Tiger.svg")
  b.bench(() => b.keep(@xml.parse(src) catch { _ => abort("parse") }))
}

///|
test "xml serialize Tiger" (b : @bench.T) {
  let doc = @xml.parse(corpus_item("Ghostscript_Tiger.svg"))
  b.bench(() => b.keep(doc.to_string()))
}

///|
test "path optimize Tiger paths" (b : @bench.T) {
  let doc = @xml.parse(corpus_item("Ghostscript_Tiger.svg"))
  let ds : Array[String] = []
  doc.each_element((e, _) => if e.attrs.get("d") is Some(d) { ds.push(d) })
  b.bench(() => {
    for d in ds {
      b.keep(@path.optimize_string(d) catch { _ => abort("path") })
    }
  })
}
