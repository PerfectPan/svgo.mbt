///|
/// Like `parse`, but keeps the segments read before the first error instead
/// of failing: browsers and svgo render a path up to its first invalid token.
/// With `until_drawing`, parsing also stops after the first segment that
/// draws something (see `is_drawing_command`), which is all a caller needs to
/// tell an empty or single-point path from a visible one without reading the
/// whole string.
fn parse_prefix(d : String, until_drawing? : Bool = false) -> Array[Segment] {
  let out : Array[Segment] = []
  parse_into(out, d, until_drawing~) catch {
    _ => ()
  }
  out
}

///|
fn parse_into(
  out : Array[Segment],
  d : String,
  until_drawing? : Bool = false,
) -> Unit raise PathError {
  let cu = d.code_units()
  let n = cu.length()
  let mut i = 0
  let mut cmd : Char = ' '
  fn skip(i : Int) -> Int {
    let mut i = i
    while i < n &&
          (
            cu[i] == 32 ||
            cu[i] == 9 ||
            cu[i] == 10 ||
            cu[i] == 13 ||
            cu[i] == 44
          ) {
      i += 1
    }
    i
  }
  i = skip(i)
  while i < n {
    let c = cu[i].to_int().unsafe_to_char()
    let count = arg_count(c)
    if count >= 0 {
      cmd = c
      i = skip(i + 1)
      if count == 0 {
        out.push({ cmd, args: [], })
        continue
      }
    } else {
      guard cmd != ' ' else {
        raise PathError("path must start with a command")
      }
      // implicit repetition: after M comes L, after m comes l
      if cmd == 'M' {
        cmd = 'L'
      } else if cmd == 'm' {
        cmd = 'l'
      }
      guard arg_count(cmd) > 0 else {
        raise PathError("unexpected number after '\{cmd}'")
      }
    }
    let count = arg_count(cmd)
    let args : Array[Double] = []
    for k in 0..<count {
      i = skip(i)
      let is_flag = cmd.to_ascii_lowercase() == 'a' && (k == 3 || k == 4)
      if is_flag {
        // arc flags are single digits that may be glued together: "10" is two flags
        guard i < n && (cu[i] == 48 || cu[i] == 49) else {
          raise PathError("expected arc flag at \{i}")
        }
        args.push((cu[i].to_int() - 48).to_double())
        i = skip(i + 1)
      } else {
        let (v, ni) = @num.scan_number(cu, i) catch {
          NumError(msg) => raise PathError(msg)
        }
        args.push(v)
        i = skip(ni)
      }
    }
    out.push({ cmd, args, })
    if until_drawing && is_drawing_command(cmd) {
      return
    }
  }
}

///|
/// Append the path data for `segments` to `sb`.
fn write_path(
  sb : StringBuilder,
  segments : Array[Segment],
  precision : Int,
) -> Unit {
  // The leading moveto is always from the origin, so its absolute/relative
  // form is interchangeable. Match its case to the following lineto so the
  // pair can share an implicit command letter (`M x y L` → `M x y `,
  // `M x y l` → `m x y `).
  let first_cmd = if segments.length() >= 2 {
    match (segments[0].cmd, segments[1].cmd) {
      ('M', 'l') => 'm'
      ('m', 'L') => 'M'
      (c, _) => c
    }
  } else if segments.length() == 1 {
    segments[0].cmd
  } else {
    ' '
  }
  let mut prev_cmd : Char = ' '
  // shape of the last number written in the current command, 0 right after
  // a command letter
  let mut prev_shape = 0
  let mut prev_was_flag = false
  for i, seg in segments {
    let cmd = if i == 0 { first_cmd } else { seg.cmd }
    // implicit repetition saves the command letter; `M x y L` pairs use it too
    let implicit = (
        cmd == prev_cmd && cmd != 'M' && cmd != 'm' && cmd != 'z' && cmd != 'Z'
      ) ||
      (prev_cmd == 'M' && cmd == 'L') ||
      (prev_cmd == 'm' && cmd == 'l')
    if !implicit {
      sb.write_char(cmd)
      prev_shape = 0
      prev_was_flag = false
    }
    let is_arc = cmd == 'a' || cmd == 'A'
    for k, a in seg.args {
      let is_flag = is_arc && (k == 3 || k == 4)
      if is_flag {
        // arc flags are always separated: gluing them is valid but trips up
        // older renderers
        if prev_shape != 0 {
          sb.write_char(' ')
        }
        sb.write_char(if a != 0.0 { '1' } else { '0' })
        prev_shape = 1 << 3
        prev_was_flag = true
        continue
      }
      if prev_shape != 0 {
        // a separator is needed unless the number starts with '-', or starts
        // with '.' after a number that already has a '.'
        let (neg, int_part, frac, _) = @num.decompose(a, precision)
        let nonzero = int_part != 0 || frac != 0
        let starts_neg = nonzero && neg
        let starts_dot = nonzero &&
          !neg &&
          int_part == 0 &&
          (prev_shape & 4) != 0 &&
          !prev_was_flag
        if !(starts_neg || starts_dot) {
          sb.write_char(' ')
        }
      }
      prev_shape = @num.write_number_shaped(sb, a, precision)
      prev_was_flag = false
    }
    prev_cmd = cmd
  }
}

///|
/// Length of `stringify([seg])`: the command letter plus its arguments with
/// the same separator rules as `stringify`.
fn segment_len(seg : Segment, precision : Int) -> Int {
  let mut len = 1
  let is_arc = seg.cmd == 'a' || seg.cmd == 'A'
  let mut prev_has_dot = false
  let mut prev_was_flag = false
  let mut first = true
  for k, a in seg.args {
    let is_flag = is_arc && (k == 3 || k == 4)
    if is_flag {
      if !first {
        len += 1
      }
      len += 1
      prev_has_dot = false
      prev_was_flag = true
    } else {
      let shape = @num.number_shape(a, precision)
      let starts_neg = (shape & 1) != 0
      let starts_dot = (shape & 2) != 0 && prev_has_dot && !prev_was_flag
      if !first && !(starts_neg || starts_dot) {
        len += 1
      }
      len += shape >> 3
      prev_has_dot = (shape & 4) != 0
      prev_was_flag = false
    }
    first = false
  }
  len
}

///|
/// Apply a 6-element affine matrix [a, b, c, d, e, f] to path data, returning
/// new segments. Absolute points are transformed as (a*x + c*y + e,
/// b*x + d*y + f); relative deltas as (a*dx + c*dy, b*dx + d*dy). `H`/`V` are
/// widened to `L` because a non-axis-aligned transform changes both
/// coordinates. Arcs have their radii, rotation and sweep flag adjusted.
pub fn apply_matrix(
  segments : Array[Segment],
  m : Array[Double],
) -> Array[Segment] {
  let a = m[0]
  let b = m[1]
  let c = m[2]
  let d = m[3]
  let e = m[4]
  let f = m[5]
  let out : Array[Segment] = []
  // transformed current point and subpath start
  let mut cx = 0.0
  let mut cy = 0.0
  let mut sx = 0.0
  let mut sy = 0.0
  // original (untransformed) current point, needed for H/V which reference
  // the current coordinate in the pre-transform space
  let mut ocx = 0.0
  let mut ocy = 0.0
  let mut osx = 0.0
  let mut osy = 0.0
  // the first moveto in a path is always absolute, even when written as 'm'
  let mut first = true
  fn abs_pt(x : Double, y : Double) -> (Double, Double) {
    let nx = a * x + c * y + e
    let ny = b * x + d * y + f
    (nx, ny)
  }
  fn rel_pt(x : Double, y : Double) -> (Double, Double) {
    let nx = a * x + c * y
    let ny = b * x + d * y
    (nx, ny)
  }
  for seg in segments {
    let args = seg.args
    let upper = seg.cmd.to_ascii_uppercase()
    match upper {
      'M' | 'L' | 'C' | 'S' | 'Q' | 'T' => {
        // every argument is a coordinate pair; the first moveto is absolute
        // per the SVG spec even when written as `m`
        let rel = seg.cmd.is_ascii_lowercase() && !first
        let n = args.length()
        let out_args : Array[Double] = []
        let mut i = 0
        while i < n {
          let (x, y) = if rel {
            rel_pt(args[i], args[i + 1])
          } else {
            abs_pt(args[i], args[i + 1])
          }
          out_args.push(x)
          out_args.push(y)
          i += 2
        }
        if rel {
          cx = cx + out_args[n - 2]
          cy = cy + out_args[n - 1]
          ocx = ocx + args[n - 2]
          ocy = ocy + args[n - 1]
        } else {
          cx = out_args[n - 2]
          cy = out_args[n - 1]
          ocx = args[n - 2]
          ocy = args[n - 1]
        }
        if upper == 'M' {
          sx = cx
          sy = cy
          osx = ocx
          osy = ocy
        }
        out.push({ cmd: if rel { seg.cmd } else { upper }, args: out_args, })
      }
      'H' if seg.cmd == 'H' => {
        let (x, y) = abs_pt(args[0], ocy)
        cx = x
        cy = y
        ocx = args[0]
        out.push({ cmd: 'L', args: [x, y], })
      }
      'H' => {
        let (dx, dy) = rel_pt(args[0], 0.0)
        cx = cx + dx
        cy = cy + dy
        ocx = ocx + args[0]
        out.push({ cmd: 'l', args: [dx, dy], })
      }
      'V' if seg.cmd == 'V' => {
        let (x, y) = abs_pt(ocx, args[0])
        cx = x
        cy = y
        ocy = args[0]
        out.push({ cmd: 'L', args: [x, y], })
      }
      'V' => {
        let (dx, dy) = rel_pt(0.0, args[0])
        cx = cx + dx
        cy = cy + dy
        ocy = ocy + args[0]
        out.push({ cmd: 'l', args: [dx, dy], })
      }
      'A' if seg.cmd == 'A' => {
        let na = transform_arc(ocx, ocy, args, m, true)
        cx = na[5]
        cy = na[6]
        ocx = args[5]
        ocy = args[6]
        out.push({ cmd: 'A', args: na, })
      }
      'A' => {
        let na = transform_arc(0.0, 0.0, args, m, false)
        cx = cx + na[5]
        cy = cy + na[6]
        ocx = ocx + args[5]
        ocy = ocy + args[6]
        out.push({ cmd: 'a', args: na, })
      }
      'Z' => {
        cx = sx
        cy = sy
        ocx = osx
        ocy = osy
        out.push({ cmd: seg.cmd, args: [], })
      }
      _ => out.push(seg)
    }
    first = false
  }
  out
}

///|
/// Transform an elliptical arc's parameters (rx, ry, x-axis-rotation,
/// large-arc-flag, sweep-flag, x, y) by an affine matrix. The radii are
/// scaled, the rotation is adjusted (and normalized to |rot| ≤ 80 by swapping
/// rx/ry), and the sweep flag is flipped when the determinant is negative.
/// The endpoint (x, y) is transformed by the full matrix when `absolute` is
/// true, or by the linear part only when false. Mirrors svgo's `transformArc`.
fn transform_arc(
  cursor_x : Double,
  cursor_y : Double,
  arc : Array[Double],
  m : Array[Double],
  absolute : Bool,
) -> Array[Double] {
  let a = m[0]
  let b = m[1]
  let c = m[2]
  let d = m[3]
  let e = m[4]
  let f = m[5]
  let x = arc[5] - cursor_x
  let y = arc[6] - cursor_y
  let mut rx = arc[0]
  let mut ry = arc[1]
  let rot = arc[2] * @math.PI / 180.0
  let cos = @num.cos(rot)
  let sin = @num.sin(rot)
  if rx > 0.0 && ry > 0.0 {
    let mut h = (x * cos + y * sin) * (x * cos + y * sin) / (4.0 * rx * rx) +
      (y * cos - x * sin) * (y * cos - x * sin) / (4.0 * ry * ry)
    if h > 1.0 {
      h = h.sqrt()
      rx = rx * h
      ry = ry * h
    }
  }
  // ellipse matrix [rx*cos, rx*sin, -ry*sin, ry*cos, 0, 0]
  let e0 = rx * cos
  let e1 = rx * sin
  let e2 = -ry * sin
  let e3 = ry * cos
  // multiply m * ellipse
  let m0 = a * e0 + c * e1
  let m1 = b * e0 + d * e1
  let m2 = a * e2 + c * e3
  let m3 = b * e2 + d * e3
  let last_col = m2 * m2 + m3 * m3
  let square_sum = m0 * m0 + m1 * m1 + last_col
  let root = @math.hypot(m0 - m3, m1 + m2) * @math.hypot(m0 + m3, m1 - m2)
  let (nrx0, nry0, nrot0) = if root == 0.0 {
    let r = (square_sum / 2.0).sqrt()
    (r, r, 0.0)
  } else {
    let major_sqr = (square_sum + root) / 2.0
    let minor_sqr = (square_sum - root) / 2.0
    let major = (major_sqr - last_col).abs() > 0.000001
    let sub = (if major { major_sqr } else { minor_sqr }) - last_col
    let rows_sum = m0 * m2 + m1 * m3
    let term1 = m0 * sub + m2 * rows_sum
    let term2 = m1 * sub + m3 * rows_sum
    let nrx = major_sqr.sqrt()
    let nry = minor_sqr.sqrt()
    let value = if major { term1 } else { term2 }
    let sign = if major { term2 < 0.0 } else { term1 > 0.0 }
    let angle = (if sign { -1.0 } else { 1.0 }) *
      @num.acos(value / @math.hypot(term1, term2)) *
      180.0 /
      @math.PI
    (nrx, nry, angle)
  }
  let mut nrx = nrx0
  let mut nry = nry0
  let mut nrot = nrot0
  // reduce the rotation angle to [-80, 80] by swapping the radii and
  // shifting the angle by 90°; an ellipse is invariant under this.
  if nrot.abs() > 80.0 {
    let tmp = nrx
    nrx = nry
    nry = tmp
    nrot = nrot + (if nrot > 0.0 { -90.0 } else { 90.0 })
  }
  let mut sweep = arc[4]
  if (a < 0.0) != (d < 0.0) {
    sweep = 1.0 - sweep
  }
  // transform the endpoint
  let nx = a * arc[5] + c * arc[6] + (if absolute { e } else { 0.0 })
  let ny = b * arc[5] + d * arc[6] + (if absolute { f } else { 0.0 })
  [nrx, nry, nrot, arc[3], sweep, nx, ny]
}

///|
/// True when the path draws anything: a drawing command after the first move.
/// Parsing stops at the first error, just like browsers render a path up to
/// its first invalid token, so a malformed tail does not hide visible geometry.
pub fn has_geometry(d : String) -> Bool {
  let segs = parse_prefix(d, until_drawing=true)
  segs.iter().any(s => is_drawing_command(s.cmd))
}
