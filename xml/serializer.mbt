///|
pub(all) struct SerializeOptions {
  /// indent with newlines and two spaces per level
  pretty : Bool
  /// emit the `<?xml ...?>` and doctype nodes
  prolog : Bool
} derive(Debug)

///|
pub fn SerializeOptions::default() -> SerializeOptions {
  { pretty: false, prolog: true, }
}

///|
fn escape_text(s : String) -> String {
  if !s.contains("&") && !s.contains("<") && !s.contains(">") {
    return s
  }
  let sb = StringBuilder()
  for c in s {
    match c {
      '&' => sb.write_string("&amp;")
      '<' => sb.write_string("&lt;")
      '>' => sb.write_string("&gt;")
      _ => sb.write_char(c)
    }
  }
  sb.to_string()
}

///|
fn escape_attr(s : String) -> String {
  if !s.contains("&") && !s.contains("<") && !s.contains("\"") {
    return s
  }
  let sb = StringBuilder()
  for c in s {
    match c {
      '&' => sb.write_string("&amp;")
      '<' => sb.write_string("&lt;")
      '"' => sb.write_string("&quot;")
      _ => sb.write_char(c)
    }
  }
  sb.to_string()
}

///|
/// Serialize a document back to SVG text.
pub fn Document::to_string(
  self : Document,
  options? : SerializeOptions = SerializeOptions::default(),
) -> String {
  let sb = StringBuilder()
  let mut first = true
  for node in self.children {
    if !options.prolog && node is (Doctype(_) | ProcInst(_, _)) {
      continue
    }
    if options.pretty && !first {
      sb.write_char('\n')
    }
    write_node(sb, node, 0, options)
    first = false
  }
  if options.pretty {
    sb.write_char('\n')
  }
  sb.to_string()
}

///|
pub fn Element::to_string(
  self : Element,
  options? : SerializeOptions = SerializeOptions::default(),
) -> String {
  let sb = StringBuilder()
  write_node(sb, Element(self), 0, options)
  sb.to_string()
}

///|
fn indent(sb : StringBuilder, depth : Int) -> Unit {
  for _ in 0..<depth {
    sb.write_string("  ")
  }
}

///|
fn write_node(
  sb : StringBuilder,
  node : Node,
  depth : Int,
  options : SerializeOptions,
) -> Unit {
  match node {
    Text(t) => sb.write_string(escape_text(t))
    Comment(c) => {
      sb.write_string("<!--")
      sb.write_string(c)
      sb.write_string("-->")
    }
    CData(c) => {
      sb.write_string("<![CDATA[")
      sb.write_string(c)
      sb.write_string("]]>")
    }
    Doctype(d) => {
      sb.write_string("<!DOCTYPE ")
      sb.write_string(d)
      sb.write_string(">")
    }
    ProcInst(target, data) => {
      sb.write_string("<?")
      sb.write_string(target)
      if data.length() > 0 {
        sb.write_char(' ')
        sb.write_string(data)
      }
      sb.write_string("?>")
    }
    Element(e) => {
      sb.write_char('<')
      sb.write_string(e.name)
      for k, v in e.attrs {
        sb.write_char(' ')
        sb.write_string(k)
        sb.write_string("=\"")
        sb.write_string(escape_attr(v))
        sb.write_char('"')
      }
      if e.children.length() == 0 {
        sb.write_string("/>")
        return
      }
      sb.write_char('>')
      let text_only = e.children.iter().all(c => c is (Text(_) | CData(_)))
      let pretty_children = options.pretty &&
        !text_only &&
        !text_elements.contains(e.name)
      for child in e.children {
        if pretty_children {
          sb.write_char('\n')
          indent(sb, depth + 1)
        }
        write_node(sb, child, depth + 1, options)
      }
      if pretty_children {
        sb.write_char('\n')
        indent(sb, depth)
      }
      sb.write_string("</")
      sb.write_string(e.name)
      sb.write_char('>')
    }
  }
}
