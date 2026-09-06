///|
/// Per-plugin cost on the Tiger, one pass each on a freshly parsed document.
/// The parse itself costs about 0.7 ms and is included in every number.
test "profile plugins on Tiger" (b : @bench.T) {
  let src = corpus_item("Ghostscript_Tiger.svg")
  let ctx : @plugins.Context = { precision: 3 }
  for p in @plugins.preset_default {
    b.bench(name=p.name, () => {
      let doc = @xml.parse(src) catch { _ => abort("parse") }
      b.keep((p.run)(doc, ctx))
    })
  }
}
