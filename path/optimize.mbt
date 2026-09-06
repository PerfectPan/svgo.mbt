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
  /// use `S`/`T` when a control point mirrors the previous one
  smooth_shorthands : Bool
} derive(Debug)

///|
/// Precision 3 with every rewrite enabled.
pub fn Options::default() -> Options {
  {
    precision: 3,
    utilize_absolute: true,
    remove_useless: true,
    straight_curves: true,
    smooth_shorthands: true,
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
  let dist = ((dy * px - dx * py + bx * ay - by * ax) / len).abs()
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
  let rel_args : Array[Double] = []
  match cmd {
    'H' => rel_args.push(round_to(abs_args[0] - self.bx, p))
    'V' => rel_args.push(round_to(abs_args[0] - self.by, p))
    'A' => {
      for i in 0..<5 {
        rel_args.push(abs_args[i])
      }
      rel_args.push(round_to(abs_args[5] - self.bx, p))
      rel_args.push(round_to(abs_args[6] - self.by, p))
    }
    _ =>
      for i, v in abs_args {
        rel_args.push(
          round_to(v - (if i % 2 == 0 { self.bx } else { self.by }), p),
        )
      }
  }
  let abs_rounded = abs_args.map(v => round_to(v, p))
  let rel_seg : Segment = { cmd: cmd.to_ascii_lowercase(), args: rel_args, }
  let abs_seg : Segment = { cmd, args: abs_rounded, }
  let abs_len = self.seg_len(abs_seg)
  let rel_len = self.seg_len(rel_seg)
  // the first command must be absolute; movetos prefer absolute on ties
  let first = self.out.length() == 0
  let use_abs = first ||
    (
      self.options.utilize_absolute &&
      (abs_len < rel_len || (cmd == 'M' && abs_len == rel_len))
    )
  if use_abs {
    self.out.push(abs_seg)
    self.bx = round_to(ex, p)
    self.by = round_to(ey, p)
  } else {
    self.out.push(rel_seg)
    // the consumer adds the rounded relative offsets to its current point
    match cmd {
      'H' => self.bx = round_to(self.bx + rel_args[0], p)
      'V' => self.by = round_to(self.by + rel_args[0], p)
      'A' => {
        self.bx = round_to(self.bx + rel_args[5], p)
        self.by = round_to(self.by + rel_args[6], p)
      }
      _ => {
        let n = rel_args.length()
        self.bx = round_to(self.bx + rel_args[n - 2], p)
        self.by = round_to(self.by + rel_args[n - 1], p)
      }
    }
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
  let em : Emitter = { out: [], options, bx: 0.0, by: 0.0, }
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
  let tolerance = @math.pow(10.0, -p.to_double()) / 2.0
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
            em.bx = round_to(em.bx - last.args[0], p)
            em.by = round_to(em.by - last.args[1], p)
          } else {
            em.bx = bsx
            em.by = bsy
          }
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
        let last_cmd = if em.out.length() > 0 {
          em.out[em.out.length() - 1].cmd
        } else {
          ' '
        }
        if !(last_cmd == 'z' ||
          last_cmd == 'Z' ||
          last_cmd == 'm' ||
          last_cmd == 'M') {
          em.out.push({ cmd: 'z', args: [], })
        }
        em.bx = bsx
        em.by = bsy
        // Z resets the current point; an implicit M would follow
        cx = sx
        cy = sy
        prev_ctrl = None
        prev_kind = ' '
        continue
      }
      'L' | 'H' | 'V' => {
        let ex = round_to(a.ex, p)
        let ey = round_to(a.ey, p)
        if options.remove_useless && ex == em.bx && ey == em.by {
          // zero-length segment
          cx = a.ex
          cy = a.ey
          prev_ctrl = None
          prev_kind = ' '
          continue
        }
        if ey == em.by {
          em.emit('H', [a.ex], a.ex, a.ey)
        } else if ex == em.bx {
          em.emit('V', [a.ey], a.ex, a.ey)
        } else {
          em.emit('L', [a.ex, a.ey], a.ex, a.ey)
        }
      }
      'C' | 'S' => {
        // resolve the first control point of S from the previous curve
        let (c1x, c1y, c2x, c2y) = if a.cmd == 'S' {
          let (rx, ry) = match (prev_kind, prev_ctrl) {
            ('C', Some((px, py))) => (2.0 * cx - px, 2.0 * cy - py)
            _ => (cx, cy)
          }
          (rx, ry, a.args[0], a.args[1])
        } else {
          (a.args[0], a.args[1], a.args[2], a.args[3])
        }
        if options.straight_curves &&
          collinear(cx, cy, a.ex, a.ey, c1x, c1y, tolerance) &&
          collinear(cx, cy, a.ex, a.ey, c2x, c2y, tolerance) {
          let ex = round_to(a.ex, p)
          let ey = round_to(a.ey, p)
          if options.remove_useless && ex == em.bx && ey == em.by {
            cx = a.ex
            cy = a.ey
            prev_ctrl = None
            prev_kind = ' '
            continue
          }
          if ey == em.by {
            em.emit('H', [a.ex], a.ex, a.ey)
          } else if ex == em.bx {
            em.emit('V', [a.ey], a.ex, a.ey)
          } else {
            em.emit('L', [a.ex, a.ey], a.ex, a.ey)
          }
        } else {
          let (mx, my) = match (prev_kind, prev_ctrl) {
            ('C', Some((px, py))) => (2.0 * cx - px, 2.0 * cy - py)
            _ => (cx, cy)
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
          match (prev_kind, prev_ctrl) {
            ('Q', Some((px, py))) => (2.0 * cx - px, 2.0 * cy - py)
            _ => (cx, cy)
          }
        } else {
          (a.args[0], a.args[1])
        }
        if options.straight_curves &&
          collinear(cx, cy, a.ex, a.ey, qx, qy, tolerance) {
          let ex = round_to(a.ex, p)
          let ey = round_to(a.ey, p)
          if options.remove_useless && ex == em.bx && ey == em.by {
            cx = a.ex
            cy = a.ey
            prev_ctrl = None
            prev_kind = ' '
            continue
          }
          if ey == em.by {
            em.emit('H', [a.ex], a.ex, a.ey)
          } else if ex == em.bx {
            em.emit('V', [a.ey], a.ex, a.ey)
          } else {
            em.emit('L', [a.ex, a.ey], a.ex, a.ey)
          }
        } else {
          let (mx, my) = match (prev_kind, prev_ctrl) {
            ('Q', Some((px, py))) => (2.0 * cx - px, 2.0 * cy - py)
            _ => (cx, cy)
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
        let rx = a.args[0]
        let ry = a.args[1]
        if round_to(rx, p) == 0.0 || round_to(ry, p) == 0.0 {
          // the spec says a degenerate arc is a straight line
          let ex = round_to(a.ex, p)
          let ey = round_to(a.ey, p)
          if !(options.remove_useless && ex == em.bx && ey == em.by) {
            em.emit('L', [a.ex, a.ey], a.ex, a.ey)
          }
        } else {
          let ex = round_to(a.ex, p)
          let ey = round_to(a.ey, p)
          if options.remove_useless && ex == em.bx && ey == em.by {
            cx = a.ex
            cy = a.ey
            prev_ctrl = None
            prev_kind = ' '
            continue
          }
          em.emit(
            'A',
            [rx.abs(), ry.abs(), a.args[2], a.args[3], a.args[4], a.ex, a.ey],
            a.ex,
            a.ey,
          )
        }
      }
      _ => ()
    }
    cx = a.ex
    cy = a.ey
    prev_ctrl = ctrl
    prev_kind = kind
  }
  // a trailing M draws nothing
  if options.remove_useless {
    while em.out.length() > 0 &&
          em.out[em.out.length() - 1].cmd.to_ascii_lowercase() == 'm' {
      ignore(em.out.pop())
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
