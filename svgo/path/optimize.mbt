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
  /// relative deltas from the current point (the original parsed values for
  /// relative commands, or `abs - base` for absolute commands). Kept separate
  /// from `args` because `(base + delta) - base` can differ from `delta` by a
  /// ULP, which would change the rounded output.
  rel_args : Array[Double]
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
      let rel_x = if rel { a[0] } else { a[0] - cx }
      { cmd: 'H', args: [x], rel_args: [rel_x], ex: x, ey: cy, }
    }
    'V' => {
      let y = ry(a[0])
      let rel_y = if rel { a[0] } else { a[0] - cy }
      { cmd: 'V', args: [y], rel_args: [rel_y], ex: cx, ey: y, }
    }
    'Z' => { cmd: 'Z', args: [], rel_args: [], ex: cx, ey: cy, }
    'A' => {
      let x = rx(a[5])
      let y = ry(a[6])
      let rel_x = if rel { a[5] } else { a[5] - cx }
      let rel_y = if rel { a[6] } else { a[6] - cy }
      {
        cmd: 'A',
        args: [a[0], a[1], a[2], a[3], a[4], x, y],
        rel_args: [a[0], a[1], a[2], a[3], a[4], rel_x, rel_y],
        ex: x,
        ey: y,
      }
    }
    _ => {
      let out : Array[Double] = []
      let rel_out : Array[Double] = []
      for i, v in a {
        let abs_v = if i % 2 == 0 { rx(v) } else { ry(v) }
        let rel_v = if rel { v } else if i % 2 == 0 { v - cx } else { v - cy }
        out.push(abs_v)
        rel_out.push(rel_v)
      }
      {
        cmd: upper,
        args: out,
        rel_args: rel_out,
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
  /// accumulated rounded offset from the subpath start (svgo's relSubpoint).
  /// Relative coordinates are computed as round(abs_exact - rsx) so that the
  /// rounding is anchored to the accumulated rounded offset, not the exact
  /// current point — matching svgo's strongRound behaviour.
  mut rsx : Double
  mut rsy : Double
  /// previous emitted collapsible command ('m','h','v') and its geometric delta
  mut prev_cmd : Char
  mut prev_dx : Double
  mut prev_dy : Double
  /// rounded endpoint deltas of the previous emitted segment, used to undo
  /// their contribution to rsx/rsy when the segment is popped by a collapse.
  mut prev_rdx : Double
  mut prev_rdy : Double
}

///|
fn Emitter::seg_len(self : Emitter, seg : Segment) -> Int {
  segment_len(seg, self.options.precision)
}

///|
/// Emit a segment given its absolute arguments, picking the shorter of the
/// absolute and relative spellings, and update the rounded current point.
/// `bx`/`by` is the exact current point before this segment (the base that
/// the relative form is measured from). `rel_args` are the exact relative
/// deltas (not `abs_args - base`, which can drift by a ULP).
fn Emitter::emit(
  self : Emitter,
  cmd : Char,
  abs_args : Array[Double],
  rel_args : Array[Double],
  ex : Double,
  ey : Double,
  bx : Double,
  by : Double,
) -> Unit {
  let p = self.options.precision
  // Collapse consecutive m/h/v commands: two same-type moves or lines in a
  // row are equivalent to a single one covering the combined delta. For h and
  // v only merge when both deltas share a sign, so a direction reversal is
  // preserved (it can matter for markers or dash patterns).
  let lower = cmd.to_ascii_lowercase()
  let mut dx = ex - self.bx
  let mut dy = ey - self.by
  // effective base point for the relative correction; changes when the
  // previous segment is merged into this one by the collapse logic.
  let mut base_x = bx
  let mut base_y = by
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
      // undo the previous segment's contribution to the accumulated
      // rounded offset, since its delta is now folded into this one.
      self.rsx = strong_round(self.rsx - self.prev_rdx, p)
      self.rsy = strong_round(self.rsy - self.prev_rdy, p)
      dx = ex - psx
      dy = ey - psy
      base_x = psx
      base_y = psy
      self.prev_cmd = ' '
    }
  }
  // Round relative deltas as rel_args[i] + (base - rs), matching svgo's
  // order of operations: data[i] += item.base[i] - relSubpoint[i].
  // Then the absolute form is round(rel_corrected[i] + base), NOT
  // round(abs_args[i]): svgo recomputes absolute coords from the rounded
  // relative value plus the unrounded base, which can differ from rounding
  // the absolute coordinate directly by a ULP at strong_round boundaries.
  let rel_corrected : Array[Double] = []
  match cmd {
    'H' => {
      let rel = dx + (base_x - self.rsx)
      rel_corrected.push(strong_round(rel, p))
    }
    'V' => {
      let rel = dy + (base_y - self.rsy)
      rel_corrected.push(strong_round(rel, p))
    }
    'A' => {
      for i in 0..<5 {
        rel_corrected.push(strong_round(abs_args[i], p))
      }
      let relx = rel_args[5] + (base_x - self.rsx)
      let rely = rel_args[6] + (base_y - self.rsy)
      rel_corrected.push(strong_round(relx, p))
      rel_corrected.push(strong_round(rely, p))
    }
    'M' => {
      let relx = dx + (base_x - self.rsx)
      let rely = dy + (base_y - self.rsy)
      rel_corrected.push(strong_round(relx, p))
      rel_corrected.push(strong_round(rely, p))
    }
    _ =>
      for i, v in rel_args {
        let base = if i % 2 == 0 { base_x } else { base_y }
        let rs = if i % 2 == 0 { self.rsx } else { self.rsy }
        let rel = v + (base - rs)
        rel_corrected.push(strong_round(rel, p))
      }
  }
  // Absolute form: rounded relative + base, then round again. This matches
  // svgo's convertToMixed which does adata[i] = data[i] + item.base[i] then
  // roundData(adata).
  let abs_rounded : Array[Double] = []
  match cmd {
    'H' => abs_rounded.push(strong_round(rel_corrected[0] + base_x, p))
    'V' => abs_rounded.push(strong_round(rel_corrected[0] + base_y, p))
    'A' => {
      for i in 0..<5 {
        abs_rounded.push(rel_corrected[i])
      }
      abs_rounded.push(strong_round(rel_corrected[5] + base_x, p))
      abs_rounded.push(strong_round(rel_corrected[6] + base_y, p))
    }
    _ =>
      for i, v in rel_corrected {
        let base = if i % 2 == 0 { base_x } else { base_y }
        abs_rounded.push(strong_round(v + base, p))
      }
  }
  let rel_seg : Segment = {
    cmd: cmd.to_ascii_lowercase(),
    args: rel_corrected,
  }
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
      let first_rel = rel_corrected[0]
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
      'H' => self.bx = strong_round(self.bx + rel_corrected[0], p)
      'V' => self.by = strong_round(self.by + rel_corrected[0], p)
      'A' => {
        self.bx = strong_round(self.bx + rel_corrected[5], p)
        self.by = strong_round(self.by + rel_corrected[6], p)
      }
      _ => {
        let n = rel_corrected.length()
        self.bx = strong_round(self.bx + rel_corrected[n - 2], p)
        self.by = strong_round(self.by + rel_corrected[n - 1], p)
      }
    }
  }
  // Update the accumulated rounded offset (svgo's relSubpoint): add the
  // rounded endpoint relative delta, then round the accumulated value.
  match cmd {
    'H' => self.rsx = strong_round(self.rsx + rel_corrected[0], p)
    'V' => self.rsy = strong_round(self.rsy + rel_corrected[0], p)
    'A' => {
      self.rsx = strong_round(self.rsx + rel_corrected[5], p)
      self.rsy = strong_round(self.rsy + rel_corrected[6], p)
    }
    _ => {
      let n = rel_corrected.length()
      self.rsx = strong_round(self.rsx + rel_corrected[n - 2], p)
      self.rsy = strong_round(self.rsy + rel_corrected[n - 1], p)
    }
  }
  // track the previous collapsible command and its geometric delta
  if lower == 'm' || lower == 'h' || lower == 'v' {
    self.prev_cmd = lower
    self.prev_dx = dx
    self.prev_dy = dy
    // rounded endpoint deltas, to undo from rsx/rsy if this segment is
    // later merged into the next one.
    match cmd {
      'H' => {
        self.prev_rdx = rel_corrected[0]
        self.prev_rdy = 0.0
      }
      'V' => {
        self.prev_rdx = 0.0
        self.prev_rdy = rel_corrected[0]
      }
      _ => {
        let n = rel_corrected.length()
        self.prev_rdx = rel_corrected[n - 2]
        self.prev_rdy = rel_corrected[n - 1]
      }
    }
  } else {
    self.prev_cmd = ' '
  }
}

///|
/// Emit a straight segment to `a`'s end point as `H`, `V` or `L`, whichever
/// the rounded cursor (`ex`, `ey` is the rounded end point) allows.
fn Emitter::emit_line(
  self : Emitter,
  a : Abs,
  rel_dx : Double,
  rel_dy : Double,
  ex : Double,
  ey : Double,
  cx : Double,
  cy : Double,
) -> Unit {
  if ey == self.by {
    self.emit('H', [a.ex], [rel_dx], a.ex, a.ey, cx, cy)
  } else if ex == self.bx {
    self.emit('V', [a.ey], [rel_dy], a.ex, a.ey, cx, cy)
  } else {
    self.emit('L', [a.ex, a.ey], [rel_dx, rel_dy], a.ex, a.ey, cx, cy)
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
    rsx: 0.0,
    rsy: 0.0,
    prev_cmd: ' ',
    prev_dx: 0.0,
    prev_dy: 0.0,
    prev_rdx: 0.0,
    prev_rdy: 0.0,
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
        let mut base_x = cx
        let mut base_y = cy
        if em.out.length() > 0 &&
          em.out[em.out.length() - 1].cmd.to_ascii_lowercase() == 'm' {
          let last = em.out.pop().unwrap()
          if last.cmd == 'm' {
            em.bx = strong_round(em.bx - last.args[0], p)
            em.by = strong_round(em.by - last.args[1], p)
            em.rsx = strong_round(em.rsx - last.args[0], p)
            em.rsy = strong_round(em.rsy - last.args[1], p)
            // the previous M's endpoint was cx,cy; its relative delta was
            // last.args, so the base before it was cx - last.args[0].
            base_x = cx - last.args[0]
            base_y = cy - last.args[1]
          } else {
            // previous M was absolute (only happens for the first command,
            // where the base is the origin).
            em.bx = 0.0
            em.by = 0.0
            em.rsx = 0.0
            em.rsy = 0.0
            base_x = 0.0
            base_y = 0.0
          }
          em.prev_cmd = ' '
        }
        em.emit('M', a.args, a.rel_args, a.ex, a.ey, base_x, base_y)
        sx = a.ex
        sy = a.ey
        // The rounded subpath start must be the rounded absolute moveto
        // coordinate, not the emitter's accumulated bx (which can drift by a
        // ULP when the moveto was emitted as relative). A `z` resets the
        // cursor here, so a following relative `m` is measured from it.
        bsx = strong_round(sx, p)
        bsy = strong_round(sy, p)
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
        // svgo sets relSubpoint = pathBase after a closepath, so the next
        // segment's relative coordinates are measured from the rounded
        // subpath start (not from zero).
        em.rsx = bsx
        em.rsy = bsy
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
        // Relative x/y deltas (exact, from the original segment). An `H`/`V`
        // moves along one axis only, so the other delta is exactly zero. The
        // pair is needed because the rounded cursor can drift from the exact
        // one by a unit at the last place, in which case an `H`/`V` is
        // widened to `L` below and `emit` indexes both deltas.
        let (rel_dx, rel_dy) = match a.cmd {
          'H' => (a.rel_args[0], 0.0)
          'V' => (0.0, a.rel_args[0])
          _ => (a.rel_args[0], a.rel_args[1])
        }
        if options.remove_useless && ex == em.bx && ey == em.by {
          // zero-length segment: with round/square linecaps it renders as a
          // dot, so keep it as a zero-length horizontal line; otherwise drop.
          if options.linecap == "round" || options.linecap == "square" {
            em.emit_line(a, rel_dx, rel_dy, ex, ey, cx, cy)
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
          em.rsx = bsx
          em.rsy = bsy
          em.prev_cmd = ' '
        } else {
          em.emit_line(a, rel_dx, rel_dy, ex, ey, cx, cy)
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
        // endpoint relative deltas (exact, from the original segment)
        let rel_endx = a.rel_args[a.rel_args.length() - 2]
        let rel_endy = a.rel_args[a.rel_args.length() - 1]
        if options.straight_curves &&
          collinear(cx, cy, a.ex, a.ey, c1x, c1y, tolerance) &&
          collinear(cx, cy, a.ex, a.ey, c2x, c2y, tolerance) {
          let ex = strong_round(a.ex, p)
          let ey = strong_round(a.ey, p)
          if options.remove_useless && ex == em.bx && ey == em.by {
            if options.linecap == "round" || options.linecap == "square" {
              em.emit_line(a, rel_endx, rel_endy, ex, ey, cx, cy)
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
          } else {
            em.emit_line(a, rel_endx, rel_endy, ex, ey, cx, cy)
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
            em.emit(
              'Q',
              [qx, qy, a.ex, a.ey],
              [qx - cx, qy - cy, rel_endx, rel_endy],
              a.ex,
              a.ey,
              cx,
              cy,
            )
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
            em.emit(
              'S',
              [c2x, c2y, a.ex, a.ey],
              [c2x - cx, c2y - cy, rel_endx, rel_endy],
              a.ex,
              a.ey,
              cx,
              cy,
            )
          } else {
            em.emit(
              'C',
              [c1x, c1y, c2x, c2y, a.ex, a.ey],
              [c1x - cx, c1y - cy, c2x - cx, c2y - cy, rel_endx, rel_endy],
              a.ex,
              a.ey,
              cx,
              cy,
            )
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
            em.emit(
              'S',
              [c2x, c2y, a.ex, a.ey],
              [c2x - cx, c2y - cy, rel_endx, rel_endy],
              a.ex,
              a.ey,
              cx,
              cy,
            )
          } else {
            em.emit(
              'C',
              [c1x, c1y, c2x, c2y, a.ex, a.ey],
              [c1x - cx, c1y - cy, c2x - cx, c2y - cy, rel_endx, rel_endy],
              a.ex,
              a.ey,
              cx,
              cy,
            )
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
        // endpoint relative deltas (exact, from the original segment)
        let rel_endx = a.rel_args[a.rel_args.length() - 2]
        let rel_endy = a.rel_args[a.rel_args.length() - 1]
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
              em.emit_line(a, rel_endx, rel_endy, ex, ey, cx, cy)
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
          } else {
            em.emit_line(a, rel_endx, rel_endy, ex, ey, cx, cy)
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
            em.emit('T', [a.ex, a.ey], [rel_endx, rel_endy], a.ex, a.ey, cx, cy)
          } else {
            em.emit(
              'Q',
              [qx, qy, a.ex, a.ey],
              [qx - cx, qy - cy, rel_endx, rel_endy],
              a.ex,
              a.ey,
              cx,
              cy,
            )
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
        // endpoint relative deltas (exact, from the original segment)
        let rel_endx = a.rel_args[5]
        let rel_endy = a.rel_args[6]
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
              em.emit_line(a, rel_endx, rel_endy, ex, ey, cx, cy)
            }
          } else {
            em.emit_line(a, rel_endx, rel_endy, ex, ey, cx, cy)
          }
        } else {
          let ex = strong_round(a.ex, p)
          let ey = strong_round(a.ey, p)
          if options.remove_useless && ex == em.bx && ey == em.by {
            if options.linecap == "round" || options.linecap == "square" {
              em.emit_line(a, rel_endx, rel_endy, ex, ey, cx, cy)
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
              [
                rx.abs(),
                ry.abs(),
                a.args[2],
                a.args[3],
                a.args[4],
                rel_endx,
                rel_endy,
              ],
              a.ex,
              a.ey,
              cx,
              cy,
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
  let cos = @math.cos(rot)
  let sin = @math.sin(rot)
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
      @math.acos(value / @math.hypot(term1, term2)) *
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
/// Convenience: parse, optimize and stringify path data.
pub fn optimize_string(
  d : String,
  options? : Options = Options::default(),
) -> String raise PathError {
  stringify(optimize(parse(d), options~), precision=options.precision)
}
