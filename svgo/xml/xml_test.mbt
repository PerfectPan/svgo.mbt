///|
test "roundtrip a typical editor export" {
  let src =
    #|<?xml version="1.0" encoding="UTF-8"?>
    #|<!-- Generator: Sketch 60 -->
    #|<!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.1//EN" "http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd">
    #|<svg xmlns="http://www.w3.org/2000/svg" width="24px" height="24px" viewBox="0 0 24 24">
    #|  <title>icon &amp; close</title>
    #|  <g id="Page-1" fill='#FF0000'>
    #|    <path d="M6 6L18 18"/>
    #|    <text x="1">  keep   spaces </text>
    #|    <style><![CDATA[ .a { fill: red } ]]></style>
    #|  </g>
    #|</svg>
  let doc = @xml.parse(src)
  inspect(doc.children.length(), content="4")
  let root = doc.root().unwrap()
  inspect(root.name, content="svg")
  debug_inspect(root.attrs.get("width"), content="Some(\"24px\")")
  debug_inspect(root.elements().map(e => e.name), content="[\"title\", \"g\"]")
  inspect(
    doc.to_string(),
    content=(
      #|<?xml version="1.0" encoding="UTF-8"?><!-- Generator: Sketch 60 --><!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.1//EN" "http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd"><svg xmlns="http://www.w3.org/2000/svg" width="24px" height="24px" viewBox="0 0 24 24"><title>icon &amp; close</title><g id="Page-1" fill="#FF0000"><path d="M6 6L18 18"/><text x="1">  keep   spaces </text><style><![CDATA[ .a { fill: red } ]]></style></g></svg>
    ),
  )
  inspect(
    doc.to_string(options={ pretty: true, prolog: false, }),
    content=(
      #|<!-- Generator: Sketch 60 -->
      #|<svg xmlns="http://www.w3.org/2000/svg" width="24px" height="24px" viewBox="0 0 24 24">
      #|  <title>icon &amp; close</title>
      #|  <g id="Page-1" fill="#FF0000">
      #|    <path d="M6 6L18 18"/>
      #|    <text x="1">  keep   spaces </text>
      #|    <style><![CDATA[ .a { fill: red } ]]></style>
      #|  </g>
      #|</svg>
      #|
    ),
  )
}

///|
test "entities" {
  let doc = @xml.parse(
    "<svg><text>a &lt; b &amp;&amp; c &#65;&#x42; &unknown; &amp;</text></svg>",
  )
  let root = doc.root().unwrap()
  let text_el = root.children[0]
  let text = match text_el {
    @xml.Node::Element(e) =>
      match e.children[0] {
        @xml.Node::Text(t) => t
        _ => ""
      }
    _ => ""
  }
  inspect(text, content="a < b && c AB &unknown; &")
  let doc = @xml.parse("<svg><text>x &lt; y</text></svg>")
  inspect(doc.to_string(), content="<svg><text>x &lt; y</text></svg>")
}

///|
test "errors" {
  for
    bad in [
      "<svg>", "<svg></g>", "<svg a=1/>", "<svg><!-- x</svg>", "<svg/><svg/>",
    ] {
    try @xml.parse(bad) catch {
      e => println("\{bad} -> \{e}")
    } noraise {
      _ => fail("expected error for \{bad}")
    }
  }
}
