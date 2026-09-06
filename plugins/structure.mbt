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
/// Remove attributes equal to their default values, `version`, unknown
/// `xml:space` and empty `xlink` declarations.
pub let remove_unknowns_and_defaults : Plugin = {
  name: "removeUnknownsAndDefaults",
  description: "remove default attribute values",
  run: (doc, ctx) => {
    let mut changed = false
    fn walk(e : @xml.Element, chain : Array[@xml.Element]) {
      for kv in e.attrs.to_array() {
        let (k, v) = kv
        // ids of referenced elements must survive regardless
        if (e.name == "svg" && k == "version") || k == "baseProfile" {
          e.attrs.remove(k)
          changed = true
          continue
        }
        if k == "xml:space" && v == "default" {
          e.attrs.remove(k)
          changed = true
          continue
        }
        let normalized = if k == "fill" && v.trim().to_lower() == "black" {
          "#000"
        } else {
          v.trim().to_owned()
        }
        match default_values.get(k) {
          Some(d) if d == normalized =>
            // an inherited attribute may be shadowing an ancestor's value
            if !inheritable.contains(k) || !ancestors_define(chain, k) {
              // stroke="none" is the default but keep it when an ancestor strokes
              e.attrs.remove(k)
              changed = true
              continue
            }
          _ => ()
        }
        match zero_defaults.get(e.name) {
          Some(list) if list.contains(k) =>
            match split_unit(v) {
              Some((n, _)) if @path.round_to(n, ctx.precision) == 0.0 => {
                // rx/ry default to each other, only drop when both are zero or absent
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
          _ => ()
        }
      }
      let next = chain.copy()
      next.push(e)
      for c in e.children {
        if c is Element(child) {
          walk(child, next)
        }
      }
    }
    if doc.root() is Some(root) {
      walk(root, [])
    }
    changed
  },
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
      let referenced = e.attrs.get("id") is Some(id) && ids.contains(id)
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
      let next = chain.copy()
      next.push(e)
      for c in e.children {
        if c is Element(child) {
          walk(child, next)
        }
      }
    }
    if doc.root() is Some(root) {
      walk(root, [])
    }
    changed
  },
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
      let elems = g.elements()
      // move attributes onto a single child when that is unambiguous
      if elems.length() == 1 &&
        g.children.length() == 1 &&
        !g.attrs.contains("id") &&
        !g.attrs.contains("filter") &&
        !g.attrs.contains("clip-path") &&
        !g.attrs.contains("mask") {
        let child = elems[0]
        let mut ok = true
        for k, _ in g.attrs {
          if child.attrs.contains(k) && k != "transform" {
            // the child's own value already wins, unless it is `inherit`
            if child.attrs.get(k) != Some("inherit") {
              continue
            }
            ok = false
          }
          if k == "transform" && child.attrs.contains("transform") {
            // transforms compose: g's transform goes first
            continue
          }
        }
        if ok {
          for k, v in g.attrs {
            if k == "transform" && child.attrs.get("transform") is Some(t) {
              child.attrs[k] = v + " " + t
            } else if !child.attrs.contains(k) ||
              child.attrs.get(k) == Some("inherit") {
              child.attrs[k] = v
            }
          }
          g.attrs.clear()
          changed = true
        }
      }
      if g.attrs.length() == 0 {
        // splice children into the parent
        let idx = p.children.search_by(c => c is Element(x) && physical_eq(x, g))
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
    doc.each_element((e, _) => {
      if e.name == "path" && e.attrs.get("d") is Some(d) {
        // marker positions depend on zero-length segments; keep those paths intact
        let has_markers = e.attrs.contains("marker-start") ||
          e.attrs.contains("marker-mid") ||
          e.attrs.contains("marker-end")
        let opts = if has_markers {
          { ..options, remove_useless: false, }
        } else {
          options
        }
        try {
          let segs = @path.parse(d)
          let out = @path.stringify(
            @path.optimize(segs, options=opts),
            precision=ctx.precision,
          )
          if out != d {
            e.attrs["d"] = out
            changed = true
          }
        } catch {
          _ => ()
        }
      }
    })
    changed
  },
}

///|
/// Merge adjacent paths with identical attributes when their bounding boxes
/// do not overlap, so fill rules cannot interact.
pub let merge_paths : Plugin = {
  name: "mergePaths",
  description: "merge adjacent non-overlapping paths with the same attributes",
  run: (doc, ctx) => {
    let mut changed = false
    doc.each_element((parent, _) => {
      let mut i = 0
      while i + 1 < parent.children.length() {
        match (parent.children[i], parent.children[i + 1]) {
          (Element(a), Element(b)) if a.name == "path" &&
            b.name == "path" &&
            mergeable(a, b, ctx) => {
            a.attrs["d"] = a.attrs.get("d").unwrap() + b.attrs.get("d").unwrap()
            ignore(parent.children.remove(i + 1))
            changed = true
          }
          _ => i += 1
        }
      }
    })
    changed
  },
}

///|
fn mergeable(a : @xml.Element, b : @xml.Element, ctx : Context) -> Bool {
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
    if k.has_prefix("marker") || v.contains("url(") {
      return false
    }
  }
  guard a.attrs.get("d") is Some(da) && b.attrs.get("d") is Some(db) else {
    return false
  }
  // paths must both be closed or stroke-free for the join to be safe
  match (bbox(da), bbox(db)) {
    (Some((ax0, ay0, ax1, ay1)), Some((bx0, by0, bx1, by1))) => {
      let gap = @math.pow(10.0, -ctx.precision.to_double())
      ax1 + gap < bx0 || bx1 + gap < ax0 || ay1 + gap < by0 || by1 + gap < ay0
    }
    _ => false
  }
}

///|
/// Conservative bounding box: the hull of all end and control points.
fn bbox(d : String) -> (Double, Double, Double, Double)? {
  let segs = @path.parse(d) catch { _ => return None }
  let mut x0 = 1.0e300
  let mut y0 = 1.0e300
  let mut x1 = -1.0e300
  let mut y1 = -1.0e300
  let mut cx = 0.0
  let mut cy = 0.0
  let mut sx = 0.0
  let mut sy = 0.0
  fn add(x : Double, y : Double) {
    if x < x0 {
      x0 = x
    }
    if y < y0 {
      y0 = y
    }
    if x > x1 {
      x1 = x
    }
    if y > y1 {
      y1 = y
    }
  }
  for seg in segs {
    let rel = seg.cmd.is_ascii_lowercase()
    let a = seg.args
    match seg.cmd.to_ascii_lowercase() {
      'z' => {
        cx = sx
        cy = sy
      }
      'h' => {
        cx = if rel { cx + a[0] } else { a[0] }
        add(cx, cy)
      }
      'v' => {
        cy = if rel { cy + a[0] } else { a[0] }
        add(cx, cy)
      }
      'a' => {
        let ex = if rel { cx + a[5] } else { a[5] }
        let ey = if rel { cy + a[6] } else { a[6] }
        // the arc lies within the box spanned by the end points grown by the radii
        let r = @cmp.maximum(a[0].abs(), a[1].abs())
        add(@cmp.minimum(cx, ex) - r, @cmp.minimum(cy, ey) - r)
        add(@cmp.maximum(cx, ex) + r, @cmp.maximum(cy, ey) + r)
        cx = ex
        cy = ey
      }
      _ => {
        let mut i = 0
        while i + 1 < a.length() {
          let px = if rel { cx + a[i] } else { a[i] }
          let py = if rel { cy + a[i + 1] } else { a[i + 1] }
          add(px, py)
          i += 2
        }
        cx = if rel { cx + a[a.length() - 2] } else { a[a.length() - 2] }
        cy = if rel { cy + a[a.length() - 1] } else { a[a.length() - 1] }
        if seg.cmd == 'm' || seg.cmd == 'M' {
          sx = cx
          sy = cy
        }
      }
    }
  }
  if x0 > x1 {
    None
  } else {
    Some((x0, y0, x1, y1))
  }
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
pub let remove_title : Plugin = {
  name: "removeTitle",
  description: "remove <title>",
  run: (doc, _) => remove_elements(doc, (e, _) => e.name == "title"),
}
