///|
/// Attributes that take a plain number or length.
let numeric_attrs : Array[String] = [
  "x", "y", "x1", "y1", "x2", "y2", "cx", "cy", "r", "rx", "ry", "width", "height",
  "dx", "dy", "fx", "fy", "offset", "opacity", "fill-opacity", "stroke-opacity",
  "stroke-width", "stroke-miterlimit", "stroke-dashoffset", "font-size", "letter-spacing",
  "word-spacing", "refX", "refY", "markerWidth", "markerHeight", "stdDeviation",
  "k1", "k2", "k3", "k4", "startOffset", "textLength", "pathLength",
]

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
let color_attrs : Array[String] = [
  "fill", "stroke", "stop-color", "flood-color", "lighting-color", "color",
]

///|
/// Convert colors to their shortest equivalent form.
pub let convert_colors : Plugin = {
  name: "convertColors",
  description: "convert colors to the shortest form",
  run: (doc, _) => {
    let mut changed = false
    doc.each_element((e, _) => {
      for kv in e.attrs.to_array() {
        let (k, v) = kv
        if color_attrs.contains(k) {
          let c = shorten_color(v)
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
                shorten_color(value.trim().to_owned())
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
    })
    changed
  },
}

///|
pub fn shorten_color(v : String) -> String {
  let t = v.trim().to_owned()
  let lower = t.to_lower()
  if lower == "none" ||
    lower == "currentcolor" ||
    lower == "inherit" ||
    lower.has_prefix("url(") {
    return t
  }
  // rgb(255, 0, 0) / rgb(100%, 0%, 0%)
  if lower.has_prefix("rgb(") && lower.has_suffix(")") {
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
      return shorten_hex("#" + hex2(vals[0]) + hex2(vals[1]) + hex2(vals[2]))
    }
    return t
  }
  if lower.has_prefix("#") {
    if lower.length() == 7 || lower.length() == 4 {
      return shorten_hex(lower)
    }
    return t
  }
  match color_names.get(lower) {
    Some(hex) => shorten_hex(hex)
    None => t
  }
}

///|
fn hex2(n : Int) -> String {
  n.to_string(radix=16).pad_start(2, '0')
}

///|
fn shorten_hex(h : String) -> String {
  let h = h.to_lower()
  if h.length() == 7 &&
    h.get_char(1) == h.get_char(2) &&
    h.get_char(3) == h.get_char(4) &&
    h.get_char(5) == h.get_char(6) {
    let short = "#" +
      h.get_char(1).unwrap().to_string() +
      h.get_char(3).unwrap().to_string() +
      h.get_char(5).unwrap().to_string()
    match hex_to_name.get(short) {
      Some(name) if name.length() < short.length() => name
      _ => short
    }
  } else {
    match hex_to_name.get(h) {
      Some(name) if name.length() < h.length() => name
      _ => h
    }
  }
}

///|
/// CSS named colors.
let color_names : Map[String, String] = {
  "aliceblue": "#f0f8ff",
  "antiquewhite": "#faebd7",
  "aqua": "#00ffff",
  "aquamarine": "#7fffd4",
  "azure": "#f0ffff",
  "beige": "#f5f5dc",
  "bisque": "#ffe4c4",
  "black": "#000000",
  "blanchedalmond": "#ffebcd",
  "blue": "#0000ff",
  "blueviolet": "#8a2be2",
  "brown": "#a52a2a",
  "burlywood": "#deb887",
  "cadetblue": "#5f9ea0",
  "chartreuse": "#7fff00",
  "chocolate": "#d2691e",
  "coral": "#ff7f50",
  "cornflowerblue": "#6495ed",
  "cornsilk": "#fff8dc",
  "crimson": "#dc143c",
  "cyan": "#00ffff",
  "darkblue": "#00008b",
  "darkcyan": "#008b8b",
  "darkgoldenrod": "#b8860b",
  "darkgray": "#a9a9a9",
  "darkgreen": "#006400",
  "darkgrey": "#a9a9a9",
  "darkkhaki": "#bdb76b",
  "darkmagenta": "#8b008b",
  "darkolivegreen": "#556b2f",
  "darkorange": "#ff8c00",
  "darkorchid": "#9932cc",
  "darkred": "#8b0000",
  "darksalmon": "#e9967a",
  "darkseagreen": "#8fbc8f",
  "darkslateblue": "#483d8b",
  "darkslategray": "#2f4f4f",
  "darkslategrey": "#2f4f4f",
  "darkturquoise": "#00ced1",
  "darkviolet": "#9400d3",
  "deeppink": "#ff1493",
  "deepskyblue": "#00bfff",
  "dimgray": "#696969",
  "dimgrey": "#696969",
  "dodgerblue": "#1e90ff",
  "firebrick": "#b22222",
  "floralwhite": "#fffaf0",
  "forestgreen": "#228b22",
  "fuchsia": "#ff00ff",
  "gainsboro": "#dcdcdc",
  "ghostwhite": "#f8f8ff",
  "gold": "#ffd700",
  "goldenrod": "#daa520",
  "gray": "#808080",
  "green": "#008000",
  "greenyellow": "#adff2f",
  "grey": "#808080",
  "honeydew": "#f0fff0",
  "hotpink": "#ff69b4",
  "indianred": "#cd5c5c",
  "indigo": "#4b0082",
  "ivory": "#fffff0",
  "khaki": "#f0e68c",
  "lavender": "#e6e6fa",
  "lavenderblush": "#fff0f5",
  "lawngreen": "#7cfc00",
  "lemonchiffon": "#fffacd",
  "lightblue": "#add8e6",
  "lightcoral": "#f08080",
  "lightcyan": "#e0ffff",
  "lightgoldenrodyellow": "#fafad2",
  "lightgray": "#d3d3d3",
  "lightgreen": "#90ee90",
  "lightgrey": "#d3d3d3",
  "lightpink": "#ffb6c1",
  "lightsalmon": "#ffa07a",
  "lightseagreen": "#20b2aa",
  "lightskyblue": "#87cefa",
  "lightslategray": "#778899",
  "lightslategrey": "#778899",
  "lightsteelblue": "#b0c4de",
  "lightyellow": "#ffffe0",
  "lime": "#00ff00",
  "limegreen": "#32cd32",
  "linen": "#faf0e6",
  "magenta": "#ff00ff",
  "maroon": "#800000",
  "mediumaquamarine": "#66cdaa",
  "mediumblue": "#0000cd",
  "mediumorchid": "#ba55d3",
  "mediumpurple": "#9370db",
  "mediumseagreen": "#3cb371",
  "mediumslateblue": "#7b68ee",
  "mediumspringgreen": "#00fa9a",
  "mediumturquoise": "#48d1cc",
  "mediumvioletred": "#c71585",
  "midnightblue": "#191970",
  "mintcream": "#f5fffa",
  "mistyrose": "#ffe4e1",
  "moccasin": "#ffe4b5",
  "navajowhite": "#ffdead",
  "navy": "#000080",
  "oldlace": "#fdf5e6",
  "olive": "#808000",
  "olivedrab": "#6b8e23",
  "orange": "#ffa500",
  "orangered": "#ff4500",
  "orchid": "#da70d6",
  "palegoldenrod": "#eee8aa",
  "palegreen": "#98fb98",
  "paleturquoise": "#afeeee",
  "palevioletred": "#db7093",
  "papayawhip": "#ffefd5",
  "peachpuff": "#ffdab9",
  "peru": "#cd853f",
  "pink": "#ffc0cb",
  "plum": "#dda0dd",
  "powderblue": "#b0e0e6",
  "purple": "#800080",
  "rebeccapurple": "#663399",
  "red": "#ff0000",
  "rosybrown": "#bc8f8f",
  "royalblue": "#4169e1",
  "saddlebrown": "#8b4513",
  "salmon": "#fa8072",
  "sandybrown": "#f4a460",
  "seagreen": "#2e8b57",
  "seashell": "#fff5ee",
  "sienna": "#a0522d",
  "silver": "#c0c0c0",
  "skyblue": "#87ceeb",
  "slateblue": "#6a5acd",
  "slategray": "#708090",
  "slategrey": "#708090",
  "snow": "#fffafa",
  "springgreen": "#00ff7f",
  "steelblue": "#4682b4",
  "tan": "#d2b48c",
  "teal": "#008080",
  "thistle": "#d8bfd8",
  "tomato": "#ff6347",
  "turquoise": "#40e0d0",
  "violet": "#ee82ee",
  "wheat": "#f5deb3",
  "white": "#ffffff",
  "whitesmoke": "#f5f5f5",
  "yellow": "#ffff00",
  "yellowgreen": "#9acd32",
}

///|
/// Reverse map for the names that are shorter than their hex form.
let hex_to_name : Map[String, String] = {
  "#f00": "red",
  "#d2b48c": "tan",
  "#ff0000": "red",
  "#000080": "navy",
  "#808080": "gray",
  "#800000": "maroon",
  "#a52a2a": "brown",
  "#ffd700": "gold",
  "#dda0dd": "plum",
  "#cd853f": "peru",
  "#008080": "teal",
  "#ffa500": "orange",
  "#808000": "olive",
  "#800080": "purple",
  "#fffafa": "snow",
  "#ffc0cb": "pink",
  "#f0e68c": "khaki",
  "#a0522d": "sienna",
  "#4b0082": "indigo",
  "#ff7f50": "coral",
  "#ff6347": "tomato",
  "#fa8072": "salmon",
  "#faf0e6": "linen",
  "#c0c0c0": "silver",
  "#f5f5dc": "beige",
  "#ffe4c4": "bisque",
  "#f5deb3": "wheat",
  "#f0ffff": "azure",
  "#fffff0": "ivory",
  "#ee82ee": "violet",
  "#da70d6": "orchid",
}
