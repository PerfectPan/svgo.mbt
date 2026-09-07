///|
/// Shared state passed to every plugin: the numeric precision plus a cache
/// that lives for the whole run.
pub struct Context {
  /// decimal places for numeric attribute values and path data
  precision : Int
  /// path data the optimizer has already left unchanged in this run
  optimized_paths : Set[String]
} derive(Debug)

///|
/// A fresh context; create one per `optimize` run.
pub fn Context::new(precision? : Int = 3) -> Context {
  { precision, optimized_paths: Set([]), }
}

///|
/// A plugin transforms the document in place and reports whether it changed
/// anything, which drives multipass optimization.
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
/// Remove elements matching `pred` anywhere below the root. Children are
/// visited before their parent, so a container emptied by the predicate can
/// be removed in the same pass.
fn remove_elements(
  doc : @xml.Document,
  pred : (@xml.Element, @xml.Element?) -> Bool,
) -> Bool {
  let mut changed = false
  fn walk(e : @xml.Element) {
    let mut has_elements = false
    for c in e.children {
      if c is Element(x) {
        has_elements = true
        walk(x)
      }
    }
    if has_elements {
      let before = e.children.length()
      let parent = Some(e)
      e.children.retain(c => !(c is Element(x) && pred(x, parent)))
      if e.children.length() != before {
        changed = true
      }
    }
  }
  if doc.root() is Some(root) {
    walk(root)
  }
  changed
}

///|
/// Remove attributes for which `pred` holds; returns true if any was removed.
fn remove_attrs(e : @xml.Element, pred : (String, String) -> Bool) -> Bool {
  let before = e.attrs.length()
  e.attrs.retain((k, v) => !pred(k, v))
  e.attrs.length() != before
}

///|
/// Split a numeric attribute value into number and unit ("12.5px" -> (12.5, "px")).
pub fn split_unit(s : String) -> (Double, String)? {
  let t = s.trim()
  let mut end = t.length()
  while end > 0 &&
        (
          t.get_char(end - 1).unwrap().is_ascii_alphabetic() ||
          t.get_char(end - 1) == Some('%')
        ) {
    end -= 1
  }
  if end == 0 {
    return None
  }
  let v = @string.parse_double(t[:end].to_owned()) catch { _ => return None }
  Some((v, t[end:].to_owned()))
}

///|
/// Elements that are containers for other content.
pub let container_elements : Set[String] = Set([
  "a", "defs", "foreignObject", "g", "marker", "mask", "missing-glyph", "pattern",
  "svg", "switch", "symbol", "text", "textPath", "tspan",
])

///|
/// Attributes whose value may reference an element: `url(#id)` in paint
/// servers and effects, `#id` in links, `id.event` in animation timing.
pub let reference_attrs : Set[String] = Set([
  "fill", "stroke", "filter", "clip-path", "mask", "marker", "marker-start", "marker-mid",
  "marker-end", "cursor", "color-profile", "begin", "end", "style",
])

///|
/// Collect every id referenced anywhere in the document: `href="#id"`,
/// `url(#id)` in attributes and `<style>` text, and `begin="id.click"`.
pub fn referenced_ids(doc : @xml.Document) -> Set[String] {
  let ids : Set[String] = Set([])
  doc.each_element((e, _) => {
    for k, v in e.attrs {
      if k == "href" || k == "xlink:href" {
        if v.has_prefix("#") {
          ids.add(v[1:].to_owned())
        }
      } else if k == "begin" || k == "end" {
        collect_timing_refs(v, ids)
      } else if reference_attrs.contains(k) && v.contains_code_unit(35) {
        // 35 is '#'
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
fn is_id_char(c : Char) -> Bool {
  c.is_ascii_alphabetic() || c.is_ascii_digit() || c is ('-' | '_' | ':' | '.')
}

///|
fn collect_url_refs(v : String, ids : Set[String]) -> Unit {
  let mut i = 0
  while v[i:].find("#") is Some(rel) {
    let start = i + rel + 1
    let mut end = start
    while end < v.length() && is_id_char(v.get_char(end).unwrap()) {
      end += 1
    }
    if end > start {
      ids.add(v[start:end].to_owned())
    }
    i = end
  }
}

///|
/// SMIL timing values reference elements as `id.event` or `id.begin+2s`
/// (several values are separated by `;`).
fn collect_timing_refs(v : String, ids : Set[String]) -> Unit {
  for part in v.split(";") {
    let t = part.trim()
    guard t.find(".") is Some(dot) && dot > 0 else { continue }
    let id = t[:dot]
    let mut ok = true
    for c in id {
      if !is_id_char(c) {
        ok = false
        break
      }
    }
    // "0.5s" is a clock value, not a reference
    if ok && !id.get_char(0).unwrap().is_ascii_digit() {
      ids.add(id.to_owned())
    }
  }
}
