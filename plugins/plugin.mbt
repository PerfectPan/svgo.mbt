///|
/// Shared settings passed to every plugin.
pub(all) struct Context {
  /// decimal places for numeric attribute values and path data
  precision : Int
} derive(Debug)

///|
/// A plugin transforms the document in place and reports whether it changed
/// anything, which drives multipass optimisation.
pub(all) struct Plugin {
  name : String
  description : String
  run : (@xml.Document, Context) -> Bool
}

///|
/// Remove every child node for which `pred` holds; returns true if any was removed.
fn remove_children(e : @xml.Element, pred : (@xml.Node) -> Bool) -> Bool {
  let before = e.children.length()
  e.children.retain(c => !pred(c))
  e.children.length() != before
}

///|
fn remove_top_level(doc : @xml.Document, pred : (@xml.Node) -> Bool) -> Bool {
  let before = doc.children.length()
  doc.children.retain(c => !pred(c))
  doc.children.length() != before
}

///|
/// Remove elements matching `pred` anywhere in the document.
fn remove_elements(
  doc : @xml.Document,
  pred : (@xml.Element, @xml.Element?) -> Bool,
) -> Bool {
  let mut changed = false
  doc.each_element_post((e, parent) => {
    match parent {
      Some(p) =>
        if pred(e, parent) {
          let before = p.children.length()
          p.children.retain(c => !(c is Element(x) && physical_eq(x, e)))
          if p.children.length() != before {
            changed = true
          }
        }
      None => ()
    }
  })
  changed
}

///|
/// Identity comparison for elements (same object).
pub fn physical_eq(a : @xml.Element, b : @xml.Element) -> Bool {
  // elements are heap objects; compare identity via a temporary marker
  let key = "\u{0}svgo-id"
  let had = a.attrs.contains(key)
  a.attrs[key] = "1"
  let same = b.attrs.contains(key)
  if !had {
    a.attrs.remove(key)
  }
  same
}

///|
pub fn is_number(s : String) -> Bool {
  try {
    ignore(@path.parse("M" + s + " 0"))
    true
  } catch {
    _ => false
  }
}

///|
/// Split a numeric attribute value into number and unit ("12.5px" -> (12.5, "px")).
pub fn split_unit(s : String) -> (Double, String)? {
  let t = s.trim().to_owned()
  let mut end = t.length()
  while end > 0 &&
        (
          t.get_char(end - 1).unwrap().is_ascii_alphabetic() ||
          t.get_char(end - 1) == Some('%')
        ) {
    end -= 1
  }
  let num = t[:end].to_owned()
  let unit = t[end:].to_owned()
  if num.is_empty() {
    return None
  }
  try {
    let v = @string.parse_double(num)
    Some((v, unit))
  } catch {
    _ => None
  }
}

///|
/// Elements that are containers for other content.
pub let container_elements : Array[String] = [
  "a", "defs", "foreignObject", "g", "marker", "mask", "missing-glyph", "pattern",
  "svg", "switch", "symbol", "text", "textPath", "tspan",
]

///|
/// Attributes whose value is a reference like `url(#id)` or `#id`.
pub let reference_attrs : Array[String] = [
  "href", "xlink:href", "fill", "stroke", "filter", "clip-path", "mask", "marker-start",
  "marker-mid", "marker-end", "begin", "style",
]

///|
/// Collect every id referenced anywhere in the document.
pub fn referenced_ids(doc : @xml.Document) -> Set[String] {
  let ids : Set[String] = Set([])
  doc.each_element((e, _) => {
    for k, v in e.attrs {
      if k == "href" || k == "xlink:href" {
        if v.has_prefix("#") {
          ids.add(v[1:].to_owned())
        }
      } else if v.contains("url(") || k == "begin" {
        collect_url_refs(v, ids)
      }
    }
    // <style> text may reference ids as well
    if e.name == "style" {
      for c in e.children {
        match c {
          Text(t) | CData(t) => collect_url_refs(t, ids)
          _ => ()
        }
      }
    }
  })
  ids
}

///|
fn collect_url_refs(v : String, ids : Set[String]) -> Unit {
  let mut rest = v
  while rest.find("#") is Some(i) {
    let after = rest[i + 1:]
    let mut end = 0
    while end < after.length() &&
          (
            after.get_char(end).unwrap().is_ascii_alphabetic() ||
            after.get_char(end).unwrap().is_ascii_digit() ||
            after.get_char(end) is Some('-' | '_' | ':' | '.')
          ) {
      end += 1
    }
    if end > 0 {
      ids.add(after[:end].to_owned())
    }
    rest = after.to_owned()
  }
}
