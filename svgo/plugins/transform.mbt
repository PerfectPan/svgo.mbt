///|
priv struct Tf {
  name : String
  args : Array[Double]
}

///|
fn parse_transform(v : String) -> Array[Tf]? {
  let out : Array[Tf] = []
  let mut rest = v.trim().to_owned()
  while !rest.is_empty() {
    guard rest.find("(") is Some(open) &&
      rest.find(")") is Some(close) &&
      close > open else {
      return None
    }
    let name = rest[:open].trim().to_owned()
    let inner = rest[open + 1:close].to_owned()
    let args : Array[Double] = []
    for tok in inner.replace_all(old=",", new=" ").split(" ") {
      if tok.is_empty() {
        continue
      }
      match split_unit(tok.to_owned()) {
        Some((n, "")) => args.push(n)
        _ => return None
      }
    }
    guard ["matrix", "translate", "scale", "rotate", "skewX", "skewY"].contains(
      name,
    ) else {
      return None
    }
    out.push({ name, args, })
    rest = rest[close + 1:].trim().to_owned()
    if rest.has_prefix(",") {
      rest = rest[1:].trim().to_owned()
    }
  }
  Some(out)
}

///|
fn is_identity(t : Tf) -> Bool {
  match (t.name, t.args) {
    ("translate", [0.0]) | ("translate", [0.0, 0.0]) => true
    ("scale", [1.0]) | ("scale", [1.0, 1.0]) => true
    ("rotate", [0.0]) | ("rotate", [0.0, _, _]) => true
    ("skewX", [0.0]) | ("skewY", [0.0]) => true
    ("matrix", [1.0, 0.0, 0.0, 1.0, 0.0, 0.0]) => true
    _ => false
  }
}

///|
/// Round transform arguments, drop redundant ones and remove identity transforms.
pub let convert_transform : Plugin = {
  name: "convertTransform",
  description: "simplify transform lists",
  run: (doc, ctx) => {
    let mut changed = false
    let p = ctx.precision
    doc.each_element((e, _) => {
      for attr in ["transform", "gradientTransform", "patternTransform"] {
        guard e.attrs.get(attr) is Some(v) else { continue }
        guard parse_transform(v) is Some(list) else { continue }
        let sb = StringBuilder()
        let mut first = true
        for t in list {
          let args = t.args.map(a => @path.round_to(a, p))
          let t : Tf = { name: t.name, args, }
          if is_identity(t) {
            continue
          }
          // translate(x 0) -> translate(x); scale(s s) -> scale(s)
          let args = match (t.name, args) {
            ("translate", [x, 0.0]) => [x]
            ("scale", [s1, s2]) if s1 == s2 => [s1]
            ("rotate", [a, 0.0, 0.0]) => [a]
            (_, a) => a
          }
          if !first {
            sb.write_char(' ')
          }
          first = false
          sb.write_string(t.name)
          sb.write_char('(')
          for i, a in args {
            let s = @path.format_number(a, p)
            if i > 0 && !s.has_prefix("-") {
              sb.write_char(' ')
            }
            sb.write_string(s)
          }
          sb.write_char(')')
        }
        let out = sb.to_string()
        if out != v {
          if out.is_empty() {
            e.attrs.remove(attr)
          } else {
            e.attrs[attr] = out
          }
          changed = true
        }
      }
    })
    changed
  },
}
