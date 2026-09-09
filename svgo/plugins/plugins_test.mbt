///|
test "sortAttrs orders known attributes first, then alphabetically" {
  let doc = @xml.parse(
    "<svg xmlns=\"http://www.w3.org/2000/svg\"><path stroke-width=\"2\" d=\"M0 0\" stroke-linecap=\"round\" stroke=\"red\" id=\"a\"/></svg>",
  )
  let changed = (@plugins.sort_attrs.run)(doc, @plugins.Context::new())
  inspect(changed, content="true")
  inspect(
    doc.to_string(),
    content="<svg xmlns=\"http://www.w3.org/2000/svg\"><path id=\"a\" stroke=\"red\" stroke-linecap=\"round\" stroke-width=\"2\" d=\"M0 0\"/></svg>",
  )
}

///|
test "percent-encoded id references are decoded before matching" {
  let doc = @xml.parse(
    "<svg><defs><linearGradient id=\"é\"/><linearGradient id=\"a b\"/><linearGradient id=\"\u{1F600}\"/></defs><rect fill=\"url(#%C3%A9)\"/><use href=\"#a%20b\"/><use href=\"#%zz\"/><use href=\"#%F0%9F%98%80\"/></svg>",
  )
  let ctx = @plugins.Context::new()
  ignore((@plugins.find_plugin("cleanupIds").unwrap().run)(doc, ctx))
  inspect(
    doc.to_string(),
    content=(
      #|<svg><defs><linearGradient id="a"/><linearGradient id="b"/><linearGradient id="c"/></defs><rect fill="url(#a)"/><use href="#b"/><use href="#%zz"/><use href="#c"/></svg>
    ),
  )
}
