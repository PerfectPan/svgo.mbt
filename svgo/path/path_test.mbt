///|
test "parse expands implicit repetition and arc flags" {
  let segs = @path.parse("M 1,2 3 4 h5v-6 a1 1 0 011 1 z")
  debug_inspect(
    segs.map(s => (s.cmd, s.args)),
    content=(
      #|[
      #|  ('M', [1, 2]),
      #|  ('L', [3, 4]),
      #|  ('h', [5]),
      #|  ('v', [-6]),
      #|  ('a', [1, 1, 0, 0, 1, 1, 1]),
      #|  ('z', []),
      #|]
    ),
  )
  inspect(
    @path.parse("M1e2.5.5-1-1-2z").map(s => (s.cmd, s.args)).length(),
    content="4",
  )
}

///|
test "number formatting" {
  inspect(@path.format_number(0.5, 3), content=".5")
  inspect(@path.format_number(-0.5, 3), content="-.5")
  inspect(@path.format_number(10.0, 3), content="10")
  inspect(@path.format_number(1.23456, 3), content="1.235")
  inspect(@path.format_number(1.0004, 3), content="1")
  inspect(@path.format_number(-0.0004, 3), content="0")
  inspect(@path.format_number(100.10, 2), content="100.1")
}

///|
test "stringify is compact" {
  let segs = @path.parse("M 10 10 L 20 20 L 30 -5 L 0.5 0.5 a 1 1 0 0 1 2 2")
  inspect(@path.stringify(segs), content="M10 10 20 20 30-5 .5.5a1 1 0 0 1 2 2")
}

///|
test "optimize typical editor output" {
  // Sketch-style export: absolute coordinates with 6 decimals
  inspect(
    @path.optimize_string(
      "M 6.000000,6.000000 L 18.000000,18.000000 M 18.000000,6.000000 L 6.000000,18.000000",
    ),
    content=(
      #|m6 6 12 12m0-12L6 18
    ),
  )
  // lineto back to start before Z is dropped, H/V used for axis aligned lines
  inspect(
    @path.optimize_string("M10 10 L 20 10 L 20 20 L 10 20 L 10 10 Z"),
    content="M10 10h10v10H10z",
  )
  // curves whose control points mirror become S, straight curves become lines
  inspect(
    @path.optimize_string("M0 0 C 10 10 20 10 30 0 C 40 -10 50 -10 60 0"),
    content="M0 0q15 15 30 0 15-15 30 0",
  )
  inspect(
    @path.optimize_string("M0 0 C 1 1 2 2 3 3"),
    content=(
      #|m0 0 3 3
    ),
  )
  inspect(
    @path.optimize_string("M0 0 Q 5 5 10 10 T 20 20"),
    content=(
      #|m0 0 10 10 10 10
    ),
  )
  // zero length segments and empty subpaths are removed
  inspect(
    @path.optimize_string("M1 1 L1 1 L2 2 M5 5 M6 6 L7 7 M9 9"),
    content=(
      #|m1 1 1 1m4 4 1 1m2 2
    ),
  )
  // rounding keeps absolute positions from drifting
  inspect(
    @path.optimize_string(
      "M0 0 l 0.3333 0 l 0.3333 0 l 0.3333 0 l 0.3333 0 l 0.3333 0 l 0.3333 0",
      options={ ..@path.Options::default(), precision: 1, },
    ),
    content=(
      #|M0 0h2
    ),
  )
}

///|
test "H/V widened to L when the rounded cursor drifts from the exact one" {
  // After `v0.0715` the emitter's rounded y (.194) differs from round(0.195)
  // = .195, so the `h6` is no longer horizontal in rounded space and must be
  // emitted as a line with both deltas. This used to panic in `emit` because
  // the `H` carried a single relative argument.
  inspect(
    @path.optimize_string("M0 0.1235v0.0715h6"),
    content="M0 .124v.07l6 .001",
  )
  inspect(
    @path.optimize_string("M0.1235 0h0.0715v6"),
    content="M.124 0h.07l.001 6",
  )
}

///|
test "makeArcs turns a circular cubic run into an arc" {
  // Three cubics that trace one circle of r = 6.43 (svgo's own
  // convertPathData fixture 15). At precision 2 the arc form is shorter, so
  // the first two curves collapse into a single `A` and the third, which
  // leaves the circle, stays a curve.
  inspect(
    @path.optimize_string(
      "M.49 8.8c-.3-.75-.44-1.55-.44-2.35 0-3.54 2.88-6.43 6.43-6.43 3.53 0 6.42 2.88 6.42 6.43 0 .8-.15 1.6-.43 2.35",
      options={ ..@path.Options::default(), precision: 2, },
    ),
    content="M.49 8.8A6.44 6.44 0 0 1 6.48.02a6.44 6.44 0 0 1 5.99 8.78",
  )
  // The same path with one control point moved off the circle (2.88 -> 8.42):
  // the fit fails, so that run keeps its curves.
  inspect(
    @path.optimize_string(
      "M.49 8.8c-.3-.75-.44-1.55-.44-2.35 0-3.54 2.88-6.43 6.43-6.43 3.53 0 8.42 2.88 6.42 6.43 0 .8-.15 1.6-.43 2.35",
      options={ ..@path.Options::default(), precision: 2, },
    ),
    content="M.49 8.8A6.44 6.44 0 0 1 6.48.02c3.53 0 8.42 2.88 6.42 6.43q0 1.21-.43 2.35",
  )
  // makeArcs off leaves every curve alone.
  inspect(
    @path.optimize_string(
      "M.49 8.8c-.3-.75-.44-1.55-.44-2.35 0-3.54 2.88-6.43 6.43-6.43 3.53 0 6.42 2.88 6.42 6.43 0 .8-.15 1.6-.43 2.35",
      options={ ..@path.Options::default(), precision: 2, make_arcs: false, },
    ),
    content="M.49 8.8Q.05 7.66.05 6.45C.05 2.91 2.93.02 6.48.02c3.53 0 6.42 2.88 6.42 6.43q0 1.21-.43 2.35",
  )
}

///|
test "arcs" {
  inspect(
    @path.optimize_string("M 5 5 A 5 5 0 1 1 15 5 A 5 5 0 1 1 5 5 Z"),
    content=(
      #|M5 5a5 5 0 1 1 10 0A5 5 0 1 1 5 5
    ),
  )
  // degenerate arc is a line
  inspect(
    @path.optimize_string("M0 0 A 0 5 0 0 0 10 10"),
    content=(
      #|m0 0 10 10
    ),
  )
}

///|
test "errors" {
  for bad in ["10 10", "M 1", "M1 1 a 1 1 0 2 0 1 1", "M x"] {
    try @path.parse(bad) catch {
      e => println("\{bad} -> \{e}")
    } noraise {
      _ => fail("expected error for \{bad}")
    }
  }
}

///|
test "numbers beyond the exact fast path keep their sign" {
  // 17 significant digits fall back to the general parser; the sign is
  // applied once, after it.
  let segs = @path.parse("M-0.30000000000000004 1.2345678901234567e5")
  debug_inspect(
    segs[0].args,
    content=(
      #|[-0.30000000000000004, 123456.78901234567]
    ),
  )
}

///|
test "parse_number accepts exactly one number" {
  debug_inspect(
    @path.parse_number("1e+21"),
    content=(
      #|Some(1e+21)
    ),
  )
  debug_inspect(
    @path.parse_number("-.5"),
    content=(
      #|Some(-0.5)
    ),
  )
  debug_inspect(
    @path.parse_number(" 1"),
    content=(
      #|None
    ),
  )
  debug_inspect(
    @path.parse_number("1px"),
    content=(
      #|None
    ),
  )
  debug_inspect(
    @path.parse_number(""),
    content=(
      #|None
    ),
  )
}

///|
test "epsilon is the correctly rounded power of ten" {
  inspect(@path.epsilon(3), content="0.001")
  inspect(@path.epsilon(4), content="0.0001")
  inspect(@path.epsilon(5), content="0.00001")
  inspect(@path.epsilon(0), content="1")
}
