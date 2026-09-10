///|
test "specificity calculation" {
  let s1 = parse_complex_selector(".btn").unwrap()
  assert_eq(s1.specificity(), { a: 0, b: 0, c: 1, d: 0, })

  let s2 = parse_complex_selector("#header .btn:hover").unwrap()
  assert_eq(s2.specificity(), { a: 0, b: 1, c: 2, d: 0, })

  let s3 = parse_complex_selector("div > span.highlight").unwrap()
  assert_eq(s3.specificity(), { a: 0, b: 0, c: 1, d: 2, })
}

///|
test "parse stylesheet and stringify" {
  let css = "a { color: red; fill: blue; } @media screen { b { margin: 10px; } }"
  let sheet = parse_stylesheet(css)
  assert_eq(sheet.items.length(), 2)
  let minified = sheet.to_css()
  assert_eq(minified, "a{color:red;fill:blue}@media screen{b{margin:10px}}")
}

///|
test "parse declarations" {
  let decls = parse_declarations(
    "fill: red !important; stroke: none; margin: 1em 2em;",
  )
  assert_eq(decls.length(), 3)
  assert_eq(decls[0].name, "fill")
  assert_eq(decls[0].value, "red")
  assert_eq(decls[0].important, true)
  assert_eq(decls[1].name, "stroke")
  assert_eq(decls[1].value, "none")
  assert_eq(decls[1].important, false)
}

///|
test "DOM matching basic" {
  let xml_str =
    #|<svg id="root"><g id="group" class="box"><rect id="r1" class="item primary"/><rect id="r2" class="item"/></g></svg>
  let doc = @xml.parse(xml_str)
  let dom_ctx = DocumentContext::build(doc)

  let sel1 = parse_complex_selector(".item").unwrap()
  let matches1 = dom_ctx.find_all_matches(sel1)
  assert_eq(matches1.length(), 2)

  let sel2 = parse_complex_selector("#group > .primary").unwrap()
  let matches2 = dom_ctx.find_all_matches(sel2)
  assert_eq(matches2.length(), 1)
  assert_eq(dom_ctx.elements[matches2[0]].attrs.get("id"), Some("r1"))

  let sel3 = parse_complex_selector(".box rect").unwrap()
  let matches3 = dom_ctx.find_all_matches(sel3)
  assert_eq(matches3.length(), 2)
}
