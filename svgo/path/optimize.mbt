///|
/// Knobs of the path optimizer; every field defaults to on except that
/// `precision` is 3. Disable individual rewrites when a consumer depends on
/// the exact segment structure (for example markers or animations).
pub(all) struct Options {
  /// decimal places kept for coordinates
  precision : Int
  /// choose between absolute and relative form per segment by length
  utilize_absolute : Bool
  /// drop zero-length segments and `L` back to the subpath start before `Z`
  remove_useless : Bool
  /// turn curves whose control points lie on the chord into lines
  straight_curves : Bool
  /// convert a cubic bezier to a quadratic when its control points match
  convert_to_q : Bool
  /// use `S`/`T` when a control point mirrors the previous one
  smooth_shorthands : Bool
  /// merge consecutive `m`/`h`/`v` commands that share a direction
  collapse_repeated : Bool
  /// replace a line back to the subpath start with `z`
  convert_to_z : Bool
  /// stroke-linecap value; "round"/"square" keep zero-length segments as `h0`
  linecap : String
  /// stroke-linejoin value; together with linecap decides if `z` is removable
  linejoin : String
  /// whether the element has a visible stroke (not "none")
  has_stroke : Bool
} derive(Debug)

///|
/// Precision 3 with every rewrite enabled.
pub fn Options::default() -> Options {
  {
    precision: 3,
    utilize_absolute: true,
    remove_useless: true,
    straight_curves: true,
    convert_to_q: true,
    smooth_shorthands: true,
    collapse_repeated: true,
    convert_to_z: true,
    linecap: "butt",
    linejoin: "miter",
    has_stroke: false,
  }
}

///|
/// A segment in absolute coordinates plus its end point.
priv struct Abs {
  cmd : Char
  args : Array[Double]
  ex : Double
  ey : Double
}

///|
fn to_absolute(seg : Segment, cx : Double, cy : Double) -> Abs {
  let a = seg.args
  let upper = seg.cmd.to_ascii_uppercase()
  let rel = seg.cmd.is_ascii_lowercase()
  fn rx(v : Double) -> Double {
    if rel {
      cx + v
    } else {
      v
    }
  }
  fn ry(v : Double) -> Double {
    if rel {
      cy + v
    } else {
      v
    }
  }
  match upper {
    'H' => {
      let x = rx(a[0])
      { cmd: 'H', args: [x], ex: x, ey: cy, }
    }
    'V' => {
      let y = ry(a[0])
      { cmd: 'V', args: [y], ex: cx, ey: y, }
    }
    'Z' => { cmd: 'Z', args: [], ex: cx, ey: cy, }
    'A' => {
      let x = rx(a[5])
      let y = ry(a[6])
      { cmd: 'A', args: [a[0], a[1], a[2], a[3], a[4], x, y], ex: x, ey: y, }
    }
    _ => {
      let out : Array[Double] = []
      for i, v in a {
        out.push(if i % 2 == 0 { rx(v) } else { ry(v) })
      }
      {
        cmd: upper,
        args: out,
        ex: out[out.length() - 2],
        ey: out[out.length() - 1],
      }
    }
  }
}

///|
fn approx(a : Double, b : Double, precision : Int) -> Bool {
  round_to(a, precision) == round_to(b, precision)
}

///|
/// Distance of point p from the line through a and b relative to the chord
/// length; used to decide whether a curve is visually a straight line.
fn collinear(
  ax : Double,
  ay : Double,
  bx : Double,
  by : Double,
  px : Double,
  py : Double,
  tolerance : Double,
) -> Bool {
  let dx = bx - ax
  let dy = by - ay
  let len = (dx * dx + dy * dy).sqrt()
  if len == 0.0 {
    return ((px - ax) * (px - ax) + (py - ay) * (py - ay)).sqrt() <= tolerance
  }
  // Use the cross product form (dx*(py-ay) - dy*(px-ax)) instead of the
  // equivalent dy*px - dx*py + bx*ay - by*ax: the latter subtracts large
  // nearly-equal terms and loses precision when coordinates are large.
  let dist = (dx * (py - ay) - dy * (px - ax)).abs() / len
  // the control point must also lie between the end points (projection in [0,1])
  let t = ((px - ax) * dx + (py - ay) * dy) / (len * len)
  dist <= tolerance && t >= -0.0001 && t <= 1.0001
}

///|
priv struct Emitter {
  out : Array[Segment]
  options : Options
  /// rounded current point as the consumer of the output sees it
  mut bx : Double
  mut by : Double
  /// previous emitted collapsible command ('m','h','v') and its geometric delta
  mut prev_cmd : Char
  mut prev_dx : Double
  mut prev_dy : Double
}

///|
fn Emitter::seg_len(self : Emitter, seg : Segment) -> Int {
  segment_len(seg, self.options.precision)
}

///|
/// Emit a segment given its absolute arguments, picking the shorter of the
/// absolute and relative spellings, and update the rounded current point.
fn Emitter::emit(
  self : Emitter,
  cmd : Char,
  abs_args : Array[Double],
  ex : Double,
  ey : Double,
) -> Unit {
  let p = self.options.precision
  // Collapse consecutive m/h/v commands: two same-type moves or lines in a
  // row are equivalent to a single one covering the combined delta. For h and
  // v only merge when both deltas share a sign, so a direction reversal is
  // preserved (it can matter for markers or dash patterns).
  let lower = cmd.to_ascii_lowercase()
  let mut dx = ex - self.bx
  let mut dy = ey - self.by
  if self.options.collapse_repeated &&
    (lower == 'm' || lower == 'h' || lower == 'v') &&
    self.prev_cmd == lower {
    let same_sign = match lower {
      'h' => (self.prev_dx >= 0.0) == (dx >= 0.0)
      'v' => (self.prev_dy >= 0.0) == (dy >= 0.0)
      _ => true
    }
    if same_sign {
      // start point of the previous (now merged-away) segment
      let psx = if lower == 'v' { self.bx } else { self.bx - self.prev_dx }
      let psy = if lower == 'h' { self.by } else { self.by - self.prev_dy }
      ignore(self.out.pop())
      self.bx = psx
      self.by = psy
      dx = ex - psx
      dy = ey - psy
      self.prev_cmd = ' '
    }
  }
  // Round absolute coordinates first, then derive relative deltas from the
  // rounded values. Computing rel = round(abs_exact - bx_rounded) can drift
  // by an ULP when abs_exact is itself a sum of rounded steps.
  let abs_rounded = abs_args.map(v => strong_round(v, p))
  let rel_args : Array[Double] = []
  match cmd {
    'H' => rel_args.push(strong_round(abs_rounded[0] - self.bx, p))
    'V' => rel_args.push(strong_round(abs_rounded[0] - self.by, p))
    'A' => {
      for i in 0..<5 {
        rel_args.push(abs_rounded[i])
      }
      rel_args.push(strong_round(abs_rounded[5] - self.bx, p))
      rel_args.push(strong_round(abs_rounded[6] - self.by, p))
    }
    _ =>
      for i, v in abs_rounded {
        rel_args.push(
          strong_round(v - (if i % 2 == 0 { self.bx } else { self.by }), p),
        )
      }
  }
  let rel_seg : Segment = { cmd: cmd.to_ascii_lowercase(), args: rel_args, }
  let abs_seg : Segment = { cmd, args: abs_rounded, }
  let abs_len = self.seg_len(abs_seg)
  let rel_len = self.seg_len(rel_seg)
  // the first command must be absolute; movetos prefer absolute on ties
  let first = self.out.length() == 0
  // When the previous emitted command is the same lowercase command, the
  // relative form can drop its command letter (implicit repetition). If the
  // first relative argument also needs no leading separator (negative, or a
  // bare fraction after a fractional number), that saves exactly one byte, so
  // the effective relative length is rel_len - 1. On a tie we keep relative.
  let mut effective_rel_len = rel_len
  if !first {
    let prev = self.out[self.out.length() - 1]
    if prev.cmd == rel_seg.cmd {
      let first_rel = rel_args[0]
      let prev_last = prev.args[prev.args.length() - 1]
      let no_space = first_rel < 0.0 ||
        (
          first_rel > 0.0 &&
          first_rel < 1.0 &&
          prev_last - @math.floor(prev_last) != 0.0
        )
      if no_space {
        effective_rel_len = rel_len - 1
      }
    }
  }
  let use_abs = first ||
    (self.options.utilize_absolute && abs_len < effective_rel_len)
  if use_abs {
    self.out.push(abs_seg)
    self.bx = strong_round(ex, p)
    self.by = strong_round(ey, p)
  } else {
    self.out.push(rel_seg)
    // the consumer adds the rounded relative offsets to its current point
    match cmd {
      'H' => self.bx = strong_round(self.bx + rel_args[0], p)
      'V' => self.by = strong_round(self.by + rel_args[0], p)
      'A' => {
        self.bx = strong_round(self.bx + rel_args[5], p)
        self.by = strong_round(self.by + rel_args[6], p)
      }
      _ => {
        let n = rel_args.length()
        self.bx = strong_round(self.bx + rel_args[n - 2], p)
        self.by = strong_round(self.by + rel_args[n - 1], p)
      }
    }
  }
  // track the previous collapsible command and its geometric delta
  if lower == 'm' || lower == 'h' || lower == 'v' {
    self.prev_cmd = lower
    self.prev_dx = dx
    self.prev_dy = dy
  } else {
    self.prev_cmd = ' '
  }
}

///|
/// Optimize path data: convert between absolute/relative, use shorthand
/// commands, drop useless segments and round coordinates. The visual result
/// is preserved up to the configured precision.
pub fn optimize(
  segments : Array[Segment],
  options? : Options = Options::default(),
) -> Array[Segment] {
  let p = options.precision
  let em : Emitter = {
    out: [],
    options,
    bx: 0.0,
    by: 0.0,
    prev_cmd: ' ',
    prev_dx: 0.0,
    prev_dy: 0.0,
  }
  // exact current point and subpath start
  let mut cx = 0.0
  let mut cy = 0.0
  let mut sx = 0.0
  let mut sy = 0.0
  // rounded subpath start (where Z takes the consumer)
  let mut bsx = 0.0
  let mut bsy = 0.0
  // absolute second control point of the previous curve, for shorthands
  let mut prev_ctrl : (Double, Double)? = None
  let mut prev_kind : Char = ' ' // 'C' or 'Q' family of the previous emitted segment
  // original kind of the previous segment before straight-curve conversion,
  // used to resolve S/T control points (which reflect the previous curve's
  // control point even if that curve was collapsed to a line)
  let mut prev_orig_kind : Char = ' '
  let tolerance = @math.pow(10.0, -p.to_double())
  for seg in segments {
    let a = to_absolute(seg, cx, cy)
    let mut kind : Char = ' '
    let mut ctrl : (Double, Double)? = None
    match a.cmd {
      'M' => {
        // an M directly after another M replaces it
        if em.out.length() > 0 &&
          em.out[em.out.length() - 1].cmd.to_ascii_lowercase() == 'm' {
          let last = em.out.pop().unwrap()
          if last.cmd == 'm' {
            em.bx = strong_round(em.bx - last.args[0], p)
            em.by = strong_round(em.by - last.args[1], p)
          } else {
            em.bx = bsx
            em.by = bsy
          }
          em.prev_cmd = ' '
        }
        em.emit('M', a.args, a.ex, a.ey)
        sx = a.ex
        sy = a.ey
        bsx = em.bx
        bsy = em.by
      }
      'Z' => {
        if options.remove_useless && em.out.length() > 0 {
          // a line back to the start right before Z is redundant
          let last = em.out[em.out.length() - 1]
          if last.cmd.to_ascii_lowercase() is ('l' | 'h' | 'v') &&
            em.bx == bsx &&
            em.by == bsy {
            ignore(em.out.pop())
          }
        }
        // If the current point is already at the subpath start, the z is a
        // zero-length close. It is removable only when the stroke would not
        // make the join visible: no stroke, or (right after M and linecap is
        // butt), or (linecap and linejoin are both round).
        let at_start = em.bx == bsx && em.by == bsy
        let last_cmd = if em.out.length() > 0 {
          em.out[em.out.length() - 1].cmd
        } else {
          ' '
        }
        let prev_is_moveto = last_cmd == 'm' || last_cmd == 'M'
        let prev_is_z = last_cmd == 'z' || last_cmd == 'Z'
        let is_safe_to_use_z = !options.has_stroke ||
          (options.linecap == "round" && options.linejoin == "round")
        let safe_to_remove = !options.has_stroke ||
          (prev_is_moveto && options.linecap == "butt") ||
          (!prev_is_moveto && is_safe_to_use_z)
        // consecutive Z's are always redundant; a Z that closes at the
        // subpath start is redundant only when the join is invisible.
        let drop = prev_is_z || (at_start && safe_to_remove)
        if !drop {
          em.out.push({ cmd: seg.cmd, args: [], })
        }
        em.bx = bsx
        em.by = bsy
        em.prev_cmd = ' '
        // Z resets the current point; an implicit M would follow
        cx = sx
        cy = sy
        prev_ctrl = None
        prev_kind = ' '
        prev_orig_kind = ' '
        continue
      }
      'L' | 'H' | 'V' => {
        let ex = strong_round(a.ex, p)
        let ey = strong_round(a.ey, p)
        if options.remove_useless && ex == em.bx && ey == em.by {
          // zero-length segment: with round/square linecaps it renders as a
          // dot, so keep it as a zero-length horizontal line; otherwise drop.
          if options.linecap == "round" || options.linecap == "square" {
            em.emit('H', [a.ex], a.ex, a.ey)
          } else {
            cx = a.ex
            cy = a.ey
            prev_ctrl = None
            prev_kind = ' '
            prev_orig_kind = ' '
            continue
          }
        } else if options.convert_to_z &&
          em.out.length() > 0 &&
          ex == bsx &&
          ey == bsy &&
          (
            !options.has_stroke ||
            (options.linecap == "round" && options.linejoin == "round")
          ) {
          // a line back to the subpath start is equivalent to `z` only when
          // the join is invisible (no stroke, or round cap + round join)
          em.out.push({ cmd: 'z', args: [], })
          em.bx = bsx
          em.by = bsy
          em.prev_cmd = ' '
        } else if ey == em.by {
          em.emit('H', [a.ex], a.ex, a.ey)
        } else if ex == em.bx {
          em.emit('V', [a.ey], a.ex, a.ey)
        } else {
          em.emit('L', [a.ex, a.ey], a.ex, a.ey)
        }
      }
      'C' | 'S' => {
        // resolve the first control point of S from the previous cubic
        let (c1x, c1y, c2x, c2y) = if a.cmd == 'S' {
          let (rx, ry) = if prev_orig_kind == 'C' {
            match prev_ctrl {
              Some((px, py)) => (2.0 * cx - px, 2.0 * cy - py)
              None => (cx, cy)
            }
          } else {
            (cx, cy)
          }
          (rx, ry, a.args[0], a.args[1])
        } else {
          (a.args[0], a.args[1], a.args[2], a.args[3])
        }
        if options.straight_curves &&
          collinear(cx, cy, a.ex, a.ey, c1x, c1y, tolerance) &&
          collinear(cx, cy, a.ex, a.ey, c2x, c2y, tolerance) {
          let ex = strong_round(a.ex, p)
          let ey = strong_round(a.ey, p)
          if options.remove_useless && ex == em.bx && ey == em.by {
            if options.linecap == "round" || options.linecap == "square" {
              em.emit('H', [a.ex], a.ex, a.ey)
              kind = 'C'
              ctrl = Some((c2x, c2y))
            } else {
              cx = a.ex
              cy = a.ey
              prev_ctrl = None
              prev_kind = ' '
              prev_orig_kind = ' '
              continue
            }
          } else if ey == em.by {
            em.emit('H', [a.ex], a.ex, a.ey)
          } else if ex == em.bx {
            em.emit('V', [a.ey], a.ex, a.ey)
          } else {
            em.emit('L', [a.ex, a.ey], a.ex, a.ey)
          }
          // Keep the second control point so a following `s` can still
          // reflect it, but mark the emitted command as a line so the `s`
          // shorthand is not used (it would be invalid after an `l`).
          kind = ' '
          ctrl = Some((c2x, c2y))
        } else if options.convert_to_q {
          // convertToQ: a cubic whose control points satisfy
          // C1 = P0 + 2/3*(Q-P0) and C2 = P3 + 2/3*(Q-P3) is exactly a
          // quadratic with control point Q = (3*C1 - P0)/2 = (3*C2 - P3)/2.
          let qx1 = (3.0 * c1x - cx) / 2.0
          let qy1 = (3.0 * c1y - cy) / 2.0
          let qx2 = (3.0 * c2x - a.ex) / 2.0
          let qy2 = (3.0 * c2y - a.ey) / 2.0
          if (qx1 - qx2).abs() < 2.0 * tolerance &&
            (qy1 - qy2).abs() < 2.0 * tolerance {
            let qx = strong_round(qx1, p)
            let qy = strong_round(qy1, p)
            em.emit('Q', [qx, qy, a.ex, a.ey], a.ex, a.ey)
            kind = 'Q'
            ctrl = Some((qx, qy))
            prev_orig_kind = 'Q'
            cx = a.ex
            cy = a.ey
            continue
          }
          // The renderer derives the first control point of `S` from the
          // previous cubic's second control point only when the previous
          // emitted command was C/S; otherwise it uses the current point.
          // Use the shorthand only when that matches our resolved c1.
          let (mx, my) = if prev_kind == 'C' {
            match prev_ctrl {
              Some((px, py)) => (2.0 * cx - px, 2.0 * cy - py)
              None => (cx, cy)
            }
          } else {
            (cx, cy)
          }
          if options.smooth_shorthands &&
            approx(c1x, mx, p) &&
            approx(c1y, my, p) {
            em.emit('S', [c2x, c2y, a.ex, a.ey], a.ex, a.ey)
          } else {
            em.emit('C', [c1x, c1y, c2x, c2y, a.ex, a.ey], a.ex, a.ey)
          }
          kind = 'C'
          ctrl = Some((c2x, c2y))
        } else {
          // The renderer derives the first control point of `S` from the
          // previous cubic's second control point only when the previous
          // emitted command was C/S; otherwise it uses the current point.
          // Use the shorthand only when that matches our resolved c1.
          let (mx, my) = if prev_kind == 'C' {
            match prev_ctrl {
              Some((px, py)) => (2.0 * cx - px, 2.0 * cy - py)
              None => (cx, cy)
            }
          } else {
            (cx, cy)
          }
          if options.smooth_shorthands &&
            approx(c1x, mx, p) &&
            approx(c1y, my, p) {
            em.emit('S', [c2x, c2y, a.ex, a.ey], a.ex, a.ey)
          } else {
            em.emit('C', [c1x, c1y, c2x, c2y, a.ex, a.ey], a.ex, a.ey)
          }
          kind = 'C'
          ctrl = Some((c2x, c2y))
        }
      }
      'Q' | 'T' => {
        let (qx, qy) = if a.cmd == 'T' {
          if prev_orig_kind == 'Q' {
            match prev_ctrl {
              Some((px, py)) => (2.0 * cx - px, 2.0 * cy - py)
              None => (cx, cy)
            }
          } else {
            (cx, cy)
          }
        } else {
          (a.args[0], a.args[1])
        }
        // A `t` whose predecessor was not a quadratic curve has no control
        // point to reflect, so it degenerates to a straight line. When the
        // previous `q`/`t` was itself collapsed to `l`, svgo rewrites the `t`
        // to `q` longhand and then applies the straight-curve check to that
        // `q`. A `t` after an unconverted `q`/`t` stays a curve regardless.
        let degenerate_t = a.cmd == 'T' && prev_orig_kind != 'Q'
        let prev_q_collapsed = a.cmd == 'T' &&
          prev_orig_kind == 'Q' &&
          prev_kind == ' '
        let is_straight = (a.cmd == 'Q' || prev_q_collapsed) &&
          options.straight_curves &&
          collinear(cx, cy, a.ex, a.ey, qx, qy, tolerance)
        if degenerate_t || is_straight {
          let ex = strong_round(a.ex, p)
          let ey = strong_round(a.ey, p)
          if options.remove_useless && ex == em.bx && ey == em.by {
            if options.linecap == "round" || options.linecap == "square" {
              em.emit('H', [a.ex], a.ex, a.ey)
              kind = 'Q'
              ctrl = Some((qx, qy))
            } else {
              cx = a.ex
              cy = a.ey
              prev_ctrl = None
              prev_kind = ' '
              prev_orig_kind = ' '
              continue
            }
          } else if ey == em.by {
            em.emit('H', [a.ex], a.ex, a.ey)
          } else if ex == em.bx {
            em.emit('V', [a.ey], a.ex, a.ey)
          } else {
            em.emit('L', [a.ex, a.ey], a.ex, a.ey)
          }
          // Even when a quadratic collapses to a line, the next `t` must
          // still reflect this curve's control point. Record the original
          // quadratic kind and control point.
          kind = ' '
          ctrl = Some((qx, qy))
          prev_orig_kind = 'Q'
        } else {
          // The renderer derives the control point of `T` from the previous
          // quadratic's control point only when the previous emitted command
          // was Q/T; otherwise it uses the current point. Use the shorthand
          // only when that matches our resolved qx,qy.
          let (mx, my) = if prev_kind == 'Q' {
            match prev_ctrl {
              Some((px, py)) => (2.0 * cx - px, 2.0 * cy - py)
              None => (cx, cy)
            }
          } else {
            (cx, cy)
          }
          if options.smooth_shorthands && approx(qx, mx, p) && approx(qy, my, p) {
            em.emit('T', [a.ex, a.ey], a.ex, a.ey)
          } else {
            em.emit('Q', [qx, qy, a.ex, a.ey], a.ex, a.ey)
          }
          kind = 'Q'
          ctrl = Some((qx, qy))
        }
      }
      'A' => {
        let mut rx = a.args[0]
        let mut ry = a.args[1]
        let large_arc = a.args[3]
        let dx = a.ex - cx
        let dy = a.ey - cy
        let chord = (dx * dx + dy * dy).sqrt()
        // smartArcRounding: for circular arcs, try rounding the radius to
        // fewer decimal places as long as the sagitta change stays below the
        // precision error.
        if large_arc == 0.0 &&
          (rx - ry).abs() < tolerance &&
          rx > 0.0 &&
          chord <= 2.0 * rx {
          let sagitta = rx - (rx * rx - 0.25 * chord * chord).sqrt()
          let mut p_new = p
          while p_new >= 0 {
            let r = strong_round(rx, p_new)
            if r > 0.0 && chord <= 2.0 * r {
              let s_new = r - (r * r - 0.25 * chord * chord).sqrt()
              if (sagitta - s_new).abs() < tolerance {
                rx = r
                ry = r
              } else {
                break
              }
            } else {
              break
            }
            p_new -= 1
          }
        }
        // straightCurves: a circular arc whose sagitta is below the precision
        // error is visually a straight line.
        let is_straight_arc = options.straight_curves &&
          large_arc == 0.0 &&
          (rx - ry).abs() < tolerance &&
          chord <= 2.0 * rx &&
          rx > 0.0 &&
          ({
            let sagitta = rx - (rx * rx - 0.25 * chord * chord).sqrt()
            sagitta < tolerance
          })
        if strong_round(rx, p) == 0.0 ||
          strong_round(ry, p) == 0.0 ||
          is_straight_arc {
          // the spec says a degenerate arc is a straight line
          let ex = strong_round(a.ex, p)
          let ey = strong_round(a.ey, p)
          if options.remove_useless && ex == em.bx && ey == em.by {
            if options.linecap == "round" || options.linecap == "square" {
              em.emit('H', [a.ex], a.ex, a.ey)
            }
          } else if ey == em.by {
            em.emit('H', [a.ex], a.ex, a.ey)
          } else if ex == em.bx {
            em.emit('V', [a.ey], a.ex, a.ey)
          } else {
            em.emit('L', [a.ex, a.ey], a.ex, a.ey)
          }
        } else {
          let ex = strong_round(a.ex, p)
          let ey = strong_round(a.ey, p)
          if options.remove_useless && ex == em.bx && ey == em.by {
            if options.linecap == "round" || options.linecap == "square" {
              em.emit('H', [a.ex], a.ex, a.ey)
            } else {
              cx = a.ex
              cy = a.ey
              prev_ctrl = None
              prev_kind = ' '
              prev_orig_kind = ' '
              continue
            }
          } else {
            em.emit(
              'A',
              [rx.abs(), ry.abs(), a.args[2], a.args[3], a.args[4], a.ex, a.ey],
              a.ex,
              a.ey,
            )
          }
        }
      }
      _ => ()
    }
    cx = a.ex
    cy = a.ey
    prev_ctrl = ctrl
    prev_kind = kind
    prev_orig_kind = match a.cmd {
      'C' | 'S' => 'C'
      'Q' | 'T' => 'Q'
      _ => ' '
    }
  }
  em.out
}

///|
/// Convenience: parse, optimize and stringify path data.
pub fn optimize_string(
  d : String,
  options? : Options = Options::default(),
) -> String raise PathError {
  stringify(optimize(parse(d), options~), precision=options.precision)
}
