///|
/// Attributes that take a plain number or length.
let numeric_attrs : Set[String] = Set([
  "x", "y", "x1", "y1", "x2", "y2", "cx", "cy", "r", "rx", "ry", "width", "height",
  "dx", "dy", "fx", "fy", "offset", "opacity", "fill-opacity", "stroke-opacity",
  "stroke-width", "stroke-miterlimit", "stroke-dashoffset", "font-size", "letter-spacing",
  "word-spacing", "refX", "refY", "markerWidth", "markerHeight", "stdDeviation",
  "k1", "k2", "k3", "k4", "startOffset", "textLength", "pathLength",
])

///|
/// Round numbers in attribute values and drop the default `px` unit.
pub let cleanup_numeric_values : Plugin = {
  name: "cleanupNumericValues",
  description: "round numeric values and remove px units",
  run: (doc, ctx) => {
    let mut changed = false
    doc.each_element((e, _) => {
      for kv in e.attrs.to_array() {
        let (k, v) = kv
        if k == "viewBox" {
          let parts = v
            .trim()
            .replace_all(old=",", new=" ")
            .split(" ")
            .filter(s => !s.is_empty())
            .map(s => s.to_owned())
            .to_array()
          let cleaned = parts.map(s => {
            match split_unit(s) {
              Some((n, "")) => @path.format_number(n, ctx.precision)
              _ => s
            }
          })
          let joined = cleaned.join(" ")
          if joined != v {
            e.attrs[k] = joined
            changed = true
          }
          continue
        }
        guard numeric_attrs.contains(k) else { continue }
        match split_unit(v) {
          Some((n, unit)) => {
            let unit = if unit == "px" { "" } else { unit }
            let formatted = @path.format_number(n, ctx.precision) + unit
            if formatted != v {
              e.attrs[k] = formatted
              changed = true
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
/// Attributes that carry colors.
let color_attrs : Set[String] = Set([
  "fill", "stroke", "stop-color", "flood-color", "lighting-color", "color",
])

///|
/// Convert colors to their shortest equivalent form.
pub let convert_colors : Plugin = {
  name: "convertColors",
  description: "convert colors to the shortest form",
  run: (doc, ctx) => {
    let mut changed = false
    fn walk(e : @xml.Element, in_mask : Bool) {
      let in_mask = in_mask || e.name == "mask"
      for kv in e.attrs.to_array() {
        let (k, v) = kv
        if color_attrs.contains(k) {
          let c = convert_color(v, ctx, in_mask)
          if c != v {
            e.attrs[k] = c
            changed = true
          }
        } else if k == "style" && v.contains(":") {
          // fill:#FF0000 inside style attributes
          let parts = v.split(";").map(p => p.to_owned()).to_array()
          let out = parts.map(p => {
            match p.split_once(":") {
              Some((name, value)) if color_attrs.contains(
                  name.trim().to_owned(),
                ) =>
                name.trim().to_owned() +
                ":" +
                convert_color(value.trim().to_owned(), ctx, in_mask)
              _ => p
            }
          })
          let joined = out.join(";")
          if joined != v {
            e.attrs[k] = joined
            changed = true
          }
        }
      }
      for child in e.children {
        if child is Element(x) {
          walk(x, in_mask)
        }
      }
    }
    if doc.root() is Some(root) {
      walk(root, false)
    }
    changed
  },
}

///|
/// Shortest equivalent spelling of a color: `rgb()` and names become hex,
/// `#rrggbb` collapses to `#rgb` when possible, and a color name wins when
/// it is shorter than the hex form (`#ff0000` -> `red`).
pub fn shorten_color(v : String) -> String {
  convert_color(v, Context::new(), false)
}

///|
fn convert_color(v : String, ctx : Context, in_mask : Bool) -> String {
  let t = v.trim().to_owned()
  if !in_mask &&
    (
      (ctx.param_bool("currentColor", false) && t != "none") ||
      (
        ctx.param_string("currentColor", "") != "" &&
        t == ctx.param_string("currentColor", "")
      )
    ) {
    return "currentColor"
  }
  let lower = t.to_lower()
  if lower == "none" ||
    lower == "currentcolor" ||
    lower == "inherit" ||
    lower.has_prefix("url(") {
    return t
  }
  // rgb(255, 0, 0) / rgb(100%, 0%, 0%)
  if ctx.param_bool("rgb2hex", true) &&
    lower.has_prefix("rgb(") &&
    lower.has_suffix(")") {
    let inner = lower[4:lower.length() - 1].to_owned()
    let parts = inner.split(",").map(p => p.trim().to_owned()).to_array()
    if parts.length() == 3 {
      let vals : Array[Int] = []
      for p in parts {
        match split_unit(p) {
          Some((n, "%")) =>
            vals.push(@math.round(n * 2.55).to_int().clamp(min=0, max=255))
          Some((n, "")) =>
            vals.push(@math.round(n).to_int().clamp(min=0, max=255))
          _ => return t
        }
      }
      return shorten_hex(
        "#" + hex2(vals[0]) + hex2(vals[1]) + hex2(vals[2]),
        ctx,
      )
    }
    return t
  }
  if lower.has_prefix("#") {
    if lower.length() == 7 || lower.length() == 4 {
      return shorten_hex(lower, ctx)
    }
    return t
  }
  match
    (if ctx.param_bool("names2hex", true) {
      color_names().get(lower)
    } else {
      None
    }) {
    Some(hex) => shorten_hex(hex, ctx)
    None => t
  }
}

///|
fn hex2(n : Int) -> String {
  n.to_string(radix=16).pad_start(2, '0')
}

///|
fn shorten_hex(h : String, ctx : Context) -> String {
  let h = h.to_lower()
  if ctx.param_bool("shorthex", true) &&
    h.length() == 7 &&
    h.get_char(1) == h.get_char(2) &&
    h.get_char(3) == h.get_char(4) &&
    h.get_char(5) == h.get_char(6) {
    let short = "#" +
      h.get_char(1).unwrap().to_string() +
      h.get_char(3).unwrap().to_string() +
      h.get_char(5).unwrap().to_string()
    match hex_to_name().get(short) {
      Some(name) if ctx.param_bool("shortname", true) &&
        name.length() < short.length() => name
      _ => short
    }
  } else {
    match hex_to_name().get(h) {
      Some(name) if ctx.param_bool("shortname", true) &&
        name.length() < h.length() => name
      _ => h
    }
  }
}
