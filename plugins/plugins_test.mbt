///|
test "sortAttrs orders known attributes first, then alphabetically" {
  let doc = @xml.parse(
    "<svg xmlns=\"http://www.w3.org/2000/svg\"><path stroke-width=\"2\" d=\"M0 0\" stroke-linecap=\"round\" stroke=\"red\" id=\"a\"/></svg>",
  )
  let changed = (@plugins.sort_attrs.run)(doc, { precision: 3, })
  inspect(changed, content="true")
  inspect(
    doc.to_string(),
    content="<svg xmlns=\"http://www.w3.org/2000/svg\"><path id=\"a\" stroke=\"red\" stroke-linecap=\"round\" stroke-width=\"2\" d=\"M0 0\"/></svg>",
  )
}
