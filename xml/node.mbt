///|
/// A parsed XML/SVG document: a sequence of top level nodes, usually a
/// prolog (`<?xml ...?>`, doctype, comments) followed by one root element.
pub(all) struct Document {
  children : Array[Node]
} derive(Debug)

///|
pub(all) enum Node {
  Element(Element)
  Text(String)
  Comment(String)
  CData(String)
  Doctype(String)
  /// processing instruction: target and data (`<?target data?>`)
  ProcInst(String, String)
} derive(Debug)

///|
pub(all) struct Element {
  mut name : String
  /// attributes in source order; MoonBit maps preserve insertion order
  attrs : Map[String, String]
  children : Array[Node]
} derive(Debug)

///|
pub fn Element::new(
  name : String,
  attrs? : Map[String, String] = Map([]),
  children? : Array[Node] = [],
) -> Element {
  { name, attrs, children, }
}

///|
pub fn Element::get(self : Element, name : String) -> String? {
  self.attrs.get(name)
}

///|
pub fn Element::set(self : Element, name : String, value : String) -> Unit {
  self.attrs[name] = value
}

///|
pub fn Element::remove(self : Element, name : String) -> Unit {
  self.attrs.remove(name)
}

///|
pub fn Element::has(self : Element, name : String) -> Bool {
  self.attrs.contains(name)
}

///|
/// Child elements only (skipping text and comments).
pub fn Element::elements(self : Element) -> Array[Element] {
  let out = []
  for c in self.children {
    if c is Element(e) {
      out.push(e)
    }
  }
  out
}

///|
/// The root `<svg>` element, if any.
pub fn Document::root(self : Document) -> Element? {
  for c in self.children {
    if c is Element(e) {
      return Some(e)
    }
  }
  None
}

///|
/// Depth first traversal over all elements, parents before children.
pub fn Document::each_element(
  self : Document,
  f : (Element, Element?) -> Unit,
) -> Unit {
  fn walk(e : Element, parent : Element?) {
    f(e, parent)
    for c in e.children {
      if c is Element(child) {
        walk(child, Some(e))
      }
    }
  }
  for c in self.children {
    if c is Element(e) {
      walk(e, None)
    }
  }
}

///|
/// Depth first traversal, children before parents; useful when a visitor
/// removes or merges the nodes it visits.
pub fn Document::each_element_post(
  self : Document,
  f : (Element, Element?) -> Unit,
) -> Unit {
  fn walk(e : Element, parent : Element?) {
    // iterate over a snapshot so visitors may mutate `e.children`
    for c in e.children.copy() {
      if c is Element(child) {
        walk(child, Some(e))
      }
    }
    f(e, parent)
  }
  for c in self.children.copy() {
    if c is Element(e) {
      walk(e, None)
    }
  }
}
