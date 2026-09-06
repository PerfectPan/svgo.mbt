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
    content="M6 6l12 12M18 6 6 18",
  )
  // lineto back to start before Z is dropped, H/V used for axis aligned lines
  inspect(
    @path.optimize_string("M10 10 L 20 10 L 20 20 L 10 20 L 10 10 Z"),
    content="M10 10h10v10H10z",
  )
  // curves whose control points mirror become S, straight curves become lines
  inspect(
    @path.optimize_string("M0 0 C 10 10 20 10 30 0 C 40 -10 50 -10 60 0"),
    content="M0 0c10 10 20 10 30 0s20-10 30 0",
  )
  inspect(@path.optimize_string("M0 0 C 1 1 2 2 3 3"), content="M0 0l3 3")
  inspect(
    @path.optimize_string("M0 0 Q 5 5 10 10 T 20 20"),
    content=(
      #|M0 0l10 10 10 10
    ),
  )
  // zero length segments and empty subpaths are removed
  inspect(
    @path.optimize_string("M1 1 L1 1 L2 2 M5 5 M6 6 L7 7 M9 9"),
    content=(
      #|M1 1l1 1M6 6l1 1
    ),
  )
  // rounding keeps absolute positions from drifting
  inspect(
    @path.optimize_string(
      "M0 0 l 0.3333 0 l 0.3333 0 l 0.3333 0 l 0.3333 0 l 0.3333 0 l 0.3333 0",
      options={ ..@path.Options::default(), precision: 1, },
    ),
    content=(
      #|M0 0h.3.4H1h.3.4H2
    ),
  )
}

///|
test "arcs" {
  inspect(
    @path.optimize_string("M 5 5 A 5 5 0 1 1 15 5 A 5 5 0 1 1 5 5 Z"),
    content="M5 5a5 5 0 1 1 10 0A5 5 0 1 1 5 5z",
  )
  // degenerate arc is a line
  inspect(@path.optimize_string("M0 0 A 0 5 0 0 0 10 10"), content="M0 0l10 10")
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
