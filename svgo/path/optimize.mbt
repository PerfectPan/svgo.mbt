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
  /// convert runs of cubic beziers approximating a circular arc into `A`
  make_arcs : Bool
  /// coefficient of the rounding error used as the arc-fit tolerance
  make_arcs_threshold : Double
  /// arc-fit tolerance as a fraction of the radius (percentage points)
  make_arcs_tolerance : Double
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
    make_arcs: true,
    make_arcs_threshold: 2.5,
    make_arcs_tolerance: 0.5,
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
  @num.round_to(a, precision) == @num.round_to(b, precision)
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
      self.rsx = @num.strong_round(self.rsx - self.prev_rdx, p)
      self.rsy = @num.strong_round(self.rsy - self.prev_rdy, p)
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
      rel_corrected.push(@num.strong_round(rel, p))
    }
    'V' => {
      let rel = dy + (base_y - self.rsy)
      rel_corrected.push(@num.strong_round(rel, p))
    }
    'A' => {
      for i in 0..<5 {
        rel_corrected.push(@num.strong_round(abs_args[i], p))
      }
      let relx = rel_args[5] + (base_x - self.rsx)
      let rely = rel_args[6] + (base_y - self.rsy)
      rel_corrected.push(@num.strong_round(relx, p))
      rel_corrected.push(@num.strong_round(rely, p))
    }
    'M' => {
      let relx = dx + (base_x - self.rsx)
      let rely = dy + (base_y - self.rsy)
      rel_corrected.push(@num.strong_round(relx, p))
      rel_corrected.push(@num.strong_round(rely, p))
    }
    _ =>
      for i, v in rel_args {
        let base = if i % 2 == 0 { base_x } else { base_y }
        let rs = if i % 2 == 0 { self.rsx } else { self.rsy }
        let rel = v + (base - rs)
        rel_corrected.push(@num.strong_round(rel, p))
      }
  }
  // Absolute form: rounded relative + base, then round again. This matches
  // svgo's convertToMixed which does adata[i] = data[i] + item.base[i] then
  // roundData(adata).
  let abs_rounded : Array[Double] = []
  match cmd {
    'H' => abs_rounded.push(@num.strong_round(rel_corrected[0] + base_x, p))
    'V' => abs_rounded.push(@num.strong_round(rel_corrected[0] + base_y, p))
    'A' => {
      for i in 0..<5 {
        abs_rounded.push(rel_corrected[i])
      }
      abs_rounded.push(@num.strong_round(rel_corrected[5] + base_x, p))
      abs_rounded.push(@num.strong_round(rel_corrected[6] + base_y, p))
    }
    _ =>
      for i, v in rel_corrected {
        let base = if i % 2 == 0 { base_x } else { base_y }
        abs_rounded.push(@num.strong_round(v + base, p))
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
    self.bx = @num.strong_round(ex, p)
    self.by = @num.strong_round(ey, p)
  } else {
    self.out.push(rel_seg)
    // the consumer adds the rounded relative offsets to its current point
    match cmd {
      'H' => self.bx = @num.strong_round(self.bx + rel_corrected[0], p)
      'V' => self.by = @num.strong_round(self.by + rel_corrected[0], p)
      'A' => {
        self.bx = @num.strong_round(self.bx + rel_corrected[5], p)
        self.by = @num.strong_round(self.by + rel_corrected[6], p)
      }
      _ => {
        let n = rel_corrected.length()
        self.bx = @num.strong_round(self.bx + rel_corrected[n - 2], p)
        self.by = @num.strong_round(self.by + rel_corrected[n - 1], p)
      }
    }
  }
  // Update the accumulated rounded offset (svgo's relSubpoint): add the
  // rounded endpoint relative delta, then round the accumulated value.
  match cmd {
    'H' => self.rsx = @num.strong_round(self.rsx + rel_corrected[0], p)
    'V' => self.rsy = @num.strong_round(self.rsy + rel_corrected[0], p)
    'A' => {
      self.rsx = @num.strong_round(self.rsx + rel_corrected[5], p)
      self.rsy = @num.strong_round(self.rsy + rel_corrected[6], p)
    }
    _ => {
      let n = rel_corrected.length()
      self.rsx = @num.strong_round(self.rsx + rel_corrected[n - 2], p)
      self.rsy = @num.strong_round(self.rsy + rel_corrected[n - 1], p)
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
/// Point on a cubic bezier at parameter `t`, with the start point at the
/// origin. `curve` is the six relative control values [x1 y1 x2 y2 x y].
fn get_cubic_bezier_point(
  curve : Array[Double],
  t : Double,
) -> (Double, Double) {
  let sqr_t = t * t
  let cub_t = sqr_t * t
  let mt = 1.0 - t
  let sqr_mt = mt * mt
  let x = 3.0 * sqr_mt * t * curve[0] +
    3.0 * mt * sqr_t * curve[2] +
    cub_t * curve[4]
  let y = 3.0 * sqr_mt * t * curve[1] +
    3.0 * mt * sqr_t * curve[3] +
    cub_t * curve[5]
  (x, y)
}

///|
/// Intersection of two lines given by eight coordinates [x1 y1 x2 y2 x3 y3
/// x4 y4]. Returns None for parallel lines.
fn get_intersection(coords : Array[Double]) -> (Double, Double)? {
  let a1 = coords[1] - coords[3]
  let b1 = coords[2] - coords[0]
  let c1 = coords[0] * coords[3] - coords[2] * coords[1]
  let a2 = coords[5] - coords[7]
  let b2 = coords[6] - coords[4]
  let c2 = coords[4] * coords[7] - coords[5] * coords[6]
  let denom = a1 * b2 - a2 * b1
  if denom == 0.0 {
    return None
  }
  let cx = (b1 * c2 - b2 * c1) / denom
  let cy = (a1 * c2 - a2 * c1) / -denom
  if cx.is_nan() || cy.is_nan() || cx.is_inf() || cy.is_inf() {
    None
  } else {
    Some((cx, cy))
  }
}

///|
/// Whether the cubic's control points form a convex quadrilateral: the
/// diagonals (0,0)-(x2,y2) and (x1,y1)-(x,y) cross inside the hull.
fn is_convex(data : Array[Double]) -> Bool {
  match
    get_intersection([
      0.0,
      0.0,
      data[2],
      data[3],
      data[0],
      data[1],
      data[4],
      data[5],
    ]) {
    Some((cx, cy)) =>
      (data[2] < cx) == (cx < 0.0) &&
      (data[3] < cy) == (cy < 0.0) &&
      (data[4] < cx) == (cx < data[0]) &&
      (data[5] < cy) == (cy < data[1])
    None => false
  }
}

///|
/// A circle fitted to a cubic bezier: center and radius.
priv struct Circle {
  cx : Double
  cy : Double
  r : Double
}

///|
/// Information about an emitted arc needed to extend it with a following
/// curve that lies on the same circle.
priv struct ArcInfo {
  /// the last curve's control points (for isArcPrev)
  sdata : Array[Double]
  /// total endpoint of the arc, relative to its start
  endx : Double
  endy : Double
  /// total angle swept by the arc
  angle : Double
}

///|
/// Fit a circle to the cubic by the start, midpoint and end points, then
/// verify the quarter points lie within `tolerance` of it. Returns the
/// circle or None if the curve does not approximate a circular arc.
fn find_circle(
  curve : Array[Double],
  threshold : Double,
  tolerance_pct : Double,
  error : Double,
) -> Circle? {
  let (mx, my) = get_cubic_bezier_point(curve, 0.5)
  let m1x = mx / 2.0
  let m1y = my / 2.0
  let m2x = (mx + curve[4]) / 2.0
  let m2y = (my + curve[5]) / 2.0
  // perpendicular bisector of (0,0)-midpoint through m1
  // perpendicular bisector of midpoint-end through m2
  match
    get_intersection([
      m1x,
      m1y,
      m1x + m1y,
      m1y - m1x,
      m2x,
      m2y,
      m2x + (m2y - my),
      m2y - (m2x - mx),
    ]) {
    Some((cx, cy)) => {
      let r = (cx * cx + cy * cy).sqrt()
      if r >= 1.0e15 {
        return None
      }
      let tol = (threshold * error).min(tolerance_pct * r / 100.0)
      let fits = [0.25, 0.75].all(t => {
        let (px, py) = get_cubic_bezier_point(curve, t)
        let d = ((px - cx) * (px - cx) + (py - cy) * (py - cy)).sqrt()
        (d - r).abs() <= tol
      })
      if fits {
        Some({ cx, cy, r, })
      } else {
        None
      }
    }
    None => None
  }
}

///|
/// Whether the cubic fits the given circle at t = 0, 1/4, 1/2, 3/4, 1.
fn is_arc(
  curve : Array[Double],
  circle : Circle,
  threshold : Double,
  tolerance_pct : Double,
  error : Double,
) -> Bool {
  let tol = (threshold * error).min(tolerance_pct * circle.r / 100.0)
  [0.0, 0.25, 0.5, 0.75, 1.0].all(t => {
    let (px, py) = get_cubic_bezier_point(curve, t)
    let d = ((px - circle.cx) * (px - circle.cx) +
    (py - circle.cy) * (py - circle.cy)).sqrt()
    (d - circle.r).abs() <= tol
  })
}

///|
/// Angle (in radians) swept by the arc from the curve's start to its end,
/// measured about the circle center.
fn find_arc_angle(
  curve : Array[Double],
  rel_cx : Double,
  rel_cy : Double,
) -> Double {
  let x1 = -rel_cx
  let y1 = -rel_cy
  let x2 = curve[4] - rel_cx
  let y2 = curve[5] - rel_cy
  let denom = ((x1 * x1 + y1 * y1) * (x2 * x2 + y2 * y2)).sqrt()
  if denom == 0.0 {
    0.0
  } else {
    let cos = (x1 * x2 + y1 * y2) / denom
    // clamp to [-1, 1] to dodge acos NaNs from floating point drift
    @num.acos(if cos > 1.0 { 1.0 } else if cos < -1.0 { -1.0 } else { cos })
  }
}

///|
/// Convert runs of convex cubic beziers that approximate a circular arc into
/// `A` commands. Operates on the original (mixed absolute/relative) segments
/// and returns a new array; the rest of `optimize` then rounds and shortens
/// the arcs. Mirrors svgo's makeArcs.
fn make_arcs(segments : Array[Segment], options : Options) -> Array[Segment] {
  if !options.make_arcs {
    return segments
  }
  // Only cubics can become arcs, so a path without one costs nothing.
  if !segments.iter().any(s => s.cmd is ('c' | 'C' | 's' | 'S')) {
    return segments
  }
  let p = options.precision
  let error = @num.epsilon(p)
  let threshold = options.make_arcs_threshold
  let tolerance_pct = options.make_arcs_tolerance
  // Convert every segment to relative coordinates so the arc math (which
  // assumes the start point is the origin) is uniform.
  let rel : Array[Segment] = []
  let mut cx = 0.0
  let mut cy = 0.0
  let mut sx = 0.0
  let mut sy = 0.0
  for seg in segments {
    let upper = seg.cmd.to_ascii_uppercase()
    let is_rel = seg.cmd.is_ascii_lowercase()
    let a = seg.args
    match upper {
      'M' => {
        let x = if is_rel { cx + a[0] } else { a[0] }
        let y = if is_rel { cy + a[1] } else { a[1] }
        rel.push({ cmd: 'm', args: [x - cx, y - cy], })
        cx = x
        cy = y
        sx = x
        sy = y
      }
      'Z' => {
        rel.push({ cmd: seg.cmd, args: [], })
        cx = sx
        cy = sy
      }
      'H' => {
        let x = if is_rel { cx + a[0] } else { a[0] }
        rel.push({ cmd: 'h', args: [x - cx], })
        cx = x
      }
      'V' => {
        let y = if is_rel { cy + a[0] } else { a[0] }
        rel.push({ cmd: 'v', args: [y - cy], })
        cy = y
      }
      'L' => {
        let x = if is_rel { cx + a[0] } else { a[0] }
        let y = if is_rel { cy + a[1] } else { a[1] }
        rel.push({ cmd: 'l', args: [x - cx, y - cy], })
        cx = x
        cy = y
      }
      'C' => {
        let out : Array[Double] = []
        for i, v in a {
          let base = if i % 2 == 0 { cx } else { cy }
          out.push(if is_rel { v } else { v - base })
        }
        rel.push({ cmd: 'c', args: out, })
        cx = if is_rel { cx + a[4] } else { a[4] }
        cy = if is_rel { cy + a[5] } else { a[5] }
      }
      'S' => {
        let out : Array[Double] = []
        for i, v in a {
          let base = if i % 2 == 0 { cx } else { cy }
          out.push(if is_rel { v } else { v - base })
        }
        rel.push({ cmd: 's', args: out, })
        cx = if is_rel { cx + a[2] } else { a[2] }
        cy = if is_rel { cy + a[3] } else { a[3] }
      }
      'Q' => {
        let out : Array[Double] = []
        for i, v in a {
          let base = if i % 2 == 0 { cx } else { cy }
          out.push(if is_rel { v } else { v - base })
        }
        rel.push({ cmd: 'q', args: out, })
        cx = if is_rel { cx + a[2] } else { a[2] }
        cy = if is_rel { cy + a[3] } else { a[3] }
      }
      'T' => {
        let out : Array[Double] = []
        for i, v in a {
          let base = if i % 2 == 0 { cx } else { cy }
          out.push(if is_rel { v } else { v - base })
        }
        rel.push({ cmd: 't', args: out, })
        cx = if is_rel { cx + a[0] } else { a[0] }
        cy = if is_rel { cy + a[1] } else { a[1] }
      }
      'A' => {
        let x = if is_rel { cx + a[5] } else { a[5] }
        let y = if is_rel { cy + a[6] } else { a[6] }
        rel.push({
          cmd: 'a',
          args: [a[0], a[1], a[2], a[3], a[4], x - cx, y - cy],
        })
        cx = x
        cy = y
      }
      _ => rel.push(seg)
    }
  }
  // Now scan for arc runs. `out` accumulates the result; when a curve starts
  // an arc we may also pull the previous emitted curve back in if it belongs
  // to the same circle. `prev_arc` holds information about the last emitted
  // arc so a following curve can extend it (svgo's isArcPrev).
  let out : Array[Segment] = []
  // `out` holds the all-relative analysis form; `kept` mirrors it but keeps
  // every non-arc segment exactly as it came in. Relative-izing a segment
  // that no arc consumed would change its rounding and its command kind
  // (`H` becoming `h` breaks the emitter's smooth-shorthand tracking), so
  // only the arcs we actually produce may differ from the input.
  let kept : Array[Segment] = []
  let mut prev_arc : ArcInfo? = None
  let mut i = 0
  while i < rel.length() {
    let seg = rel[i]
    if seg.cmd != 'c' && seg.cmd != 's' {
      out.push(seg)
      kept.push(segments[i])
      prev_arc = None
      i += 1
      continue
    }
    // resolve S to full cubic control points (relative to current point)
    let sdata : Array[Double] = []
    if seg.cmd == 's' {
      // first control point is the reflection of the previous cubic's second
      // control point across the current point. In relative coords that is
      // (end_x - cp2_x, end_y - cp2_y) of the previous curve.
      let prev = if out.length() > 0 {
        out[out.length() - 1]
      } else {
        { cmd: ' ', args: [], }
      }
      let (c1x, c1y) = if prev.cmd == 'c' {
        (prev.args[4] - prev.args[2], prev.args[5] - prev.args[3])
      } else if prev.cmd == 's' {
        (prev.args[2] - prev.args[0], prev.args[3] - prev.args[1])
      } else {
        (0.0, 0.0)
      }
      sdata.push(c1x)
      sdata.push(c1y)
      sdata.push(seg.args[0])
      sdata.push(seg.args[1])
      sdata.push(seg.args[2])
      sdata.push(seg.args[3])
    } else {
      for v in seg.args {
        sdata.push(v)
      }
    }
    if !is_convex(sdata) {
      out.push(seg)
      kept.push(segments[i])
      prev_arc = None
      i += 1
      continue
    }
    let circle = find_circle(sdata, threshold, tolerance_pct, error)
    if circle is None {
      out.push(seg)
      kept.push(segments[i])
      prev_arc = None
      i += 1
      continue
    }
    let circle = circle.unwrap()
    let r = @num.strong_round(circle.r, p)
    let sweep = if sdata[5] * sdata[0] - sdata[4] * sdata[1] > 0.0 {
      1.0
    } else {
      0.0
    }
    // the arc built from the current curve alone
    let mut arc_endx = sdata[4]
    let mut arc_endy = sdata[5]
    let mut large_arc = 0.0
    let mut angle = find_arc_angle(sdata, circle.cx, circle.cy)
    // circle center relative to the arc's running endpoint
    let mut rel_cx = circle.cx - sdata[4]
    let mut rel_cy = circle.cy - sdata[5]
    // collect the curves that make up this arc. Store the original segment
    // (for accurate length comparison, since `s` is shorter than `c`) and
    // the resolved full-cubic sdata (for circle fitting).
    let arc_curves : Array[Segment] = []
    arc_curves.push(seg)
    let arc_sdata : Array[Array[Double]] = []
    arc_sdata.push(sdata)
    // try to merge with the previous emitted curve if it is on the same circle
    let mut has_prev = false
    let prev_seg = if out.length() > 0 {
      out[out.length() - 1]
    } else {
      { cmd: ' ', args: [], }
    }
    let prev_is_curve = prev_seg.cmd == 'c' || prev_seg.cmd == 's'
    let prev_is_arc = prev_seg.cmd == 'a' && prev_arc is Some(_)
    if prev_is_curve || prev_is_arc {
      let prev_sdata : Array[Double] = []
      if prev_is_arc {
        for v in prev_arc.unwrap().sdata {
          prev_sdata.push(v)
        }
      } else if prev_seg.cmd == 's' {
        // the curve before prev_seg provides the reflected control point
        let before = if out.length() >= 2 {
          out[out.length() - 2]
        } else {
          { cmd: ' ', args: [], }
        }
        let (c1x, c1y) = if before.cmd == 'c' {
          (before.args[4] - before.args[2], before.args[5] - before.args[3])
        } else if before.cmd == 's' {
          (before.args[2] - before.args[0], before.args[3] - before.args[1])
        } else {
          (0.0, 0.0)
        }
        prev_sdata.push(c1x)
        prev_sdata.push(c1y)
        prev_sdata.push(prev_seg.args[0])
        prev_sdata.push(prev_seg.args[1])
        prev_sdata.push(prev_seg.args[2])
        prev_sdata.push(prev_seg.args[3])
      } else {
        for v in prev_seg.args {
          prev_sdata.push(v)
        }
      }
      let prev_convex = is_convex(prev_sdata)
      // In svgo, straightCurves runs after makeArcs per item, so a nearly
      // straight curve becomes a line before the next curve's makeArcs sees
      // it. We approximate that by refusing to merge a previous curve whose
      // control points are collinear with its start/end (within the rounding
      // tolerance): svgo would have turned it into a line, and lines can't
      // be merged into arcs.
      let straight_tol = @num.epsilon(p)
      let prev_straight = collinear(
          0.0,
          0.0,
          prev_sdata[4],
          prev_sdata[5],
          prev_sdata[0],
          prev_sdata[1],
          straight_tol,
        ) &&
        collinear(
          0.0,
          0.0,
          prev_sdata[4],
          prev_sdata[5],
          prev_sdata[2],
          prev_sdata[3],
          straight_tol,
        )
      let prev_arc_circle = {
        cx: circle.cx + prev_sdata[4],
        cy: circle.cy + prev_sdata[5],
        r: circle.r,
      }
      let prev_fits = if prev_convex && !prev_straight {
        is_arc(prev_sdata, prev_arc_circle, threshold, tolerance_pct, error)
      } else {
        false
      }
      if prev_convex && prev_fits {
        has_prev = true
        arc_curves.push(prev_seg)
        arc_sdata.push(prev_sdata)
        if prev_is_arc {
          // the previous arc already spans multiple curves; extend it using
          // its stored total endpoint and angle.
          let pa = prev_arc.unwrap()
          arc_endx = pa.endx + sdata[4]
          arc_endy = pa.endy + sdata[5]
          angle = pa.angle + find_arc_angle(sdata, circle.cx, circle.cy)
        } else {
          // the previous segment is a single curve; its endpoint is the
          // arc's start-to-end delta.
          arc_endx = prev_sdata[4] + sdata[4]
          arc_endy = prev_sdata[5] + sdata[5]
          let prev_angle = find_arc_angle(
            prev_sdata,
            circle.cx + prev_sdata[4],
            circle.cy + prev_sdata[5],
          )
          angle += prev_angle
        }
        if angle > @math.PI {
          large_arc = 1.0
        }
        // circle center relative to the new arc's endpoint
        rel_cx = circle.cx - sdata[4]
        rel_cy = circle.cy - sdata[5]
      }
    }
    // look ahead at following curves
    let mut j = i + 1
    let mut full_circle = false
    // When the curve immediately after the arc is an `s` command, its first
    // control point (the reflection of this curve's second CP) must be written
    // explicitly because arcs have no control points. `suffix_len` accounts for
    // those extra characters so the length comparison is fair.
    let mut suffix_len = 0
    while j < rel.length() {
      let next = rel[j]
      if next.cmd != 'c' && next.cmd != 's' {
        break
      }
      let next_sdata : Array[Double] = []
      if next.cmd == 's' {
        let before = rel[j - 1]
        let (c1x, c1y) = if before.cmd == 'c' {
          (before.args[4] - before.args[2], before.args[5] - before.args[3])
        } else if before.cmd == 's' {
          (before.args[2] - before.args[0], before.args[3] - before.args[1])
        } else {
          (0.0, 0.0)
        }
        next_sdata.push(c1x)
        next_sdata.push(c1y)
        next_sdata.push(next.args[0])
        next_sdata.push(next.args[1])
        next_sdata.push(next.args[2])
        next_sdata.push(next.args[3])
        // The suffix is the first control point of this `s` command, which
        // must be written explicitly if the preceding segment is an arc.
        let suffix_seg : Array[Segment] = [{ cmd: 'c', args: [c1x, c1y], }]
        suffix_len = stringify(suffix_seg, precision=p).length()
      } else {
        for v in next.args {
          next_sdata.push(v)
        }
        suffix_len = 0
      }
      if is_convex(next_sdata) &&
        is_arc(
          next_sdata,
          { cx: rel_cx, cy: rel_cy, r: circle.r, },
          threshold,
          tolerance_pct,
          error,
        ) {
        let a = find_arc_angle(next_sdata, rel_cx, rel_cy)
        angle += a
        if angle - 2.0 * @math.PI > 1.0e-3 {
          break
        }
        if angle > @math.PI {
          large_arc = 1.0
        }
        arc_curves.push(next)
        arc_sdata.push(next_sdata)
        if 2.0 * @math.PI - angle > 1.0e-3 {
          arc_endx += next_sdata[4]
          arc_endy += next_sdata[5]
          rel_cx -= next_sdata[4]
          rel_cy -= next_sdata[5]
        } else {
          // full circle: split into two arcs. The first ends at the point
          // opposite the arc's start (which equals the next curve's endpoint
          // for a closed loop), the second closes back to the start.
          let run_endx = arc_endx
          let run_endy = arc_endy
          arc_endx = 2.0 * (rel_cx - next_sdata[4])
          arc_endy = 2.0 * (rel_cy - next_sdata[5])
          // the second arc runs from the first arc's endpoint to the next
          // curve's endpoint (which is the arc's start for a full circle).
          let second_x = run_endx + next_sdata[4] - arc_endx
          let second_y = run_endy + next_sdata[5] - arc_endy
          // build the two-arc output and compare length
          let arcs_len = arc_length(r, large_arc, sweep, arc_endx, arc_endy, p) +
            arc_length(r, 0.0, sweep, second_x, second_y, p) +
            suffix_len
          let curves_len = curves_length(arc_curves, p)
          if arcs_len < curves_len {
            if has_prev {
              ignore(out.pop())
              ignore(kept.pop())
            }
            let first_arc : Segment = {
              cmd: 'a',
              args: [r, r, 0.0, large_arc, sweep, arc_endx, arc_endy],
            }
            let second_arc : Segment = {
              cmd: 'a',
              args: [r, r, 0.0, 0.0, sweep, second_x, second_y],
            }
            out.push(first_arc)
            out.push(second_arc)
            kept.push(first_arc)
            kept.push(second_arc)
            // the second arc continues from the first; store the last curve's
            // sdata and the second arc's endpoint so a following curve can
            // test against the same circle.
            prev_arc = Some({
              sdata: next_sdata,
              endx: second_x,
              endy: second_y,
              angle: 2.0 * @math.PI - angle,
            })
            i = j + 1
            full_circle = true
            break
          } else {
            // not shorter; keep the curves
            out.push(seg)
            kept.push(segments[i])
            prev_arc = None
            i += 1
            break
          }
        }
        j += 1
      } else {
        break
      }
    }
    // single arc (possibly merged with prev and/or following curves).
    // skipped when the full-circle branch already emitted two arcs.
    if !full_circle {
      let arc_len = arc_length(r, large_arc, sweep, arc_endx, arc_endy, p) +
        suffix_len
      let curves_len = curves_length(arc_curves, p)
      if arc_len < curves_len {
        if has_prev {
          ignore(out.pop())
          ignore(kept.pop())
        }
        let arc : Segment = {
          cmd: 'a',
          args: [r, r, 0.0, large_arc, sweep, arc_endx, arc_endy],
        }
        out.push(arc)
        kept.push(arc)
        // Only store the arc's curve data when it is a single curve. For
        // multi-curve arcs the stored sdata would be the first curve's, which
        // is not what isArcPrev needs (it needs the last curve's). This
        // matches svgo, which only sets item.sdata for single-curve arcs.
        if arc_curves.length() == 1 {
          prev_arc = Some({ sdata, endx: arc_endx, endy: arc_endy, angle, })
        } else {
          prev_arc = None
        }
        i += arc_curves.length() - (if has_prev { 1 } else { 0 })
      } else {
        out.push(seg)
        kept.push(segments[i])
        prev_arc = None
        i += 1
      }
    }
  }
  kept
}

///|
/// Total stringified length of a run of curve segments, used to compare
/// against the arc form. The original command (`c` or `s`) is preserved
/// because `s` is shorter than `c`.
fn curves_length(curves : Array[Segment], precision : Int) -> Int {
  stringify(curves, precision~).length()
}

///|
/// Stringified length of a single arc segment.
fn arc_length(
  r : Double,
  large_arc : Double,
  sweep : Double,
  endx : Double,
  endy : Double,
  precision : Int,
) -> Int {
  segment_len(
    { cmd: 'a', args: [r, r, 0.0, large_arc, sweep, endx, endy], },
    precision,
  )
}

///|
/// Optimize path data: convert between absolute/relative, use shorthand
/// commands, drop useless segments and round coordinates. The visual result
/// is preserved up to the configured precision.
pub fn optimize(
  segments : Array[Segment],
  options? : Options = Options::default(),
) -> Array[Segment] {
  let segments = make_arcs(segments, options)
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
  let tolerance = @num.epsilon(p)
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
            em.bx = @num.strong_round(em.bx - last.args[0], p)
            em.by = @num.strong_round(em.by - last.args[1], p)
            em.rsx = @num.strong_round(em.rsx - last.args[0], p)
            em.rsy = @num.strong_round(em.rsy - last.args[1], p)
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
        bsx = @num.strong_round(sx, p)
        bsy = @num.strong_round(sy, p)
        kind = ' '
        ctrl = None
        prev_ctrl = None
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
        let ex = @num.strong_round(a.ex, p)
        let ey = @num.strong_round(a.ey, p)
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
        kind = ' '
        ctrl = None
        prev_ctrl = None
      }
      'C' | 'S' => {
        // resolve the first control point of S from the previous cubic
        let (c1x, c1y, c2x, c2y) = if a.cmd == 'S' {
          // svgo reflects the previous item's last two coordinate pairs as
          // that item stands after earlier rewrites, so a cubic we turned
          // into a `q` still provides the control point (case
          // convertPathData.16), and a cubic we straightened into a line
          // still provides it too because the branch above keeps `ctrl`
          // (svgo does the same through `makeLonghand`, case
          // convertPathData.08). Only the shorthand *spelling* depends on
          // what we emitted, and that is decided further down.
          let (rx, ry) = if prev_orig_kind == 'C' || prev_orig_kind == 'Q' {
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
          let ex = @num.strong_round(a.ex, p)
          let ey = @num.strong_round(a.ey, p)
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
          // quadratic. svgo's formula (in absolute coords):
          //   x1 = 0.75*C1x - 0.25*P0x,  x2 = 0.75*C2x - 0.25*P3x
          //   Qx = x1 + x2 - P0x   (relative Q control point)
          // The curve is a quadratic iff |x1-x2| < 2*error and |y1-y2| < 2*error.
          let rcx = @num.strong_round(cx, p)
          let rcy = @num.strong_round(cy, p)
          let rc1x = @num.strong_round(c1x, p)
          let rc1y = @num.strong_round(c1y, p)
          let rc2x = @num.strong_round(c2x, p)
          let rc2y = @num.strong_round(c2y, p)
          let rex = @num.strong_round(a.ex, p)
          let rey = @num.strong_round(a.ey, p)
          let x1 = 0.75 * rc1x - 0.25 * rcx
          let y1 = 0.75 * rc1y - 0.25 * rcy
          let x2 = 0.75 * rc2x - 0.25 * rex
          let y2 = 0.75 * rc2y - 0.25 * rey
          if (x1 - x2).abs() < 2.0 * tolerance &&
            (y1 - y2).abs() < 2.0 * tolerance {
            let qx = @num.strong_round(x1 + x2 - rcx, p)
            let qy = @num.strong_round(y1 + y2 - rcy, p)
            em.emit(
              'Q',
              [cx + qx, cy + qy, a.ex, a.ey],
              [qx, qy, rel_endx, rel_endy],
              a.ex,
              a.ey,
              cx,
              cy,
            )
            kind = 'Q'
            ctrl = Some((cx + qx, cy + qy))
            prev_ctrl = ctrl
            prev_orig_kind = 'Q'
            prev_kind = 'Q'
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
          let ex = @num.strong_round(a.ex, p)
          let ey = @num.strong_round(a.ey, p)
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
            let r = @num.round_to(rx, p_new)
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
        if @num.strong_round(rx, p) == 0.0 ||
          @num.strong_round(ry, p) == 0.0 ||
          is_straight_arc {
          // the spec says a degenerate arc is a straight line
          let ex = @num.strong_round(a.ex, p)
          let ey = @num.strong_round(a.ey, p)
          if options.remove_useless && ex == em.bx && ey == em.by {
            if options.linecap == "round" || options.linecap == "square" {
              em.emit_line(a, rel_endx, rel_endy, ex, ey, cx, cy)
            }
          } else {
            em.emit_line(a, rel_endx, rel_endy, ex, ey, cx, cy)
          }
        } else {
          let ex = @num.strong_round(a.ex, p)
          let ey = @num.strong_round(a.ey, p)
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
/// Convenience: parse, optimize and stringify path data.
pub fn optimize_string(
  d : String,
  options? : Options = Options::default(),
) -> String raise PathError {
  stringify(optimize(parse(d), options~), precision=options.precision)
}
