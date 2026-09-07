///|
priv struct Tf {
  name : String
  args : Array[Double]
}

///|
/// Split a transform argument string into number tokens, handling SVG's
/// permissive syntax where a sign can act as a separator (e.g. "1-1" → ["1", "-1"]
/// and ".707-.707" → [".707", "-.707"]).
fn split_numbers(s : String) -> Array[String] {
  let out : Array[String] = []
  let mut cur = ""
  let mut has_dot = false
  for c in s {
    let is_sign = c == '-' || c == '+'
    let is_dot = c == '.'
    let is_sep = c == ' ' || c == ',' || c == '\t' || c == '\n' || c == '\r'
    if is_sep {
      if !cur.is_empty() {
        out.push(cur)
        cur = ""
        has_dot = false
      }
    } else if is_sign && !cur.is_empty() {
      // a sign after an existing number starts a new number
      out.push(cur)
      cur = c.to_string()
      has_dot = false
    } else if is_dot && has_dot {
      // a second dot starts a new number
      out.push(cur)
      cur = "."
      has_dot = true
    } else {
      if is_dot {
        has_dot = true
      }
      cur = cur + c.to_string()
    }
  }
  if !cur.is_empty() {
    out.push(cur)
  }
  out
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
    for tok in split_numbers(inner) {
      if tok.is_empty() {
        continue
      }
      match split_unit(tok) {
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
/// Convert a single transform to its 6-element matrix [a, b, c, d, e, f].
fn transform_to_matrix(t : Tf) -> Array[Double] {
  match t.name {
    "matrix" => t.args.copy()
    "translate" => {
      let tx = t.args[0]
      let ty = if t.args.length() > 1 { t.args[1] } else { 0.0 }
      [1.0, 0.0, 0.0, 1.0, tx, ty]
    }
    "scale" => {
      let sx = t.args[0]
      let sy = if t.args.length() > 1 { t.args[1] } else { sx }
      [sx, 0.0, 0.0, sy, 0.0, 0.0]
    }
    "rotate" => {
      let a = t.args[0]
      let cx = if t.args.length() > 1 { t.args[1] } else { 0.0 }
      let cy = if t.args.length() > 2 { t.args[2] } else { 0.0 }
      let rad = a * @math.PI / 180.0
      let cos = @math.cos(rad)
      let sin = @math.sin(rad)
      [
        cos,
        sin,
        -sin,
        cos,
        (1.0 - cos) * cx + sin * cy,
        (1.0 - cos) * cy - sin * cx,
      ]
    }
    "skewX" => {
      let rad = t.args[0] * @math.PI / 180.0
      [1.0, 0.0, @math.tan(rad), 1.0, 0.0, 0.0]
    }
    "skewY" => {
      let rad = t.args[0] * @math.PI / 180.0
      [1.0, @math.tan(rad), 0.0, 1.0, 0.0, 0.0]
    }
    _ => [1.0, 0.0, 0.0, 1.0, 0.0, 0.0]
  }
}

///|
/// Multiply two 6-element matrices: a * b (applies b first, then a).
fn multiply_matrices(a : Array[Double], b : Array[Double]) -> Array[Double] {
  [
    a[0] * b[0] + a[2] * b[1],
    a[1] * b[0] + a[3] * b[1],
    a[0] * b[2] + a[2] * b[3],
    a[1] * b[2] + a[3] * b[3],
    a[0] * b[4] + a[2] * b[5] + a[4],
    a[1] * b[4] + a[3] * b[5] + a[5],
  ]
}

///|
/// Multiply a list of transforms into a single matrix transform.
fn transforms_multiply(ts : Array[Tf]) -> Tf {
  let mut m = [1.0, 0.0, 0.0, 1.0, 0.0, 0.0]
  for t in ts {
    m = multiply_matrices(m, transform_to_matrix(t))
  }
  { name: "matrix", args: m, }
}

///|
/// Number of digits after the decimal point.
fn float_digits(v : Double) -> Int {
  let s = v.to_string()
  match s.find(".") {
    Some(i) => s.length() - i - 1
    None => 0
  }
}

///|
/// Total number of digits in a number (ignoring sign and decimal point).
fn total_digits(v : Double) -> Int {
  let s = v.to_string()
  let mut n = 0
  for c in s {
    if c >= '0' && c <= '9' {
      n += 1
    }
  }
  n
}

///|
/// Compute (floatPrecision, transformPrecision, degPrecision) from the
/// transform list and the base float precision.
fn define_precision(ts : Array[Tf], float_prec : Int) -> (Int, Int, Int) {
  let transform_prec_default = 5
  let matrix_vals : Array[Double] = []
  for t in ts {
    if t.name == "matrix" && t.args.length() >= 4 {
      for i in 0..<4 {
        matrix_vals.push(t.args[i])
      }
    }
  }
  let mut transform_prec = transform_prec_default
  let mut num_digits = transform_prec_default
  if !matrix_vals.is_empty() {
    let mut max_float = 0
    let mut max_total = 0
    for v in matrix_vals {
      let fd = float_digits(v)
      if fd > max_float {
        max_float = fd
      }
      let td = total_digits(v)
      if td > max_total {
        max_total = td
      }
    }
    transform_prec = if max_float < transform_prec {
      max_float
    } else {
      transform_prec
    }
    num_digits = max_total
  }
  let deg_prec = {
    let v = if float_prec < num_digits - 2 {
      float_prec
    } else {
      num_digits - 2
    }
    if v > 0 {
      v
    } else {
      0
    }
  }
  (float_prec, transform_prec, deg_prec)
}

///|
/// Round a transform's arguments according to its type.
fn round_transform(
  t : Tf,
  float_prec : Int,
  transform_prec : Int,
  deg_prec : Int,
) -> Tf {
  let args : Array[Double] = match t.name {
    "translate" => t.args.map(a => @path.strong_round(a, float_prec))
    "rotate" => {
      let out : Array[Double] = []
      for i, a in t.args {
        if i == 0 {
          out.push(@path.strong_round(a, deg_prec))
        } else {
          out.push(@path.strong_round(a, float_prec))
        }
      }
      out
    }
    "skewX" => t.args.map(a => @path.strong_round(a, deg_prec))
    "skewY" => t.args.map(a => @path.strong_round(a, deg_prec))
    "scale" => t.args.map(a => @path.strong_round(a, transform_prec))
    "matrix" => {
      let out : Array[Double] = []
      for i, a in t.args {
        if i < 4 {
          out.push(@path.strong_round(a, transform_prec))
        } else {
          out.push(@path.strong_round(a, float_prec))
        }
      }
      out
    }
    _ => t.args.copy()
  }
  { name: t.name, args, }
}

///|
/// Decompose a matrix [a,b,c,d,e,f] into translate, rotate, scale, skewX.
fn decompose_qr_ab(m : Array[Double]) -> Array[Tf]? {
  let a = m[0]
  let b = m[1]
  let c = m[2]
  let d = m[3]
  let e = m[4]
  let f = m[5]
  let delta = a * d - b * c
  if delta == 0.0 {
    return None
  }
  let r = @math.hypot(a, b)
  if r == 0.0 {
    return None
  }
  let out : Array[Tf] = []
  if e != 0.0 || f != 0.0 {
    out.push({ name: "translate", args: [e, f], })
  }
  let cos_angle = a / r
  if cos_angle != 1.0 {
    let rad = @math.acos(cos_angle)
    let deg = rad * 180.0 / @math.PI
    let angle = if b < 0.0 { -deg } else { deg }
    out.push({ name: "rotate", args: [angle, 0.0, 0.0], })
  }
  let sx = r
  let sy = delta / sx
  if sx != 1.0 || sy != 1.0 {
    out.push({ name: "scale", args: [sx, sy], })
  }
  let ac_plus_bd = a * c + b * d
  if ac_plus_bd != 0.0 {
    let angle = @math.atan(ac_plus_bd / (a * a + b * b)) * 180.0 / @math.PI
    out.push({ name: "skewX", args: [angle], })
  }
  Some(out)
}

///|
/// Decompose a matrix [a,b,c,d,e,f] into translate, rotate, scale, skewY.
fn decompose_qr_cd(m : Array[Double]) -> Array[Tf]? {
  let a = m[0]
  let b = m[1]
  let c = m[2]
  let d = m[3]
  let e = m[4]
  let f = m[5]
  let delta = a * d - b * c
  if delta == 0.0 {
    return None
  }
  let s = @math.hypot(c, d)
  if s == 0.0 {
    return None
  }
  let out : Array[Tf] = []
  if e != 0.0 || f != 0.0 {
    out.push({ name: "translate", args: [e, f], })
  }
  let sign = if d < 0.0 { -1.0 } else { 1.0 }
  let rad = @math.PI / 2.0 - sign * @math.acos(-c / s)
  let angle = rad * 180.0 / @math.PI
  out.push({ name: "rotate", args: [angle, 0.0, 0.0], })
  let sx = delta / s
  let sy = s
  if sx != 1.0 || sy != 1.0 {
    out.push({ name: "scale", args: [sx, sy], })
  }
  let ac_plus_bd = a * c + b * d
  if ac_plus_bd != 0.0 {
    let angle = @math.atan(ac_plus_bd / (c * c + d * d)) * 180.0 / @math.PI
    out.push({ name: "skewY", args: [angle], })
  }
  Some(out)
}

///|
/// Check if a rounded transform is an identity.
fn is_identity_transform(t : Tf) -> Bool {
  match t.name {
    "rotate" | "skewX" | "skewY" => t.args.length() > 0 && t.args[0] == 0.0
    "scale" => t.args[0] == 1.0 && (t.args.length() < 2 || t.args[1] == 1.0)
    "translate" => t.args[0] == 0.0 && (t.args.length() < 2 || t.args[1] == 0.0)
    _ => false
  }
}

///|
/// Merge translate(tx, ty) rotate(a) into rotate(a, cx, cy).
fn merge_translate_and_rotate(tx : Double, ty : Double, a : Double) -> Tf {
  let rad = a * @math.PI / 180.0
  let d = 1.0 - @math.cos(rad)
  let e = @math.sin(rad)
  let cy = (d * ty + e * tx) / (d * d + e * e)
  let cx = (tx - e * cy) / d
  { name: "rotate", args: [a, cx, cy], }
}

///|
/// Optimize a list of rounded transforms: drop identities, fold rotate(180)
/// into scale, merge translate+rotate into rotate with centre.
fn optimize_list(rounded : Array[Tf], raw : Array[Tf]) -> Array[Tf] {
  let out : Array[Tf] = []
  let mut i = 0
  while i < rounded.length() {
    let t = rounded[i]
    if is_identity_transform(t) {
      i += 1
      continue
    }
    match t.name {
      "rotate" => {
        let a = t.args[0]
        if a == 180.0 || a == -180.0 {
          if i + 1 < rounded.length() && rounded[i + 1].name == "scale" {
            let next = rounded[i + 1]
            let neg = next.args.map(v => -v)
            if neg.length() >= 2 && neg[0] == neg[1] {
              out.push({ name: "scale", args: [neg[0]], })
            } else {
              out.push({ name: "scale", args: neg, })
            }
            i += 2
          } else {
            out.push({ name: "scale", args: [-1.0], })
            i += 1
          }
        } else {
          let has_centre = t.args.length() > 1 &&
            (t.args[1] != 0.0 || (t.args.length() > 2 && t.args[2] != 0.0))
          if has_centre {
            out.push({
              name: "rotate",
              args: [t.args[0], t.args[1], t.args[2]],
            })
          } else {
            out.push({ name: "rotate", args: [t.args[0]], })
          }
          i += 1
        }
      }
      "scale" => {
        if t.args.length() >= 2 && t.args[0] == t.args[1] {
          out.push({ name: "scale", args: [t.args[0]], })
        } else {
          out.push(t)
        }
        i += 1
      }
      "skewX" | "skewY" => {
        out.push({ name: t.name, args: [t.args[0]], })
        i += 1
      }
      "translate" => {
        let next = if i + 1 < rounded.length() {
          rounded[i + 1]
        } else {
          { name: "", args: [], }
        }
        if next.name == "rotate" &&
          next.args[0] != 0.0 &&
          next.args[0] != 180.0 &&
          next.args[0] != -180.0 &&
          next.args.length() > 2 &&
          next.args[1] == 0.0 &&
          next.args[2] == 0.0 {
          let raw_t = raw[i]
          let raw_r = raw[i + 1]
          let merged = merge_translate_and_rotate(
            raw_t.args[0],
            if raw_t.args.length() > 1 {
              raw_t.args[1]
            } else {
              0.0
            },
            raw_r.args[0],
          )
          out.push(merged)
          i += 2
        } else {
          if t.args.length() > 1 && t.args[1] == 0.0 {
            out.push({ name: "translate", args: [t.args[0]], })
          } else {
            out.push(t)
          }
          i += 1
        }
      }
      _ => {
        out.push(t)
        i += 1
      }
    }
  }
  if out.is_empty() {
    out.push({ name: "scale", args: [1.0], })
  }
  out
}

///|
/// Decompose a matrix transform into the shortest equivalent list of simple
/// transforms, or return the original matrix if no shorter form is found.
fn matrix_to_transform(
  matrix : Tf,
  float_prec : Int,
  transform_prec : Int,
  deg_prec : Int,
) -> Array[Tf] {
  let m = matrix.args
  let decompositions : Array[Array[Tf]] = []
  match decompose_qr_ab(m) {
    Some(d) => decompositions.push(d)
    None => ()
  }
  match decompose_qr_cd(m) {
    Some(d) => decompositions.push(d)
    None => ()
  }
  if decompositions.is_empty() {
    return [matrix]
  }
  // Find the shortest decomposition (strictly shorter wins; first one wins ties).
  let mut best : Array[Tf] = []
  let mut best_len = 1000000
  for dec in decompositions {
    let rounded = dec.map(t => {
      round_transform(t, float_prec, transform_prec, deg_prec)
    })
    let opt = optimize_list(rounded, dec)
    let len = transforms_string_len(opt, float_prec, transform_prec, deg_prec)
    if len < best_len {
      best = opt
      best_len = len
    }
  }
  // Use the decomposition only if it is at most as long as the original matrix.
  let matrix_len = transforms_string_len(
    [matrix],
    float_prec,
    transform_prec,
    deg_prec,
  )
  if best_len <= matrix_len {
    best
  } else {
    [matrix]
  }
}

///|
/// Compute the length of the string representation of a transform list
/// (without actually building it), used to pick the shortest decomposition.
fn transforms_string_len(
  ts : Array[Tf],
  float_prec : Int,
  transform_prec : Int,
  deg_prec : Int,
) -> Int {
  let mut len = 0
  for t in ts {
    len += t.name.length() + 2 // name + "()"
    for i, a in t.args {
      if i > 0 {
        len += 1 // space separator
      }
      let prec = match t.name {
        "translate" => float_prec
        "rotate" => if i == 0 { deg_prec } else { float_prec }
        "skewX" => deg_prec
        "skewY" => deg_prec
        "scale" => transform_prec
        "matrix" => if i < 4 { transform_prec } else { float_prec }
        _ => float_prec
      }
      len += @path.format_number(a, prec).length()
    }
  }
  len
}

///|
/// Format a single transform's arguments as a string.
fn format_args(
  t : Tf,
  float_prec : Int,
  transform_prec : Int,
  deg_prec : Int,
) -> String {
  let sb = StringBuilder()
  for i, a in t.args {
    if i > 0 {
      sb.write_char(' ')
    }
    let prec = match t.name {
      "translate" => float_prec
      "rotate" => if i == 0 { deg_prec } else { float_prec }
      "skewX" => deg_prec
      "skewY" => deg_prec
      "scale" => transform_prec
      "matrix" => if i < 4 { transform_prec } else { float_prec }
      _ => float_prec
    }
    sb.write_string(@path.format_number(a, prec))
  }
  sb.to_string()
}

///|
/// Convert a list of transforms to their string representation.
fn transforms_to_string(
  ts : Array[Tf],
  float_prec : Int,
  transform_prec : Int,
  deg_prec : Int,
) -> String {
  let sb = StringBuilder()
  for t in ts {
    sb.write_string(t.name)
    sb.write_char('(')
    sb.write_string(format_args(t, float_prec, transform_prec, deg_prec))
    sb.write_char(')')
  }
  sb.to_string()
}

///|
/// Remove identity transforms from a list.
fn remove_useless(ts : Array[Tf]) -> Array[Tf] {
  ts.filter(t => !is_identity_transform(t))
}

///|
/// Collapse multiple transforms into one matrix, decompose to the shortest
/// equivalent, apply shorts and remove identities.
pub let convert_transform : Plugin = {
  name: "convertTransform",
  description: "simplify transform lists",
  run: (doc, ctx) => {
    let mut changed = false
    let float_prec = ctx.precision
    doc.each_element((e, _) => {
      for attr in ["transform", "gradientTransform", "patternTransform"] {
        guard e.attrs.get(attr) is Some(v) else { continue }
        let list = match parse_transform(v) {
          Some(l) => l
          None => {
            // malformed transform: remove the attribute (svgo does the same)
            e.attrs.remove(attr)
            changed = true
            continue
          }
        }
        if list.is_empty() {
          e.attrs.remove(attr)
          changed = true
          continue
        }
        let (fp, tp, dp) = define_precision(list, float_prec)
        // collapse into one matrix
        let data = if list.length() > 1 {
          [transforms_multiply(list)]
        } else {
          list.copy()
        }
        // convert matrices to shorts
        let converted : Array[Tf] = []
        for t in data {
          if t.name == "matrix" {
            let dec = matrix_to_transform(t, fp, tp, dp)
            for d in dec {
              converted.push(d)
            }
          } else {
            converted.push(t)
          }
        }
        // round
        let rounded = converted.map(t => round_transform(t, fp, tp, dp))
        // shorts: translate(x 0) -> translate(x), scale(s s) -> scale(s)
        let shorted : Array[Tf] = []
        for t in rounded {
          match (t.name, t.args) {
            ("translate", [x, y]) if y == 0.0 =>
              shorted.push({ name: "translate", args: [x], })
            ("scale", [s1, s2]) if s1 == s2 =>
              shorted.push({ name: "scale", args: [s1], })
            ("rotate", [a, cx, cy]) if cx == 0.0 && cy == 0.0 =>
              shorted.push({ name: "rotate", args: [a], })
            _ => shorted.push(t)
          }
        }
        // remove useless
        let useful = remove_useless(shorted)
        let out = if useful.is_empty() {
          ""
        } else {
          transforms_to_string(useful, fp, tp, dp)
        }
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
