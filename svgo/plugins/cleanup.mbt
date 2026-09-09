///|
/// `<!DOCTYPE ...>` carries nothing a renderer needs.
pub let remove_doctype : Plugin = {
  name: "removeDoctype",
  description: "remove the doctype declaration",
  run: (doc, _) => remove_top_level(doc, n => n is Doctype(_)),
}

///|
/// `<?xml ...?>` is optional for UTF-8 documents.
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
  run: (doc, ctx) => {
    let patterns = if ctx.has_param("preservePatterns") {
      ctx.param_strings("preservePatterns")
    } else {
      ["^!"]
    }
    let pred = fn(n : @xml.Node) -> Bool {
      n is Comment(c) &&
      !patterns
      .iter()
      .any(pattern => {
        if pattern.has_prefix("^") {
          c.has_prefix(pattern[1:])
        } else {
          c.contains(pattern)
        }
      })
    }
    let mut changed = remove_top_level(doc, pred)
    doc.each_element((e, _) => if remove_children(e, pred) { changed = true })
    changed
  },
}

///|
/// `<metadata>` holds RDF/Dublin Core data from editors.
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
  "http://www.inkscape.org/namespaces/inkscape", "http://inkscape.sourceforge.net/DTD/sodipodi-0.dtd",
  "http://sodipodi.sourceforge.net/DTD/sodipodi-0.dtd", "http://ns.adobe.com/AdobeIllustrator/10.0/",
  "http://ns.adobe.com/Graphs/1.0/", "http://ns.adobe.com/AdobeSVGViewerExtensions/3.0/",
  "http://ns.adobe.com/Variables/1.0/", "http://ns.adobe.com/SaveForWeb/1.0/", "http://ns.adobe.com/Extensibility/1.0/",
  "http://ns.adobe.com/Flows/1.0/", "http://ns.adobe.com/ImageReplacement/1.0/",
  "http://ns.adobe.com/GenericCustomNamespace/1.0/", "http://ns.adobe.com/XPath/1.0/",
  "http://schemas.microsoft.com/visio/2003/SVGExtensions/", "http://taptrix.com/vectorillustrator/svg_extensions",
  "http://www.figma.com/figma/ns", "http://purl.org/dc/elements/1.1/", "http://creativecommons.org/ns#",
  "http://www.w3.org/1999/02/22-rdf-syntax-ns#", "http://www.serif.com/", "http://www.vector.evaxdesign.sk",
  "http://www.bohemiancoding.com/sketch/ns", "http://www.w3.org/2000/02/svg/testsuite/description/",
  "http://krita.org/namespaces/svg/krita", "https://boxy-svg.com",
]

///|
/// Drop the namespace declarations, elements and attributes of the editors
/// listed in `editor_namespaces`.
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
  guard needs_collapse(v) else { return v }
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
/// Attributes with an empty value, except `id`, `d` and the conditional
/// processing attributes whose empty value hides the element.
pub let remove_empty_attrs : Plugin = {
  name: "removeEmptyAttrs",
  description: "remove attributes with empty values",
  run: (doc, _) => {
    let mut changed = false
    doc.each_element((e, _) => {
      // an empty id may still be a target and an empty d is handled by
      // removeHiddenElems; empty conditional processing attributes hide
      // the element so they must be kept
      if remove_attrs(e, (k, v) => {
          v.is_empty() &&
          k != "id" &&
          k != "d" &&
          !conditional_processing_attrs.contains(k)
        }) {
        changed = true
      }
    })
    changed
  },
}

///|
/// Conditional processing attributes: an empty value makes the element
/// fail the test and not be rendered, so the attribute must be kept.
let conditional_processing_attrs : Set[String] = Set([
  "requiredFeatures", "requiredExtensions", "systemLanguage",
])

///|
/// `<text>`/`<tspan>` without content and `<tref>` without a target.
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
/// Container elements (`<g>`, `<defs>`, ...) with no children, unless they
/// are referenced or otherwise meaningful (masks, `<switch>` branches, filters).
pub let remove_empty_containers : Plugin = {
  name: "removeEmptyContainers",
  description: "remove empty container elements",
  run: (doc, _) => {
    let removed_ids : Set[String] = Set([])
    let changed = remove_elements(doc, (e, parent) => {
      guard e.children.length() == 0 &&
        container_elements.contains(e.name) &&
        e.name != "svg" else {
        false
      }
      // an empty pattern with attributes may carry reusable configuration
      if e.name == "pattern" && e.attrs.length() > 0 {
        return false
      }
      // an empty mask with an id hides the masked element
      if e.name == "mask" && e.attrs.contains("id") {
        return false
      }
      // a <g> inside <switch> is a meaningful branch
      if parent is Some(p) && p.name == "switch" {
        return false
      }
      // a <g> with a filter (attribute or inline style) still renders
      if e.name == "g" && has_filter(e) {
        return false
      }
      if e.attrs.contains("id") {
        removed_ids.add(e.attrs.get("id").unwrap())
      }
      true
    })
    // remove <use> elements that referenced a now-removed empty container
    if removed_ids.length() > 0 &&
      remove_elements(doc, (e, _) => {
        if e.name != "use" {
          return false
        }
        for k, v in e.attrs {
          if (k == "href" || k.has_suffix(":href")) && v.has_prefix("#") {
            if removed_ids.contains(v[1:].to_owned()) {
              return true
            }
          }
        }
        false
      }) {
      true
    } else {
      changed
    }
  },
}

///|
/// Elements that are never rendered.
pub let remove_hidden_elems : Plugin = {
  name: "removeHiddenElems",
  description: "remove elements that are not rendered",
  run: (doc, _) => {
    let ids = referenced_ids(doc)
    // a stylesheet can override presentation attributes, so with <style>
    // present an element a rule might match is not provably hidden
    let css = style_text(doc)
    let maybe_styled = fn(e : @xml.Element) -> Bool {
      !css.is_empty() &&
      (
        e.attrs.contains("class") ||
        e.attrs.contains("id") ||
        css.contains(e.name)
      )
    }
    let non_rendering = non_rendering_elements()
    // svgo: with a stylesheet or script in the document, an unreferenced
    // definition is not provably unused
    let deoptimized = !css.is_empty() || has_scripts(doc)
    let removed_ids : Set[String] = Set([])
    let mut changed = false

    fn in_non_rendering(ancestors : Array[@xml.Element]) -> Bool {
      ancestors.iter().any(a => non_rendering.contains(a.name))
    }

    fn walk(e : @xml.Element, ancestors : Array[@xml.Element]) {
      // post-order: process children first so descendant visibility is known
      for c in e.children.copy() {
        if c is Element(child) {
          ancestors.push(e)
          walk(child, ancestors)
          ignore(ancestors.pop())
        }
      }

      let inside_non_rendering = in_non_rendering(ancestors)
      let referenced = e.attrs.get("id") is Some(id) && ids.contains(id)

      // shape-specific zero-size rules. Path data (`d`, `points`) cannot be
      // overridden by <use>, so an empty/single-point path is useless even
      // when referenced. Geometric attributes (r, width, height, ...) CAN be
      // overridden by <use>, so zero-size shapes are kept when referenced.
      let path_like = e.name == "path" ||
        e.name == "polyline" ||
        e.name == "polygon"
      let zero_size = match e.name {
        "circle" => e.children.is_empty() && e.attrs.get("r") == Some("0")
        "ellipse" =>
          e.children.is_empty() &&
          (e.attrs.get("rx") == Some("0") || e.attrs.get("ry") == Some("0"))
        "rect" | "image" | "pattern" =>
          (e.name == "image" || e.children.is_empty()) &&
          (
            e.attrs.get("width") == Some("0") ||
            e.attrs.get("height") == Some("0")
          )
        "path" => is_empty_or_single_point_path(e)
        "polyline" | "polygon" =>
          match e.attrs.get("points") {
            None => true
            Some(p) => p.trim().is_empty()
          }
        _ => false
      }
      if zero_size && (path_like || !referenced) {
        remove_from_parent(e, ancestors, removed_ids)
        changed = true
        return
      }

      // an empty <defs> left after pruning its children is useless
      if e.name == "defs" && e.children.is_empty() {
        remove_from_parent(e, ancestors, removed_ids)
        changed = true
        return
      }

      // referenced elements may still be used via <use> or as clip paths
      if referenced {
        return
      }

      // opacity=0 (attribute or inline style), but not inside non-rendering
      // containers where it affects the resource's alpha
      let opacity_zero = e.attrs.get("opacity") == Some("0") ||
        (match e.attrs.get("style") {
          Some(s) => style_prop(s, "opacity") == Some("0")
          None => false
        })
      if opacity_zero &&
        e.name != "svg" &&
        !maybe_styled(e) &&
        !inside_non_rendering {
        remove_from_parent(e, ancestors, removed_ids)
        changed = true
        return
      }

      if e.attrs.get("display") == Some("none") &&
        e.name != "marker" &&
        !maybe_styled(e) {
        remove_from_parent(e, ancestors, removed_ids)
        changed = true
        return
      }

      // visibility=hidden: keep when a descendant resets it to visible
      if e.attrs.get("visibility") == Some("hidden") && !maybe_styled(e) {
        if !has_visible_descendant(e) {
          remove_from_parent(e, ancestors, removed_ids)
          changed = true
          return
        }
      }

      // a paint server, clipPath, mask, marker, symbol or filter that nothing
      // references applies nowhere. A stylesheet or script could still reach
      // it, so like svgo leave these alone when either is present.
      if non_rendering.contains(e.name) &&
        !deoptimized &&
        !subtree_referenced(e, ids) {
        remove_from_parent(e, ancestors, removed_ids)
        changed = true
        return
      }
    }

    if doc.root() is Some(root) {
      walk(root, [])
    }
    // drop <use> elements that pointed at a removed definition
    if removed_ids.length() > 0 {
      if remove_elements(doc, (e, _) => {
          if e.name != "use" {
            return false
          }
          for k, v in e.attrs {
            if (k == "href" || k.has_suffix(":href")) && v.has_prefix("#") {
              if removed_ids.contains(v[1:].to_owned()) {
                return true
              }
            }
          }
          false
        }) {
        changed = true
      }
    }
    changed
  },
}

///|
/// Remove `e` from its parent's children, recording its id so referencing
/// `<use>` elements can be cleaned up.
fn remove_from_parent(
  e : @xml.Element,
  ancestors : Array[@xml.Element],
  removed_ids : Set[String],
) -> Unit {
  if e.attrs.get("id") is Some(id) {
    removed_ids.add(id)
  }
  if ancestors.last() is Some(parent) {
    parent.children.retain(n => !(n is Element(c) && physical_equal(c, e)))
  }
}

///|
/// True when a descendant of `e` has an id that something references.
fn subtree_referenced(e : @xml.Element, ids : Set[String]) -> Bool {
  for c in e.children {
    if c is Element(child) {
      if child.attrs.get("id") is Some(id) && ids.contains(id) {
        return true
      }
      if subtree_referenced(child, ids) {
        return true
      }
    }
  }
  false
}

///|
/// True when the document has a `<script>` element or an event handler
/// attribute, either of which can change anything at runtime.
fn has_scripts(doc : @xml.Document) -> Bool {
  let mut found = false
  doc.each_element((e, _) => {
    if e.name == "script" || e.attrs.iter().any(kv => kv.0.has_prefix("on")) {
      found = true
    }
  })
  found
}

///|
/// True when a descendant of `e` carries `visibility="visible"`.
fn has_visible_descendant(e : @xml.Element) -> Bool {
  for c in e.children {
    if c is Element(child) {
      if child.attrs.get("visibility") == Some("visible") {
        return true
      }
      if has_visible_descendant(child) {
        return true
      }
    }
  }
  false
}

///|
/// A path is removable when it has no drawing commands. An empty `d` is
/// always removable (markers need vertices to render). A single moveto is
/// removable only when there are no markers (a marker on the sole vertex is
/// still visible).
fn is_empty_or_single_point_path(e : @xml.Element) -> Bool {
  match e.attrs.get("d") {
    None => true
    Some(d) => {
      let t = d.trim()
      if t.is_empty() {
        return true
      }
      // a renderer draws the data up to the first error, so judge that part;
      // stop at the first drawing command so long paths cost almost nothing
      let segs = @path.parse_prefix(t.to_owned(), until_drawing=true)
      let single_point = !segs.iter().any(s => @path.is_drawing_command(s.cmd))
      if single_point && has_markers(e) {
        return false
      }
      single_point
    }
  }
}

///|
fn has_markers(e : @xml.Element) -> Bool {
  e.attrs.contains("marker") ||
  e.attrs.contains("marker-start") ||
  e.attrs.contains("marker-mid") ||
  e.attrs.contains("marker-end")
}

///|
/// Children of `<defs>` and non-rendering elements without an id can never
/// be referenced, so they (and the now-empty container) are removed.
pub let remove_useless_defs : Plugin = {
  name: "removeUselessDefs",
  description: "remove <defs> children without an id",
  run: (doc, _) => {
    let non_rendering = non_rendering_elements()
    let mut changed = false
    // Prune children: keep only those with an id or named <style>,
    // unwrapping their useful descendants from intermediate groups.
    doc.each_element((e, _) => {
      let is_defs = e.name == "defs"
      let is_non_rendering_no_id = non_rendering.contains(e.name) &&
        !e.attrs.contains("id")
      if is_defs || is_non_rendering_no_id {
        let keep : Array[@xml.Node] = []
        fn collect(nodes : Array[@xml.Node]) {
          for n in nodes {
            match n {
              Element(x) =>
                if x.attrs.contains("id") || x.name == "style" {
                  keep.push(n)
                } else {
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
    // Remove defs / non-rendering containers left empty by the pruning.
    if remove_elements(doc, (e, _) => {
        let is_defs = e.name == "defs"
        let is_non_rendering_no_id = non_rendering.contains(e.name) &&
          !e.attrs.contains("id")
        (is_defs || is_non_rendering_no_id) && e.children.length() == 0
      }) {
      changed = true
    }
    changed
  },
}

///|
/// Elements that are not rendered directly (paint servers, masks, ...).
fn non_rendering_elements() -> Set[String] {
  match svg_tables().content_groups.get("nonRendering") {
    Some(names) => Set::from_array(names)
    None => Set([])
  }
}

///|
/// `xmlns:prefix` declarations whose prefix appears on no element or attribute.
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
  run: (doc, ctx) => {
    let order = if ctx.has_param("order") {
      let ranks : Map[String, Int] = Map([])
      for name in ctx.param_strings("order") {
        if !ranks.contains(name) {
          ranks[name] = ranks.length() + 1
        }
      }
      ranks
    } else {
      attr_order
    }
    let front = ctx.param_string("xmlnsOrder", "front") == "front"
    let mut changed = false
    doc.each_element((e, _) => {
      guard e.attrs.length() > 1 else { return }
      let items = e.attrs.to_array()
      // (rank, key, value); rank computed once per attribute, not per comparison
      let keyed = items.map(kv => (attr_rank(kv.0, order, front), kv.0, kv.1))
      stable_sort_by(keyed, (a, b) => {
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
fn attr_rank(k : String, order : Map[String, Int], front : Bool) -> Int {
  let namespace_rank = if front && k == "xmlns" {
    0
  } else if front && k.has_prefix("xmlns:") {
    1
  } else if k.contains(":") {
    2
  } else {
    3
  }
  let base = match k.find("-") {
    Some(i) => k[:i].to_owned()
    None => k
  }
  namespace_rank * (order.length() + 2) +
  order.get(base).unwrap_or(order.length() + 1)
}

///|
/// One scan: true when the value has leading/trailing whitespace, runs of
/// spaces, or any whitespace other than a plain space.
fn needs_collapse(v : String) -> Bool {
  let cu = v.code_units()
  let n = cu.length()
  if n == 0 {
    return false
  }
  if cu[0] == 32 || cu[n - 1] == 32 {
    return true
  }
  let mut prev_space = false
  for c in cu {
    if c == 9 || c == 10 || c == 13 {
      return true
    }
    let space = c == 32
    if space && prev_space {
      return true
    }
    prev_space = space
  }
  false
}

///|
/// The concatenated text of every `<style>` element.
fn style_text(doc : @xml.Document) -> String {
  let sb = StringBuilder()
  doc.each_element((e, _) => {
    if e.name == "style" {
      for c in e.children {
        match c {
          Text(t) | CData(t) => sb.write_string(t)
          _ => ()
        }
      }
    }
  })
  sb.to_string()
}

///|
/// Remove presentation attributes on `<g>` that are neither inheritable nor
/// in the non-inheritable-group set (clip-path, display, filter, mask,
/// opacity, text-decoration, transform, unicode-bidi). Such attributes on a
/// group have no effect on the group's children.
pub let remove_non_inheritable_group_attrs : Plugin = {
  name: "removeNonInheritableGroupAttrs",
  description: "removes non-inheritable group's presentational attributes",
  run: (doc, _) => {
    let tables = svg_tables()
    let presentation = match tables.attr_groups.get("presentation") {
      Some(names) => Set::from_array(names)
      None => Set([])
    }
    let mut changed = false
    doc.each_element((e, _) => {
      if e.name != "g" {
        return
      }
      if remove_attrs(e, (k, _) => {
          presentation.contains(k) &&
          !tables.inheritable.contains(k) &&
          !tables.presentation_non_inheritable.contains(k)
        }) {
        changed = true
      }
    })
    changed
  },
}

///|
/// Parse an `enable-background="new 0 0 W H"` value into (W, H) when it
/// matches the standard form; otherwise None.
fn parse_enable_background_new(value : String) -> (String, String)? {
  let parts = value.trim().split(" ").filter(s => !s.is_empty()).to_array()
  if parts.length() != 5 {
    return None
  }
  if parts[0].to_owned() != "new" ||
    parts[1].to_owned() != "0" ||
    parts[2].to_owned() != "0" {
    return None
  }
  Some((parts[3].to_owned(), parts[4].to_owned()))
}

///|
/// Remove or clean up the `enable-background` attribute. When the document
/// has no `<filter>`, the attribute is always redundant and is dropped.
/// Otherwise, on `<svg>`, `<mask>` and `<pattern>` with explicit `width` and
/// `height`, a value of `new 0 0 W H` matching those dimensions is redundant:
/// for `<svg>` it is removed, for `<mask>`/`<pattern>` it is shortened to
/// `new`. Inline `style` declarations are handled the same way.
pub let cleanup_enable_background : Plugin = {
  name: "cleanupEnableBackground",
  description: "remove or cleanup enable-background attribute when possible",
  run: (doc, _) => {
    let mut has_filter = false
    let mut has_enable_background = false
    doc.each_element((e, _) => {
      if e.name == "filter" {
        has_filter = true
      }
      if e.attrs.contains("enable-background") {
        has_enable_background = true
      } else if e.attrs.get("style") is Some(s) &&
        s.contains("enable-background") {
        has_enable_background = true
      }
    })
    if !has_filter && !has_enable_background {
      return false
    }
    let mut changed = false
    doc.each_element((e, _) => {
      // handle inline style's enable-background declaration
      if e.attrs.get("style") is Some(style) {
        let new_style = remove_enable_background_from_style(style)
        if new_style != style {
          if new_style.is_empty() {
            e.attrs.remove("style")
          } else {
            e.attrs["style"] = new_style
          }
          changed = true
        }
      }

      if !has_filter {
        if e.attrs.contains("enable-background") {
          e.attrs.remove("enable-background")
          changed = true
        }
        return
      }

      let has_dimensions = e.attrs.contains("width") &&
        e.attrs.contains("height")
      if (e.name == "svg" || e.name == "mask" || e.name == "pattern") &&
        has_dimensions {
        match e.attrs.get("enable-background") {
          Some(value) => {
            let width = e.attrs.get("width").unwrap()
            let height = e.attrs.get("height").unwrap()
            match parse_enable_background_new(value) {
              Some((w, h)) if w == width && h == height => {
                if e.name == "svg" {
                  e.attrs.remove("enable-background")
                } else {
                  e.attrs["enable-background"] = "new"
                }
                changed = true
              }
              _ => ()
            }
          }
          None => ()
        }
      }
    })
    changed
  },
}

///|
/// Remove all `enable-background` declarations from an inline style string.
/// Keeps the remaining declarations in order.
fn remove_enable_background_from_style(style : String) -> String {
  let kept : Array[String] = []
  for decl in style.split(";") {
    let d = decl.trim().to_owned()
    if d.is_empty() {
      continue
    }
    if d.split(":").to_array()[0].trim() == "enable-background" {
      continue
    }
    kept.push(d)
  }
  kept.join(";")
}

///|
/// Extract attribute names referenced by CSS attribute selectors
/// (`[attr]`, `[attr=value]`, ...) from a stylesheet. Used to avoid removing
/// deprecated attributes that a stylesheet still selects on.
fn css_attribute_names(css : String) -> Set[String] {
  let names : Set[String] = Set([])
  let mut i = 0
  let n = css.length()
  while i < n {
    if css.get_char(i).unwrap() == '[' {
      i += 1
      let start = i
      while i < n {
        let c = css.get_char(i).unwrap()
        if c.is_ascii_alphabetic() ||
          c.is_ascii_digit() ||
          c == '-' ||
          c == '_' ||
          c == ':' ||
          c == '*' {
          i += 1
        } else {
          break
        }
      }
      if i > start {
        names.add(css[start:i].to_owned())
      }
    } else {
      i += 1
    }
  }
  names
}

///|
/// Remove deprecated attributes. Safe deprecated attributes are always
/// removed; unsafe ones only when the `removeUnsafe` parameter is set.
/// Attributes referenced by CSS attribute selectors are kept. The special
/// `xml:lang` attribute is removed when a `lang` attribute is also present.
pub let remove_deprecated_attrs : Plugin = {
  name: "removeDeprecatedAttrs",
  description: "removes deprecated attributes",
  run: (doc, ctx) => {
    let tables = svg_tables()
    let remove_unsafe = ctx.param_bool("removeUnsafe", false)
    let css = style_text(doc)
    let css_attrs = if css.is_empty() {
      Set([])
    } else {
      css_attribute_names(css)
    }
    let mut changed = false

    doc.each_element((e, _) => {
      let elem_tables = tables.element(e.name)
      guard elem_tables is Some(et) else { return }

      // Special case: xml:lang is safe to remove when lang is present.
      if e.attrs.contains("xml:lang") &&
        e.attrs.contains("lang") &&
        !css_attrs.contains("xml:lang") {
        e.attrs.remove("xml:lang")
        changed = true
      }

      let safe = et.deprecated_safe
      let unsafe_attrs = et.deprecated_unsafe
      if safe.length() == 0 && (!remove_unsafe || unsafe_attrs.length() == 0) {
        return
      }
      for name in safe {
        if !css_attrs.contains(name) && e.attrs.contains(name) {
          e.attrs.remove(name)
          changed = true
        }
      }
      if remove_unsafe {
        for name in unsafe_attrs {
          if !css_attrs.contains(name) && e.attrs.contains(name) {
            e.attrs.remove(name)
            changed = true
          }
        }
      }
    })
    changed
  },
}
