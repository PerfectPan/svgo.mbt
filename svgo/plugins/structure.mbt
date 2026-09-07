///|
/// Presentation attributes that inherit from ancestors.
let inheritable : Array[String] = [
  "clip-rule", "color", "color-interpolation", "color-rendering", "cursor", "direction",
  "fill", "fill-opacity", "fill-rule", "font", "font-family", "font-size", "font-style",
  "font-variant", "font-weight", "letter-spacing", "marker-end", "marker-mid", "marker-start",
  "paint-order", "pointer-events", "shape-rendering", "stroke", "stroke-dasharray",
  "stroke-dashoffset", "stroke-linecap", "stroke-linejoin", "stroke-miterlimit",
  "stroke-opacity", "stroke-width", "text-anchor", "text-rendering", "visibility",
  "word-spacing", "writing-mode",
]

///|
/// Default values of presentation attributes: an attribute equal to its
/// default can be dropped when no ancestor overrides it.
let default_values : Map[String, String] = {
  "fill": "#000",
  "fill-opacity": "1",
  "stroke-opacity": "1",
  "opacity": "1",
  "stroke-width": "1",
  "stroke-linecap": "butt",
  "stroke-linejoin": "miter",
  "stroke-miterlimit": "4",
  "stroke-dasharray": "none",
  "stroke-dashoffset": "0",
  "fill-rule": "nonzero",
  "clip-rule": "nonzero",
  "stroke": "none",
  "font-style": "normal",
  "font-weight": "normal",
  "font-variant": "normal",
  "text-anchor": "start",
  "visibility": "visible",
  "display": "inline",
  "overflow": "visible",
  "clip-path": "none",
  "mask": "none",
  "filter": "none",
  "letter-spacing": "normal",
  "word-spacing": "normal",
  "writing-mode": "lr-tb",
  "color-interpolation": "sRGB",
  "color-rendering": "auto",
  "shape-rendering": "auto",
  "text-rendering": "auto",
  "image-rendering": "auto",
  "pointer-events": "visiblePainted",
  "paint-order": "normal",
}

///|
/// Attributes that are 0 by default on these elements.
let zero_defaults : Map[String, Array[String]] = {
  "rect": ["x", "y", "rx", "ry"],
  "circle": ["cx", "cy"],
  "ellipse": ["cx", "cy"],
  "image": ["x", "y"],
  "use": ["x", "y"],
  "svg": ["x", "y"],
  "pattern": ["x", "y"],
  "text": ["x", "y", "dx", "dy"],
  "tspan": ["dx", "dy"],
  "line": ["x1", "y1", "x2", "y2"],
  "foreignObject": ["x", "y"],
  "mask": [],
  "marker": ["refX", "refY"],
}

///|
fn ancestors_define(chain : Array[@xml.Element], attr : String) -> Bool {
  for a in chain {
    if a.attrs.contains(attr) {
      return true
    }
    if a.attrs.get("style") is Some(s) && s.contains(attr) {
      return true
    }
  }
  false
}

///|
/// Remove unknown elements and attributes, and attributes whose value equals
/// the element's default (when no ancestor overrides it).
pub let remove_unknowns_and_defaults : Plugin = {
  name: "removeUnknownsAndDefaults",
  description: "remove unknown elements/attributes and default attribute values",
  run: (doc, ctx) => {
    let mut changed = false
    // collect CSS text to detect attribute selectors that would make a
    // default-valued attribute meaningful
    let css = style_text(doc)
    // remove standalone="no" from the XML declaration
    for node in doc.children {
      match node {
        ProcInst("xml", v) => {
          let cleaned = remove_standalone_no(v)
          if cleaned != v {
            let idx = doc.children.search_by(n => n is ProcInst("xml", _))
            match idx {
              Some(i) => {
                doc.children[i] = ProcInst("xml", cleaned)
                changed = true
              }
              None => ()
            }
          }
        }
        _ => ()
      }
    }
    fn walk(e : @xml.Element, chain : Array[@xml.Element]) {
      // foreignObject holds arbitrary (non-SVG) content; leave it alone
      if e.name == "foreignObject" {
        return
      }
      // namespaced elements are not ours to judge
      if e.name.contains(":") {
        return
      }
      let parent = chain.last()
      // remove elements that are not allowed in their parent.
      // svgo's rule: if the parent has a non-empty allowed-children set,
      // only those children are kept; otherwise (empty or no set), only
      // unknown elements are removed.
      let parent_allowed = match parent {
        Some(p) => allowed_children.get(p.name)
        None => None
      }
      let is_unknown = !known_elements.contains(e.name)
      let not_allowed = match parent_allowed {
        Some(allowed) if allowed.length() > 0 => !allowed.contains(e.name)
        _ => is_unknown
      }
      if not_allowed {
        match parent {
          Some(p) => {
            let idx = p.children.search_by(c => {
              c is @xml.Element(x) && physical_equal(x, e)
            })
            match idx {
              Some(i) => {
                ignore(p.children.remove(i))
                changed = true
              }
              None => ()
            }
          }
          None => ()
        }
        return
      }
      let has_id = e.attrs.contains("id")
      let allowed = allowed_attrs.get(e.name)
      let defaults = elem_defaults.get(e.name)
      for kv in e.attrs.to_array() {
        let (k, v) = kv
        // always keep data-*, aria-*, xmlns and xmlns:*
        if k.has_prefix("data-") ||
          k.has_prefix("aria-") ||
          k == "xmlns" ||
          k.has_prefix("xmlns:") {
          continue
        }
        // role is removed by default (keepRoleAttr = false)
        if k == "role" {
          e.attrs.remove(k)
          changed = true
          continue
        }
        // version and baseProfile on <svg> are noise
        if e.name == "svg" && (k == "version" || k == "baseProfile") {
          e.attrs.remove(k)
          changed = true
          continue
        }
        // remove unknown attributes; namespaced attrs other than xml:*/xlink:*
        // are always kept (they belong to other namespaces)
        let is_namespaced = k.contains(":")
        let is_xml_xlink = k.has_prefix("xml:") || k.has_prefix("xlink:")
        if !is_namespaced || is_xml_xlink {
          match allowed {
            Some(set) if !set.contains(k) => {
              e.attrs.remove(k)
              changed = true
              continue
            }
            _ => ()
          }
        }
        // remove attributes set to their default value, unless the element
        // has an id (it may be referenced), an ancestor overrides it, or a
        // CSS rule selects on this attribute
        let default_val = match defaults {
          Some(d) => d.get(k)
          None => None
        }
        let is_default = match default_val {
          Some(d) => d == v
          None =>
            match default_values.get(k) {
              Some(d) => d == v
              None => false
            }
        }
        if is_default && !has_id {
          let ancestor_sets = inheritable.contains(k) &&
            ancestors_define(chain, k)
          let css_selects = css.contains("[" + k + "]")
          if !ancestor_sets && !css_selects {
            e.attrs.remove(k)
            changed = true
            continue
          }
        }
        // useless override: an inheritable attr whose value equals the
        // inherited value from the nearest ancestor that sets it
        if !has_id &&
          inheritable.contains(k) &&
          !presentation_non_inheritable.contains(k) {
          let mut inherited : String? = None
          let mut i = chain.length() - 1
          while i >= 0 {
            match chain[i].attrs.get(k) {
              Some(v) => {
                inherited = Some(v)
                break
              }
              None => i -= 1
            }
          }
          if inherited == Some(v) {
            e.attrs.remove(k)
            changed = true
            continue
          }
        }
      }
      // zero-valued geometry attributes default to 0
      match zero_defaults.get(e.name) {
        Some(list) =>
          for k in list {
            match e.attrs.get(k) {
              Some(v) =>
                match split_unit(v) {
                  Some((n, _)) if @path.round_to(n, ctx.precision) == 0.0 => {
                    // rx/ry default to each other on <rect>
                    if (k == "rx" || k == "ry") && e.name == "rect" {
                      let other = if k == "rx" { "ry" } else { "rx" }
                      match e.attrs.get(other) {
                        Some(o) if !(split_unit(o) is Some((on, _)) &&
                          @path.round_to(on, ctx.precision) == 0.0) => continue
                        _ => ()
                      }
                    }
                    e.attrs.remove(k)
                    changed = true
                  }
                  _ => ()
                }
              None => ()
            }
          }
        None => ()
      }
      chain.push(e)
      // iterate over a copy because unknown children are removed in place
      let kids = e.children[:].to_owned()
      for c in kids {
        if c is @xml.Element(child) {
          walk(child, chain)
        }
      }
      ignore(chain.pop())
    }
    if doc.root() is Some(root) {
      walk(root, [])
    }
    changed
  },
}

///|
/// Strip `standalone="no"` (single or double quotes) from an XML declaration.
fn remove_standalone_no(v : String) -> String {
  let mut s = v
  for q in ["\"", "'"] {
    let pat = "standalone=" + q + "no" + q
    s = s.replace(old=pat, new="")
  }
  // collapse any double spaces and trim trailing whitespace
  s.replace(old="  ", new=" ").trim().to_owned()
}

///|
/// Drop stroke-* attributes when there is no stroke and fill-* when fill is none.
pub let remove_useless_stroke_and_fill : Plugin = {
  name: "removeUselessStrokeAndFill",
  description: "remove useless stroke and fill attributes",
  run: (doc, _) => {
    let mut changed = false
    // elements with ids may be referenced by <use> under different inherited values
    let ids = referenced_ids(doc)
    fn walk(e : @xml.Element, chain : Array[@xml.Element]) {
      let shape = [
        "path", "rect", "circle", "ellipse", "line", "polyline", "polygon", "g",
        "text",
      ].contains(e.name)
      // ...and so may anything below a referenced element or inside <defs>:
      // a <use> can put a stroke on it that is not visible here
      let referenced = (e.attrs.get("id") is Some(id) && ids.contains(id)) ||
        chain
        .iter()
        .any(a => {
          a.name == "defs" ||
          a.name == "symbol" ||
          (a.attrs.get("id") is Some(id) && ids.contains(id))
        })
      if shape && !referenced && e.name != "g" {
        let stroke = e.attrs.get("stroke")
        let stroke_width = e.attrs.get("stroke-width")
        let stroke_opacity = e.attrs.get("stroke-opacity")
        let no_stroke = stroke == Some("none") ||
          stroke_width == Some("0") ||
          stroke_opacity == Some("0")
        let ancestor_stroke = ancestors_define(chain, "stroke")
        if no_stroke {
          for kv in e.attrs.to_array() {
            let (k, _) = kv
            if k.has_prefix("stroke") && !(k == "stroke" && ancestor_stroke) {
              e.attrs.remove(k)
              changed = true
            }
          }
          if ancestor_stroke && !e.attrs.contains("stroke") {
            e.attrs["stroke"] = "none"
          }
        } else if stroke is None && !ancestor_stroke {
          // no stroke anywhere: stroke-* attributes are noise
          for kv in e.attrs.to_array() {
            let (k, _) = kv
            if k.has_prefix("stroke-") {
              e.attrs.remove(k)
              changed = true
            }
          }
        }
        let fill = e.attrs.get("fill")
        let fill_opacity = e.attrs.get("fill-opacity")
        if fill == Some("none") || fill_opacity == Some("0") {
          for kv in e.attrs.to_array() {
            let (k, _) = kv
            if k.has_prefix("fill-") {
              e.attrs.remove(k)
              changed = true
            }
          }
        }
      }
      chain.push(e)
      for c in e.children {
        if c is Element(child) {
          walk(child, chain)
        }
      }
      ignore(chain.pop())
    }
    if doc.root() is Some(root) {
      walk(root, [])
    }
    changed
  },
}

///|
/// SVG animation elements: they add attributes to their parent at runtime,
/// so a group containing one must be preserved.
let animation_elements : Set[String] = Set([
  "animate", "animateColor", "animateMotion", "animateTransform", "set",
])

///|
/// True when `e` or any descendant is an animation element whose
/// `attributeName` equals `name`.
fn has_animated_attr(e : @xml.Element, name : String) -> Bool {
  if animation_elements.contains(e.name) &&
    e.attrs.get("attributeName") == Some(name) {
    return true
  }
  for c in e.children {
    match c {
      Element(x) if has_animated_attr(x, name) => return true
      _ => ()
    }
  }
  false
}

///|
/// True when `e` or any descendant is an animation element.
fn has_animation_child(e : @xml.Element) -> Bool {
  for c in e.children {
    match c {
      Element(x) =>
        if animation_elements.contains(x.name) || has_animation_child(x) {
          return true
        }
      _ => ()
    }
  }
  false
}

///|
/// Extract the value of a CSS property from an inline `style` attribute
/// ("a:b; filter:url(#x)"). Returns None if absent.
fn style_prop(style : String, prop : String) -> String? {
  for decl in style.split(";") {
    let kv = decl.split(":").to_array()
    if kv.length() == 2 && kv[0].trim() == prop {
      return Some(kv[1].trim().to_owned())
    }
  }
  None
}

///|
/// True when the element has a `filter` either as an attribute or inside its
/// `style` attribute.
fn has_filter(e : @xml.Element) -> Bool {
  if e.attrs.contains("filter") {
    return true
  }
  match e.attrs.get("style") {
    Some(s) => style_prop(s, "filter") is Some(_)
    None => false
  }
}

///|
/// Unwrap groups that carry nothing, and move attributes of single-child
/// groups onto the child.
pub let collapse_groups : Plugin = {
  name: "collapseGroups",
  description: "collapse useless groups",
  run: (doc, _) => {
    let mut changed = false
    doc.each_element_post((g, parent) => {
      guard g.name == "g" && parent is Some(p) && p.name != "switch" else {
        return
      }
      // svgo only collapses non-empty groups; empty containers are handled
      // by removeEmptyContainers.
      guard g.children.length() > 0 else { return }
      let elems = g.elements()
      // move attributes onto a single child element when that is unambiguous
      if elems.length() == 1 && g.children.length() == 1 && g.attrs.length() > 0 {
        let child = elems[0]
        let group_has_filter = has_filter(g)
        let group_has_clip_mask = g.attrs.contains("clip-path") ||
          g.attrs.contains("mask")
        // conditions under which moving attrs to the child is safe:
        //  - child has no id (it would be wrong to rename a referenced id)
        //  - group has no filter (filters apply to the group's subtree)
        //  - not both group and child carry a class (would merge class lists)
        //  - if the group has clip-path/mask, the child must be a <g> and
        //    neither may have a transform (clip/mask coords are tricky)
        if child.attrs.contains("id") ||
          group_has_filter ||
          (g.attrs.contains("class") && child.attrs.contains("class")) ||
          (
            group_has_clip_mask &&
            !(child.name == "g" &&
            !g.attrs.contains("transform") &&
            !child.attrs.contains("transform"))
          ) {
          // fall through to the no-attrs collapse check below
        } else {
          let mut ok = true
          for k, v in g.attrs {
            // an animated attribute on the child must not be overridden
            if has_animated_attr(child, k) {
              ok = false
              break
            }
            match child.attrs.get(k) {
              None => () // will be copied from the group
              Some(cv) =>
                if k == "transform" {
                  // transforms compose: group's transform applies first
                  ()
                } else if cv == "inherit" {
                  // inherit resolves to the group's value
                  ()
                } else if !inheritable.contains(k) && cv != v {
                  // non-inheritable attr with a different value: cannot move
                  ok = false
                  break
                } else {
                  // inheritable or equal value: child's value wins, group's
                  // copy is redundant
                  ()
                }
            }
          }
          if ok {
            for k, v in g.attrs {
              match child.attrs.get(k) {
                None => child.attrs[k] = v
                Some(cv) =>
                  if k == "transform" {
                    child.attrs[k] = v + " " + cv
                  } else if cv == "inherit" {
                    child.attrs[k] = v
                  }
                // else keep child's value
              }
            }
            g.attrs.clear()
            changed = true
          }
        }
      }
      // collapse groups that now (or originally) have no attributes, unless
      // they contain an animation element that targets one of their attrs
      if g.attrs.length() == 0 && !has_animation_child(g) {
        let idx = p.children.search_by(c => {
          c is Element(x) && physical_equal(x, g)
        })
        match idx {
          Some(i) => {
            ignore(p.children.remove(i))
            for j, c in g.children {
              p.children.insert(i + j, c)
            }
            changed = true
          }
          None => ()
        }
      }
    })
    changed
  },
}

///|
/// Convert basic shapes into paths when the path is not longer.
pub let convert_shape_to_path : Plugin = {
  name: "convertShapeToPath",
  description: "convert rect, line, polyline and polygon to path",
  run: (doc, ctx) => {
    let mut changed = false
    let p = ctx.precision
    let num = fn(v : Double) -> String { @path.format_number(v, p) }
    doc.each_element((e, _) => {
      let d : String? = match e.name {
        "rect" if !e.attrs.contains("rx") && !e.attrs.contains("ry") => {
          let x = attr_num(e, "x", 0.0)
          let y = attr_num(e, "y", 0.0)
          let w = attr_num(e, "width", -1.0)
          let h = attr_num(e, "height", -1.0)
          guard w > 0.0 &&
            h > 0.0 &&
            attr_is_plain(e, "x") &&
            attr_is_plain(e, "y") &&
            attr_is_plain(e, "width") &&
            attr_is_plain(e, "height") else {
            None
          }
          Some("M\{num(x)} \{num(y)}h\{num(w)}v\{num(h)}H\{num(x)}z")
        }
        "line" => {
          let x1 = attr_num(e, "x1", 0.0)
          let y1 = attr_num(e, "y1", 0.0)
          let x2 = attr_num(e, "x2", 0.0)
          let y2 = attr_num(e, "y2", 0.0)
          guard attr_is_plain(e, "x1") &&
            attr_is_plain(e, "y1") &&
            attr_is_plain(e, "x2") &&
            attr_is_plain(e, "y2") else {
            None
          }
          Some("M\{num(x1)} \{num(y1)} \{num(x2)} \{num(y2)}")
        }
        "polyline" | "polygon" =>
          match e.attrs.get("points") {
            Some(points) => {
              let nums : Array[Double] = []
              let mut ok = true
              for tok in points.replace_all(old=",", new=" ").split(" ") {
                if tok.is_empty() {
                  continue
                }
                match split_unit(tok.to_owned()) {
                  Some((n, "")) => nums.push(n)
                  _ => ok = false
                }
              }
              if !ok || nums.length() < 4 || nums.length() % 2 != 0 {
                None
              } else {
                let sb = StringBuilder()
                sb.write_string("M")
                for i in 0..<(nums.length() / 2) {
                  if i > 0 {
                    sb.write_char(' ')
                  }
                  sb.write_string(num(nums[i * 2]) + " " + num(nums[i * 2 + 1]))
                }
                if e.name == "polygon" {
                  sb.write_char('z')
                }
                Some(sb.to_string())
              }
            }
            None => None
          }
        _ => None
      }
      match d {
        Some(d) => {
          for
            k in ["x", "y", "x1", "y1", "x2", "y2", "width", "height", "points"] {
            e.attrs.remove(k)
          }
          e.attrs["d"] = d
          e.name = "path"
          changed = true
        }
        None => ()
      }
    })
    changed
  },
}

///|
fn attr_num(e : @xml.Element, name : String, default : Double) -> Double {
  match e.attrs.get(name) {
    Some(v) =>
      match split_unit(v) {
        Some((n, _)) => n
        None => default
      }
    None => default
  }
}

///|
/// True when the attribute is absent or a unitless number (no %, em, ...).
fn attr_is_plain(e : @xml.Element, name : String) -> Bool {
  match e.attrs.get(name) {
    None => true
    Some(v) =>
      match split_unit(v) {
        Some((_, "")) | Some((_, "px")) => true
        _ => false
      }
  }
}

///|
/// `<ellipse>` with `rx == ry` (or one radius `auto`) is a `<circle>`.
pub let convert_ellipse_to_circle : Plugin = {
  name: "convertEllipseToCircle",
  description: "convert ellipses with equal radii to circles",
  run: (doc, _) => {
    let mut changed = false
    doc.each_element((e, _) => {
      if e.name == "ellipse" {
        let rx = e.attrs.get("rx").unwrap_or("auto")
        let ry = e.attrs.get("ry").unwrap_or("auto")
        if rx == ry || rx == "auto" || ry == "auto" {
          let r = if rx == "auto" { ry } else { rx }
          if r != "auto" {
            e.name = "circle"
            e.attrs.remove("rx")
            e.attrs.remove("ry")
            e.attrs["r"] = r
            changed = true
          }
        }
      }
    })
    changed
  },
}

///|
/// Optimize the `d` attribute of every path.
pub let convert_path_data : Plugin = {
  name: "convertPathData",
  description: "optimize path data",
  run: (doc, ctx) => {
    let mut changed = false
    let options = { ..@path.Options::default(), precision: ctx.precision, }
    // Build class -> property maps from <style> elements so paths that
    // inherit marker or linecap via CSS are handled correctly.
    let linecap_by_class : Map[String, String] = Map([])
    let marker_classes : Set[String] = Set([])
    // Stylesheets can set a stroke we cannot resolve here (type selectors,
    // descendant combinators); if any rule mentions stroke, assume every
    // path may be stroked so `z` is neither added nor removed.
    let mut css_strokes = false
    doc.each_element((e, _) => {
      if e.name == "style" {
        for c in e.children {
          match c {
            Text(t) | CData(t) => {
              collect_style_props(t, linecap_by_class, marker_classes)
              if t.contains("stroke") {
                css_strokes = true
              }
            }
            _ => ()
          }
        }
      }
    })
    // Walk the tree tracking inherited stroke / linecap / linejoin so the
    // path optimizer can decide whether a closing `z` is visually redundant.
    fn walk(
      e : @xml.Element,
      inh_stroke : String,
      inh_sw : String,
      inh_lc : String,
      inh_lj : String,
      linecap_by_class : Map[String, String],
      marker_classes : Set[String],
      options : @path.Options,
      ctx : Context,
      changed : (Bool) -> Unit,
    ) -> Unit {
      let stroke = match presentation(e, "stroke") {
        Some(v) => v
        None => inh_stroke
      }
      let sw = match presentation(e, "stroke-width") {
        Some(v) => v
        None => inh_sw
      }
      let linecap = match presentation(e, "stroke-linecap") {
        Some(v) => v.trim().to_owned()
        None =>
          match e.attrs.get("class") {
            Some(cls) => {
              let mut lc = inh_lc
              for c in cls.split(" ") {
                let c = c.trim().to_owned()
                if c.length() > 0 {
                  match linecap_by_class.get(c) {
                    Some(v) => lc = v
                    None => ()
                  }
                }
              }
              lc
            }
            None => inh_lc
          }
      }
      let linejoin = match presentation(e, "stroke-linejoin") {
        Some(v) => v
        None => inh_lj
      }
      let has_stroke = css_strokes || (stroke != "none" && sw != "0")
      if e.name == "path" && e.attrs.get("d") is Some(d) {
        // applyTransforms: drop identity transforms (the full transform
        // application to path data is not implemented, but identity
        // transforms are always safe to remove).
        match e.attrs.get("transform") {
          Some(tv) =>
            match parse_transform(tv) {
              Some(list) if list.all(is_identity) => {
                e.attrs.remove("transform")
                changed(true)
              }
              _ => ()
            }
          None => ()
        }
        // marker-mid is placed on every vertex including zero-length
        // segments; marker-start/end only care about the path endpoints, so
        // only marker-mid forces us to keep the segment structure intact.
        let has_marker_mid = e.attrs.contains("marker-mid") ||
          (match e.attrs.get("class") {
            Some(cls) =>
              cls
              .split(" ")
              .any(c => marker_classes.contains(c.trim().to_owned()))
            None => false
          })
        // The memo of already-optimal path data is only valid in the default
        // context: with a stroke the result also depends on linecap/linejoin,
        // and the same `d` may appear on differently styled elements.
        let memo_ok = !has_marker_mid && !has_stroke
        if memo_ok && ctx.optimized_paths.contains(d) {
          return
        }
        let opts = if has_marker_mid {
          {
            ..options,
            remove_useless: false,
            collapse_repeated: false,
            convert_to_z: false,
          }
        } else {
          { ..options, linecap, linejoin, has_stroke, }
        }
        try {
          let segs = @path.parse(d)
          // marker-start/end on a path that originally had drawing commands
          // but optimizes down to only M/m needs an explicit `z` so the
          // marker renders consistently across clients.
          let has_marker_se = e.attrs.contains("marker-start") ||
            e.attrs.contains("marker-end")
          let includes_vertices = segs.any(s => s.cmd != 'M' && s.cmd != 'm')
          let optimized = @path.optimize(segs, options=opts)
          let all_moveto = optimized.all(s => s.cmd == 'M' || s.cmd == 'm')
          if has_marker_se && includes_vertices && all_moveto {
            optimized.push({ cmd: 'z', args: [], })
          }
          let out = @path.stringify(optimized, precision=ctx.precision)
          if out != d {
            e.attrs["d"] = out
            changed(true)
          } else if memo_ok {
            ctx.optimized_paths.add(d)
          }
        } catch {
          _ => ()
        }
      }
      for c in e.children {
        if c is @xml.Element(child) {
          walk(
            child, stroke, sw, linecap, linejoin, linecap_by_class, marker_classes,
            options, ctx, changed,
          )
        }
      }
    }
    for c in doc.children {
      if c is @xml.Element(e) {
        walk(
          e,
          "none",
          "1",
          "butt",
          "miter",
          linecap_by_class,
          marker_classes,
          options,
          ctx,
          b => changed = changed || b,
        )
      }
    }
    changed
  },
}

///|
/// A presentation property as the renderer resolves it on this element: the
/// `style` attribute wins over the attribute of the same name.
fn presentation(e : @xml.Element, name : String) -> String? {
  if e.attrs.get("style") is Some(css) {
    for decl in css.split(";") {
      match decl.split_once(":") {
        Some((k, v)) => if k.trim() == name { return Some(v.trim().to_owned()) }
        None => ()
      }
    }
  }
  e.attrs.get(name)
}

///|
/// Extract `.class { property: value; }` rules from CSS text. Populates
/// `linecap` with stroke-linecap values and `markers` with class names that
/// set any marker-* property. Only simple class selectors are handled.
fn collect_style_props(
  css : String,
  linecap : Map[String, String],
  markers : Set[String],
) -> Unit {
  for block in css.split("}") {
    let parts = block.split("{").to_array()
    if parts.length() != 2 {
      continue
    }
    let selector = parts[0].trim().to_owned()
    let body = parts[1].trim().to_owned()
    if !selector.has_prefix(".") {
      continue
    }
    let cls = selector[1:].trim().to_owned()
    for decl in body.split(";") {
      let kv = decl.split(":").to_array()
      if kv.length() == 2 {
        let k = kv[0].trim().to_owned()
        let v = kv[1].trim().to_owned()
        if k == "stroke-linecap" {
          linecap[cls] = v
        } else if k == "marker" ||
          k == "marker-start" ||
          k == "marker-mid" ||
          k == "marker-end" {
          markers.add(cls)
        }
      }
    }
  }
}

///|
/// Merge adjacent paths with identical attributes when their bounding boxes
/// do not overlap, so fill rules cannot interact.
pub let merge_paths : Plugin = {
  name: "mergePaths",
  description: "merge adjacent non-overlapping paths with the same attributes",
  run: (doc, ctx) => {
    let mut changed = false
    // Collect CSS rules that set marker-*, clip-path, mask, mask-image,
    // fill, stroke or filter — these can make a merge unsafe even when the
    // attribute is not on the element itself.
    let marker_classes : Set[String] = Set([])
    let url_classes : Set[String] = Set([])
    let clip_mask_classes : Set[String] = Set([])
    doc.each_element((e, _) => {
      if e.name == "style" {
        for c in e.children {
          match c {
            Text(t) | CData(t) =>
              collect_merge_style(
                t, marker_classes, url_classes, clip_mask_classes,
              )
            _ => ()
          }
        }
      }
    })
    doc.each_element((parent, _) => {
      // A run of mergeable neighbours is accumulated as segments and hulls
      // and written back once the run ends: re-parsing the growing `d` on
      // every step made a 300-path map quadratic.
      let mut acc_segs : Array[@path.Segment] = []
      let mut acc_hulls : Array[Array[Pt]] = []
      let mut acc_active = false
      let flush = fn(a : @xml.Element) {
        if acc_active {
          a.attrs["d"] = @path.stringify(acc_segs, precision=ctx.precision)
          acc_active = false
          changed = true
        }
      }
      let mut i = 0
      while i + 1 < parent.children.length() {
        match (parent.children[i], parent.children[i + 1]) {
          (Element(a), Element(b)) if a.name == "path" && b.name == "path" => {
            let da = a.attrs.get("d").unwrap_or("")
            let a_hulls = if acc_active {
              acc_hulls
            } else {
              path_hulls(ctx, da)
            }
            if mergeable(
                a, b, a_hulls, marker_classes, url_classes, clip_mask_classes, ctx,
              ) {
              let db = b.attrs.get("d").unwrap_or("")
              let sb = @path.parse(db) catch { _ => [] }
              if !acc_active {
                acc_segs = @path.parse(da) catch { _ => [] }
                acc_hulls = a_hulls.copy()
                acc_active = true
              }
              append_segments(acc_segs, sb)
              acc_hulls.append(path_hulls(ctx, db))
              ignore(parent.children.remove(i + 1))
            } else {
              flush(a)
              i += 1
            }
          }
          (Element(a), _) => {
            flush(a)
            i += 1
          }
          _ => i += 1
        }
      }
      if i < parent.children.length() && parent.children[i] is Element(a) {
        flush(a)
      }
    })
    changed
  },
}

///|
/// Parse `.cls { prop: value; }` rules from CSS text and record classes that
/// set markers, url() paints/effects, or clip-path/mask. Only simple class
/// selectors (`.foo`, `tag.foo`, `.foo.bar`) are handled; anything else is
/// conservatively ignored.
fn collect_merge_style(
  css : String,
  markers : Set[String],
  urls : Set[String],
  clip_mask : Set[String],
) -> Unit {
  for block in css.split("}") {
    let parts = block.split("{").to_array()
    if parts.length() != 2 {
      continue
    }
    let selector = parts[0].trim().to_owned()
    let body = parts[1].trim().to_owned()
    // extract class names from the selector
    let classes : Array[String] = []
    for tok in selector.split(" ") {
      let tok = tok.trim()
      if tok.is_empty() {
        continue
      }
      // split on '.' to get class segments
      let segs = tok.split(".").to_array()
      if segs.length() > 1 {
        for i in 1..<segs.length() {
          let cls = segs[i].trim().to_owned()
          if cls.length() > 0 {
            classes.push(cls)
          }
        }
      }
    }
    if classes.length() == 0 {
      continue
    }
    for decl in body.split(";") {
      let kv = decl.split(":").to_array()
      if kv.length() != 2 {
        continue
      }
      let k = kv[0].trim().to_owned()
      let v = kv[1].trim().to_owned()
      if k == "marker" ||
        k == "marker-start" ||
        k == "marker-mid" ||
        k == "marker-end" {
        for cls in classes {
          markers.add(cls)
        }
      } else if k == "clip-path" || k == "mask" || k == "mask-image" {
        for cls in classes {
          clip_mask.add(cls)
        }
      } else if (k == "fill" || k == "stroke" || k == "filter") &&
        v.contains("url(") {
        for cls in classes {
          urls.add(cls)
        }
      }
    }
  }
}

///|
/// True when the element has a marker, clip-path, mask, mask-image, or a
/// url() reference in fill/stroke/filter, whether set directly, via the
/// `style` attribute, or via a CSS class.
fn has_merge_restriction(
  e : @xml.Element,
  marker_classes : Set[String],
  url_classes : Set[String],
  clip_mask_classes : Set[String],
) -> Bool {
  for k, v in e.attrs {
    if k.has_prefix("marker") {
      return true
    }
    if k == "clip-path" || k == "mask" || k == "mask-image" {
      return true
    }
    if (k == "fill" || k == "stroke" || k == "filter") && v.contains("url(") {
      return true
    }
  }
  if e.attrs.get("style") is Some(css) {
    for decl in css.split(";") {
      match decl.split_once(":") {
        Some((k, v)) => {
          let k = k.trim()
          let v = v.trim()
          if k.has_prefix("marker") ||
            k == "clip-path" ||
            k == "mask" ||
            k == "mask-image" {
            return true
          }
          if (k == "fill" || k == "stroke" || k == "filter") &&
            v.contains("url(") {
            return true
          }
        }
        None => ()
      }
    }
  }
  match e.attrs.get("class") {
    Some(cls) =>
      for c in cls.split(" ") {
        let c = c.trim().to_owned()
        if c.length() > 0 &&
          (
            marker_classes.contains(c) ||
            url_classes.contains(c) ||
            clip_mask_classes.contains(c)
          ) {
          return true
        }
      }
    None => ()
  }
  false
}

///|
/// Append path `sb` to `out`. A path's first `m` is absolute on its own but
/// relative once it follows another subpath, so it becomes `M` (its implicit
/// trailing pairs stay relative as an explicit `l`). A moveto immediately
/// followed by another moveto is dropped: a bare `M x y` with no drawing
/// commands after it contributes nothing.
fn append_segments(
  out : Array[@path.Segment],
  sb : Array[@path.Segment],
) -> Unit {
  for i, seg in sb {
    let seg : @path.Segment = if i == 0 && seg.cmd == 'm' {
      let first = @path.Segment::{ cmd: 'M', args: seg.args[:2].to_owned(), }
      if seg.args.length() > 2 {
        out.push(first)
        @path.Segment::{ cmd: 'l', args: seg.args[2:].to_owned(), }
      } else {
        first
      }
    } else {
      seg
    }
    // drop a trailing moveto when the next command is also a moveto
    if out.length() > 0 &&
      is_moveto(out[out.length() - 1].cmd) &&
      is_moveto(seg.cmd) {
      ignore(out.pop())
    }
    out.push(seg)
  }
}

///|
fn is_moveto(cmd : Char) -> Bool {
  cmd == 'M' || cmd == 'm'
}

///|
fn mergeable(
  a : @xml.Element,
  b : @xml.Element,
  a_hulls : Array[Array[Pt]],
  marker_classes : Set[String],
  url_classes : Set[String],
  clip_mask_classes : Set[String],
  ctx : Context,
) -> Bool {
  guard a.attrs.length() == b.attrs.length() &&
    !a.attrs.contains("id") &&
    !b.attrs.contains("id") else {
    return false
  }
  for k, v in a.attrs {
    if k == "d" {
      continue
    }
    if b.attrs.get(k) != Some(v) {
      return false
    }
  }
  // markers, clip-path, mask and url() paints make a merge unsafe
  if has_merge_restriction(a, marker_classes, url_classes, clip_mask_classes) ||
    has_merge_restriction(b, marker_classes, url_classes, clip_mask_classes) {
    return false
  }
  guard a.attrs.contains("d") && b.attrs.get("d") is Some(db) else {
    return false
  }
  // paths must not intersect so fill rules cannot interact
  !hulls_intersect(
    a_hulls,
    path_hulls(ctx, db),
    @math.pow(10.0, -ctx.precision.to_double()),
  )
}

///|
/// Convex hulls of the subpaths of `d`, cached on the context: each path is
/// tested against both neighbours and again on every multipass round, and
/// parsing plus hull building dominates the cost of mergePaths.
fn path_hulls(ctx : Context, d : String) -> Array[Array[Pt]] {
  match ctx.path_hulls.get(d) {
    Some(h) => h
    None => {
      let hulls : Array[Array[Pt]] = gather_points(to_absolute(@path.parse(d))).map(
        convex_hull,
      ) catch {
        _ => []
      }
      ctx.path_hulls[d] = hulls
      hulls
    }
  }
}

///|
/// A 2D point.
type Pt = (Double, Double)

///|
/// Convert every relative command in `segs` to its absolute form.
fn to_absolute(segs : Array[@path.Segment]) -> Array[@path.Segment] {
  let out : Array[@path.Segment] = []
  let mut cx = 0.0
  let mut cy = 0.0
  let mut sx = 0.0
  let mut sy = 0.0
  for seg in segs {
    let a = seg.args
    match seg.cmd {
      'm' => {
        let nx = cx + a[0]
        let ny = cy + a[1]
        out.push({ cmd: 'M', args: [nx, ny], })
        cx = nx
        cy = ny
        sx = nx
        sy = ny
      }
      'M' => {
        out.push(seg)
        cx = a[0]
        cy = a[1]
        sx = a[0]
        sy = a[1]
      }
      'l' => {
        out.push({ cmd: 'L', args: [cx + a[0], cy + a[1]], })
        cx += a[0]
        cy += a[1]
      }
      'L' => {
        out.push(seg)
        cx = a[0]
        cy = a[1]
      }
      'h' => {
        out.push({ cmd: 'H', args: [cx + a[0]], })
        cx += a[0]
      }
      'H' => {
        out.push(seg)
        cx = a[0]
      }
      'v' => {
        out.push({ cmd: 'V', args: [cy + a[0]], })
        cy += a[0]
      }
      'V' => {
        out.push(seg)
        cy = a[0]
      }
      'c' => {
        out.push({
          cmd: 'C',
          args: [
            cx + a[0],
            cy + a[1],
            cx + a[2],
            cy + a[3],
            cx + a[4],
            cy + a[5],
          ],
        })
        cx += a[4]
        cy += a[5]
      }
      'C' => {
        out.push(seg)
        cx = a[4]
        cy = a[5]
      }
      's' => {
        out.push({
          cmd: 'S',
          args: [cx + a[0], cy + a[1], cx + a[2], cy + a[3]],
        })
        cx += a[2]
        cy += a[3]
      }
      'S' => {
        out.push(seg)
        cx = a[2]
        cy = a[3]
      }
      'q' => {
        out.push({
          cmd: 'Q',
          args: [cx + a[0], cy + a[1], cx + a[2], cy + a[3]],
        })
        cx += a[2]
        cy += a[3]
      }
      'Q' => {
        out.push(seg)
        cx = a[2]
        cy = a[3]
      }
      't' => {
        out.push({ cmd: 'T', args: [cx + a[0], cy + a[1]], })
        cx += a[0]
        cy += a[1]
      }
      'T' => {
        out.push(seg)
        cx = a[0]
        cy = a[1]
      }
      'a' => {
        out.push({
          cmd: 'A',
          args: [a[0], a[1], a[2], a[3], a[4], cx + a[5], cy + a[6]],
        })
        cx += a[5]
        cy += a[6]
      }
      'A' => {
        out.push(seg)
        cx = a[5]
        cy = a[6]
      }
      'z' | 'Z' => {
        out.push({ cmd: 'z', args: [], })
        cx = sx
        cy = sy
      }
      _ => out.push(seg)
    }
  }
  out
}

///|
/// Collect the points of every subpath, approximating curves with their
/// control points. Arcs are split into cubic Bézier segments first.
fn gather_points(segs : Array[@path.Segment]) -> Array[Array[Pt]] {
  let subpaths : Array[Array[Pt]] = []
  let mut current : Array[Pt] = []
  let mut cx = 0.0
  let mut cy = 0.0
  let mut prev_ctrl : Pt? = None
  fn add(p : Pt) -> Unit {
    current.push(p)
  }
  for seg in segs {
    let a = seg.args
    match seg.cmd {
      'M' => {
        if current.length() > 0 {
          subpaths.push(current)
        }
        current = []
        cx = a[0]
        cy = a[1]
        add((cx, cy))
      }
      'L' => {
        cx = a[0]
        cy = a[1]
        add((cx, cy))
      }
      'H' => {
        cx = a[0]
        add((cx, cy))
      }
      'V' => {
        cy = a[0]
        add((cx, cy))
      }
      'Q' => {
        add((a[0], a[1]))
        cx = a[2]
        cy = a[3]
        add((cx, cy))
        prev_ctrl = Some((a[0], a[1]))
      }
      'T' => {
        let ctrl = match prev_ctrl {
          Some((px, py)) => (2.0 * cx - px, 2.0 * cy - py)
          None => (cx, cy)
        }
        add(ctrl)
        cx = a[0]
        cy = a[1]
        add((cx, cy))
        prev_ctrl = Some(ctrl)
      }
      'C' => {
        add((a[0], a[1]))
        add((a[2], a[3]))
        cx = a[4]
        cy = a[5]
        add((cx, cy))
        prev_ctrl = Some((a[2], a[3]))
      }
      'S' => {
        let ctrl = match prev_ctrl {
          Some((px, py)) => (2.0 * cx - px, 2.0 * cy - py)
          None => (cx, cy)
        }
        add(ctrl)
        add((a[0], a[1]))
        cx = a[2]
        cy = a[3]
        add((cx, cy))
        prev_ctrl = Some((a[0], a[1]))
      }
      'A' => {
        let curves = arc_to_curves(
          cx,
          cy,
          a[0],
          a[1],
          a[2],
          a[3],
          a[4],
          a[5],
          a[6],
        )
        for c in curves {
          // arc_to_curves returns relative coordinates; make them absolute
          let p1x = cx + c[0]
          let p1y = cy + c[1]
          let p2x = cx + c[2]
          let p2y = cy + c[3]
          let ex = cx + c[4]
          let ey = cy + c[5]
          add((p1x, p1y))
          add((p2x, p2y))
          cx = ex
          cy = ey
          add((cx, cy))
        }
        prev_ctrl = None
      }
      'z' =>
        // close path; the start point is already in the list
        ()
      _ => ()
    }
    if seg.cmd != 'T' && seg.cmd != 'S' && seg.cmd != 'Q' && seg.cmd != 'C' {
      prev_ctrl = None
    }
  }
  if current.length() > 0 {
    subpaths.push(current)
  }
  subpaths
}

///|
/// Convert an SVG arc to a list of cubic Bézier curves (each 6 coordinates:
/// x1 y1 x2 y2 x y). Ported from svgo's `a2c`.
fn arc_to_curves(
  x1 : Double,
  y1 : Double,
  rx : Double,
  ry : Double,
  angle : Double,
  large_arc : Double,
  sweep : Double,
  x2 : Double,
  y2 : Double,
) -> Array[Array[Double]] {
  let pi = 3.141592653589793
  let _120 = pi * 120.0 / 180.0
  let rad = pi / 180.0 * angle
  let res : Array[Array[Double]] = []

  fn rotate_x(x : Double, y : Double, r : Double) -> Double {
    x * @math.cos(r) - y * @math.sin(r)
  }
  fn rotate_y(x : Double, y : Double, r : Double) -> Double {
    x * @math.sin(r) + y * @math.cos(r)
  }

  let mut x1 = x1
  let mut y1 = y1
  let mut x2 = x2
  let mut y2 = y2
  let mut rx = rx
  let mut ry = ry
  let mut cx = 0.0
  let mut cy = 0.0
  let mut f1 = 0.0
  let mut f2 = 0.0

  let x1r = rotate_x(x1, y1, -rad)
  let y1r = rotate_y(x1, y1, -rad)
  let x2r = rotate_x(x2, y2, -rad)
  let y2r = rotate_y(x2, y2, -rad)
  x1 = x1r
  y1 = y1r
  x2 = x2r
  y2 = y2r
  let x = (x1 - x2) / 2.0
  let y = (y1 - y2) / 2.0
  let mut h = x * x / (rx * rx) + y * y / (ry * ry)
  if h > 1.0 {
    h = h.sqrt()
    rx = h * rx
    ry = h * ry
  }
  let rx2 = rx * rx
  let ry2 = ry * ry
  let sign = if large_arc == sweep { -1.0 } else { 1.0 }
  let k = sign *
    ((rx2 * ry2 - rx2 * y * y - ry2 * x * x) / (rx2 * y * y + ry2 * x * x))
    .abs()
    .sqrt()
  cx = k * rx * y / ry + (x1 + x2) / 2.0
  cy = k * -ry * x / rx + (y1 + y2) / 2.0
  f1 = @math.asin((y1 - cy) / ry)
  f2 = @math.asin((y2 - cy) / ry)
  f1 = if x1 < cx { pi - f1 } else { f1 }
  f2 = if x2 < cx { pi - f2 } else { f2 }
  if f1 < 0.0 {
    f1 = pi * 2.0 + f1
  }
  if f2 < 0.0 {
    f2 = pi * 2.0 + f2
  }
  if sweep == 1.0 && f1 > f2 {
    f1 = f1 - pi * 2.0
  }
  if sweep == 0.0 && f2 > f1 {
    f2 = f2 - pi * 2.0
  }

  let mut df = f2 - f1
  if df.abs() > _120 {
    let x2old = x2
    let y2old = y2
    f2 = f1 + _120 * (if sweep == 1.0 && f2 > f1 { 1.0 } else { -1.0 })
    x2 = cx + rx * @math.cos(f2)
    y2 = cy + ry * @math.sin(f2)
    let sub = arc_to_curves(x2, y2, rx, ry, angle, 0.0, sweep, x2old, y2old)
    for s in sub {
      res.push(s)
    }
  }
  df = f2 - f1
  let c1 = @math.cos(f1)
  let s1 = @math.sin(f1)
  let c2 = @math.cos(f2)
  let s2 = @math.sin(f2)
  let t = @math.tan(df / 4.0)
  let hx = 4.0 / 3.0 * rx * t
  let hy = 4.0 / 3.0 * ry * t
  let m = [
    -hx * s1,
    hy * c1,
    x2 + hx * s2 - x1,
    y2 - hy * c2 - y1,
    x2 - x1,
    y2 - y1,
  ]
  // `m` is one cubic bezier (6 coords); prepend it to the recursive results
  // and rotate every (x, y) pair back by `angle`.
  let all : Array[Double] = []
  for v in m {
    all.push(v)
  }
  for sub in res {
    for v in sub {
      all.push(v)
    }
  }
  let rotated : Array[Double] = []
  let mut i = 0
  while i + 1 < all.length() {
    let x = all[i]
    let y = all[i + 1]
    rotated.push(rotate_x(x, y, rad))
    rotated.push(rotate_y(x, y, rad))
    i += 2
  }
  // split into individual cubic bezier curves (6 coordinates each)
  let curves : Array[Array[Double]] = []
  let mut j = 0
  while j + 5 < rotated.length() {
    let curve : Array[Double] = []
    for k in 0..<6 {
      curve.push(rotated[j + k])
    }
    curves.push(curve)
    j += 6
  }
  curves
}

///|
/// Monotone-chain convex hull of a set of points.
fn convex_hull(pts : Array[Pt]) -> Array[Pt] {
  if pts.length() < 3 {
    return pts
  }
  let sorted = pts
  sorted.sort_by((a, b) => {
    if a.0 == b.0 {
      (a.1 - b.1).to_int()
    } else {
      (a.0 - b.0).to_int()
    }
  })
  fn cross(o : Pt, a : Pt, b : Pt) -> Double {
    (a.0 - o.0) * (b.1 - o.1) - (a.1 - o.1) * (b.0 - o.0)
  }
  let lower : Array[Pt] = []
  for p in sorted {
    while lower.length() >= 2 &&
          cross(lower[lower.length() - 2], lower[lower.length() - 1], p) <= 0.0 {
      ignore(lower.pop())
    }
    lower.push(p)
  }
  let upper : Array[Pt] = []
  let mut i = sorted.length() - 1
  while i >= 0 {
    let p = sorted[i]
    while upper.length() >= 2 &&
          cross(upper[upper.length() - 2], upper[upper.length() - 1], p) <= 0.0 {
      ignore(upper.pop())
    }
    upper.push(p)
    i -= 1
  }
  ignore(lower.pop())
  ignore(upper.pop())
  let hull : Array[Pt] = []
  for p in lower {
    hull.push(p)
  }
  for p in upper {
    hull.push(p)
  }
  hull
}

///|
/// GJK intersection test between two convex polygons (point lists).
fn gjk_intersect(hull1 : Array[Pt], hull2 : Array[Pt]) -> Bool {
  if hull1.length() < 3 || hull2.length() < 3 {
    return false
  }
  fn dot(a : Pt, b : Pt) -> Double {
    a.0 * b.0 + a.1 * b.1
  }
  fn sub(a : Pt, b : Pt) -> Pt {
    (a.0 - b.0, a.1 - b.1)
  }
  fn neg(a : Pt) -> Pt {
    (-a.0, -a.1)
  }
  fn support(hull : Array[Pt], dir : Pt) -> Pt {
    let mut best = hull[0]
    let mut max_dot = dot(best, dir)
    for p in hull {
      let d = dot(p, dir)
      if d > max_dot {
        max_dot = d
        best = p
      }
    }
    best
  }
  fn support_point(dir : Pt) -> Pt {
    sub(support(hull1, dir), support(hull2, neg(dir)))
  }
  let simplex : Array[Pt] = [support_point((1.0, 0.0))]
  let mut direction = neg(simplex[0])
  // GJK settles in a few steps for separated hulls; it only keeps going when
  // the hulls touch, and then merging would be wrong anyway. svgo caps at
  // 10 000 and treats exhaustion as an intersection; 100 is plenty here and
  // keeps a touching pair from costing milliseconds.
  let mut iterations = 100
  while iterations > 0 {
    iterations -= 1
    let a = support_point(direction)
    if dot(a, direction) <= 0.0 {
      return false
    }
    simplex.push(a)
    let (hit, new_dir) = process_simplex(simplex, direction)
    direction = new_dir
    if hit {
      return true
    }
  }
  true
}

///|
/// Process the GJK simplex and update the search direction. Returns
/// `(contains_origin, new_direction)`.
fn process_simplex(simplex : Array[Pt], direction : Pt) -> (Bool, Pt) {
  fn dot(a : Pt, b : Pt) -> Double {
    a.0 * b.0 + a.1 * b.1
  }
  fn sub(a : Pt, b : Pt) -> Pt {
    (a.0 - b.0, a.1 - b.1)
  }
  fn neg(a : Pt) -> Pt {
    (-a.0, -a.1)
  }
  fn orth(v : Pt, from : Pt) -> Pt {
    let o = (-v.1, v.0)
    if dot(o, neg(from)) < 0.0 {
      neg(o)
    } else {
      o
    }
  }
  if simplex.length() == 2 {
    let a = simplex[1]
    let b = simplex[0]
    let ao = neg(a)
    let ab = sub(b, a)
    if dot(ao, ab) > 0.0 {
      (false, orth(ab, a))
    } else {
      ignore(simplex.remove(0))
      (false, ao)
    }
  } else {
    let a = simplex[2]
    let b = simplex[1]
    let c = simplex[0]
    let ab = sub(b, a)
    let ac = sub(c, a)
    let ao = neg(a)
    let acb = orth(ab, ac)
    let abc = orth(ac, ab)
    if dot(acb, ao) > 0.0 {
      if dot(ab, ao) > 0.0 {
        ignore(simplex.remove(0))
        (false, acb)
      } else {
        ignore(simplex.remove(0))
        ignore(simplex.remove(0))
        (false, ao)
      }
    } else if dot(abc, ao) > 0.0 {
      if dot(ac, ao) > 0.0 {
        ignore(simplex.remove(1))
        (false, abc)
      } else {
        ignore(simplex.remove(0))
        ignore(simplex.remove(0))
        (false, ao)
      }
    } else {
      (true, direction)
    }
  }
}

///|
/// True when two paths, given as the convex hulls of their subpaths, have
/// any intersecting subpaths (GJK). Degenerate subpaths (fewer than three
/// distinct points) are ignored. `gap` (10^-precision) widens the
/// bounding-box pre-check so paths that merely touch at sub-precision
/// distances are not merged (rounding could make them overlap).
fn hulls_intersect(
  hulls1 : Array[Array[Pt]],
  hulls2 : Array[Array[Pt]],
  gap : Double,
) -> Bool {
  // bounding boxes once per hull, not once per pair: a map with many
  // islands on both sides otherwise pays k1 * k2 * |hull| per neighbour
  let boxes2 = hulls2.map(hull_bbox)
  for h1 in hulls1 {
    if h1.length() < 3 {
      continue
    }
    let (min1x, min1y, max1x, max1y) = hull_bbox(h1)
    for j, h2 in hulls2 {
      if h2.length() < 3 {
        continue
      }
      let (min2x, min2y, max2x, max2y) = boxes2[j]
      // bounding boxes separated by more than `gap` => no intersection
      if max1x + gap < min2x ||
        max2x + gap < min1x ||
        max1y + gap < min2y ||
        max2y + gap < min1y {
        continue
      }
      if gjk_intersect(h1, h2) {
        return true
      }
    }
  }
  false
}

///|
fn hull_bbox(hull : Array[Pt]) -> (Double, Double, Double, Double) {
  if hull.is_empty() {
    return (0.0, 0.0, 0.0, 0.0)
  }
  let mut minx = hull[0].0
  let mut miny = hull[0].1
  let mut maxx = minx
  let mut maxy = miny
  for p in hull {
    if p.0 < minx {
      minx = p.0
    }
    if p.1 < miny {
      miny = p.1
    }
    if p.0 > maxx {
      maxx = p.0
    }
    if p.1 > maxy {
      maxy = p.1
    }
  }
  (minx, miny, maxx, maxy)
}

///|
/// Drop `width`/`height` when a viewBox exists so the image scales to its container.
pub let remove_dimensions : Plugin = {
  name: "removeDimensions",
  description: "remove width/height from the root when viewBox is present",
  run: (doc, _) => {
    guard doc.root() is Some(root) else { return false }
    if root.attrs.contains("viewBox") &&
      (root.attrs.contains("width") || root.attrs.contains("height")) {
      root.attrs.remove("width")
      root.attrs.remove("height")
      true
    } else {
      false
    }
  },
}

///|
/// Drop `<title>` (optional: titles are accessible names, keep them for UI icons).
pub let remove_title : Plugin = {
  name: "removeTitle",
  description: "remove <title>",
  run: (doc, _) => remove_elements(doc, (e, _) => e.name == "title"),
}
