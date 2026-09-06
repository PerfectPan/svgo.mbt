///|
pub let remove_doctype : Plugin = {
  name: "removeDoctype",
  description: "remove the doctype declaration",
  run: (doc, _) => remove_top_level(doc, n => n is Doctype(_)),
}

///|
pub let remove_xml_proc_inst : Plugin = {
  name: "removeXMLProcInst",
  description: "remove the <?xml ...?> declaration",
  run: (doc, _) => remove_top_level(doc, n => n is ProcInst("xml", _)),
}

///|
/// Comments starting with `!` are legal notices and are kept.
pub let remove_comments : Plugin = {
  name: "removeComments",
  description: "remove comments",
  run: (doc, _) => {
    let pred = fn(n : @xml.Node) -> Bool {
      n is Comment(c) && !c.has_prefix("!")
    }
    let mut changed = remove_top_level(doc, pred)
    doc.each_element((e, _) => if remove_children(e, pred) { changed = true })
    changed
  },
}

///|
pub let remove_metadata : Plugin = {
  name: "removeMetadata",
  description: "remove <metadata>",
  run: (doc, _) => remove_elements(doc, (e, _) => e.name == "metadata"),
}

///|
/// Descriptions produced by editors ("Created with Sketch.") carry no meaning.
pub let remove_desc : Plugin = {
  name: "removeDesc",
  description: "remove editor generated <desc>",
  run: (doc, _) => {
    remove_elements(doc, (e, _) => {
      e.name == "desc" &&
      (
        e.children.length() == 0 ||
        (
          e.children is [Text(t)] &&
          (t.has_prefix("Created with") || t.has_prefix("Created using"))
        )
      )
    })
  },
}

///|
/// Namespace prefixes used by editors for their private data.
pub let editor_namespaces : Array[String] = [
  "http://www.inkscape.org/namespaces/inkscape", "http://sodipodi.sourceforge.net/DTD/sodipodi-0.dtd",
  "http://ns.adobe.com/AdobeIllustrator/10.0/", "http://ns.adobe.com/Graphs/1.0/",
  "http://ns.adobe.com/AdobeSVGViewerExtensions/3.0/", "http://ns.adobe.com/Variables/1.0/",
  "http://ns.adobe.com/SaveForWeb/1.0/", "http://ns.adobe.com/Extensibility/1.0/",
  "http://ns.adobe.com/Flows/1.0/", "http://ns.adobe.com/ImageReplacement/1.0/",
  "http://ns.adobe.com/GenericCustomNamespace/1.0/", "http://ns.adobe.com/XPath/1.0/",
  "http://schemas.microsoft.com/visio/2003/SVGExtensions/", "http://taptrix.com/vectorillustrator/svg_extensions",
  "http://www.figma.com/figma/ns", "http://purl.org/dc/elements/1.1/", "http://creativecommons.org/ns#",
  "http://www.w3.org/1999/02/22-rdf-syntax-ns#", "http://www.serif.com/", "http://www.vector.evaxdesign.sk",
  "http://www.bohemiancoding.com/sketch/ns", "http://www.w3.org/2000/02/svg/testsuite/description/",
]

///|
pub let remove_editors_ns_data : Plugin = {
  name: "removeEditorsNSData",
  description: "remove editor namespaces, elements and attributes",
  run: (doc, _) => {
    let prefixes : Array[String] = []
    let mut changed = false
    // find prefixes bound to editor namespaces and drop the declarations
    doc.each_element((e, _) => {
      if remove_attrs(e, (k, v) => {
          if k.has_prefix("xmlns:") && editor_namespaces.contains(v) {
            prefixes.push(k[6:].to_owned())
            true
          } else {
            false
          }
        }) {
        changed = true
      }
    })
    if prefixes.length() == 0 {
      return changed
    }
    let is_editor = fn(name : String) -> Bool {
      match name.find(":") {
        Some(i) => prefixes.contains(name[:i].to_owned())
        None => false
      }
    }
    if remove_elements(doc, (e, _) => is_editor(e.name)) {
      changed = true
    }
    doc.each_element((e, _) => {
      if remove_attrs(e, (k, _) => is_editor(k)) {
        changed = true
      }
    })
    changed
  },
}

///|
/// Collapse whitespace inside attribute values.
pub let cleanup_attrs : Plugin = {
  name: "cleanupAttrs",
  description: "clean up whitespace in attribute values",
  run: (doc, _) => {
    let mut changed = false
    doc.each_element((e, _) => {
      for kv in e.attrs.to_array() {
        let (k, v) = kv
        let cleaned = collapse_space(v)
        if cleaned != v {
          e.attrs[k] = cleaned
          changed = true
        }
      }
    })
    changed
  },
}

///|
fn collapse_space(v : String) -> String {
  if !v.contains("\n") &&
    !v.contains("\t") &&
    !v.contains("  ") &&
    !v.has_prefix(" ") &&
    !v.has_suffix(" ") {
    return v
  }
  let sb = StringBuilder()
  let mut pending_space = false
  let mut started = false
  for c in v {
    if c == ' ' || c == '\n' || c == '\t' || c == '\r' {
      pending_space = true
    } else {
      if pending_space && started {
        sb.write_char(' ')
      }
      pending_space = false
      started = true
      sb.write_char(c)
    }
  }
  sb.to_string()
}

///|
pub let remove_empty_attrs : Plugin = {
  name: "removeEmptyAttrs",
  description: "remove attributes with empty values",
  run: (doc, _) => {
    let mut changed = false
    doc.each_element((e, _) => {
      // an empty id may still be a target and an empty d is handled by
      // removeHiddenElems; everything else empty is noise
      if remove_attrs(e, (k, v) => v.is_empty() && k != "id" && k != "d") {
        changed = true
      }
    })
    changed
  },
}

///|
pub let remove_empty_text : Plugin = {
  name: "removeEmptyText",
  description: "remove empty <text>, <tspan> and <tref>",
  run: (doc, _) => {
    remove_elements(doc, (e, _) => {
      ((e.name == "text" || e.name == "tspan") && e.children.length() == 0) ||
      (
        e.name == "tref" &&
        !e.attrs.contains("href") &&
        !e.attrs.contains("xlink:href")
      )
    })
  },
}

///|
pub let remove_empty_containers : Plugin = {
  name: "removeEmptyContainers",
  description: "remove empty container elements",
  run: (doc, _) => {
    remove_elements(doc, (e, parent) => {
      guard e.children.length() == 0 &&
        container_elements.contains(e.name) &&
        e.name != "svg" else {
        false
      }
      // an empty pattern with a href still inherits content; an empty mask hides its target
      if e.name == "pattern" &&
        (e.attrs.contains("href") || e.attrs.contains("xlink:href")) {
        return false
      }
      if e.name == "mask" && e.attrs.contains("id") {
        return false
      }
      // a <g> inside <switch> is a meaningful branch
      if parent is Some(p) && p.name == "switch" {
        return false
      }
      // filters referencing the element by id would break
      e.attrs.get("filter") is None
    })
  },
}

///|
/// Elements that are never rendered.
pub let remove_hidden_elems : Plugin = {
  name: "removeHiddenElems",
  description: "remove elements that are not rendered",
  run: (doc, _) => {
    let ids = referenced_ids(doc)
    remove_elements(doc, (e, _) => {
      // referenced elements may still be used via <use> or as clip paths
      if e.attrs.get("id") is Some(id) && ids.contains(id) {
        return false
      }
      if e.attrs.get("display") == Some("none") && e.name != "marker" {
        return true
      }
      if e.attrs.get("opacity") == Some("0") && e.name != "svg" {
        return true
      }
      match e.name {
        "circle" => e.attrs.get("r") == Some("0")
        "ellipse" =>
          e.attrs.get("rx") == Some("0") || e.attrs.get("ry") == Some("0")
        "rect" | "image" | "pattern" =>
          e.name != "pattern" &&
          (
            e.attrs.get("width") == Some("0") ||
            e.attrs.get("height") == Some("0")
          )
        "path" =>
          match e.attrs.get("d") {
            None => true
            Some(d) => d.trim().is_empty()
          }
        "polyline" | "polygon" =>
          match e.attrs.get("points") {
            None => true
            Some(p) => p.trim().is_empty()
          }
        _ => false
      }
    })
  },
}

///|
/// Remove ids nothing refers to.
pub let cleanup_ids : Plugin = {
  name: "cleanupIds",
  description: "remove unused ids",
  run: (doc, _) => {
    // scripts and styles may reference ids dynamically; leave them alone
    let mut has_script = false
    doc.each_element((e, _) => if e.name == "script" { has_script = true })
    if has_script {
      return false
    }
    let ids = referenced_ids(doc)
    let mut changed = false
    doc.each_element((e, _) => {
      if e.attrs.get("id") is Some(id) && !ids.contains(id) {
        e.attrs.remove("id")
        changed = true
      }
    })
    changed
  },
}

///|
pub let remove_useless_defs : Plugin = {
  name: "removeUselessDefs",
  description: "remove <defs> children without an id",
  run: (doc, _) => {
    let mut changed = false
    doc.each_element((e, _) => {
      if e.name == "defs" {
        // unwrap ids from nested groups first
        let keep : Array[@xml.Node] = []
        fn collect(nodes : Array[@xml.Node]) {
          for n in nodes {
            match n {
              Element(x) =>
                if x.attrs.contains("id") || x.name == "style" {
                  keep.push(n)
                } else if x.name == "g" || x.name == "defs" {
                  collect(x.children)
                }
              _ => ()
            }
          }
        }
        collect(e.children)
        if keep.length() != e.children.length() {
          e.children.clear()
          e.children.append(keep[:])
          changed = true
        }
      }
    })
    changed
  },
}

///|
pub let remove_unused_ns : Plugin = {
  name: "removeUnusedNS",
  description: "remove unused namespace declarations",
  run: (doc, _) => {
    guard doc.root() is Some(root) else { return false }
    let used : Set[String] = Set([])
    doc.each_element((e, _) => {
      if e.name.find(":") is Some(i) {
        used.add(e.name[:i].to_owned())
      }
      for k, _ in e.attrs {
        if !k.has_prefix("xmlns:") && k.find(":") is Some(i) {
          used.add(k[:i].to_owned())
        }
      }
    })
    remove_attrs(root, (k, _) => {
      k.has_prefix("xmlns:") && !used.contains(k[6:].to_owned())
    })
  },
}

///|
/// Alphabetical attribute order compresses better and diffs cleanly.
pub let sort_attrs : Plugin = {
  name: "sortAttrs",
  description: "sort attributes",
  run: (doc, _) => {
    let mut changed = false
    doc.each_element((e, _) => {
      guard e.attrs.length() > 1 else { return }
      let items = e.attrs.to_array()
      // (rank, key, value); rank computed once per attribute, not per comparison
      let keyed = items.map(kv => (attr_rank(kv.0), kv.0, kv.1))
      keyed.sort_by((a, b) => {
        if a.0 != b.0 {
          a.0 - b.0
        } else {
          // String::compare orders by length first; we want dictionary order
          a.1.lexical_compare(b.1)
        }
      })
      let mut same = true
      for i, it in items {
        if it.0 != keyed[i].1 {
          same = false
          break
        }
      }
      if !same {
        e.attrs.clear()
        for it in keyed {
          e.attrs[it.1] = it.2
        }
        changed = true
      }
    })
    changed
  },
}

///|
/// Sort order of well known attributes; `xmlns*` first, then this list (an
/// attribute like `stroke-width` sorts with `stroke`), then the rest.
let attr_order : Map[String, Int] = {
  "id": 1,
  "width": 2,
  "height": 3,
  "x": 4,
  "x1": 5,
  "x2": 6,
  "y": 7,
  "y1": 8,
  "y2": 9,
  "cx": 10,
  "cy": 11,
  "r": 12,
  "fill": 13,
  "stroke": 14,
  "marker": 15,
  "d": 16,
  "points": 17,
}

///|
fn attr_rank(k : String) -> Int {
  if k.has_prefix("xmlns") {
    return 0
  }
  let base = match k.find("-") {
    Some(i) => k[:i].to_owned()
    None => k
  }
  attr_order.get(base).unwrap_or(100)
}
