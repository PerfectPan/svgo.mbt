///|
/// One path segment. `cmd` is the command letter as written (absolute when
/// uppercase), `args` the numeric arguments of exactly one command instance.
pub(all) struct Segment {
  cmd : Char
  args : Array[Double]
} derive(Debug, Eq)

///|
/// Malformed path data: a number or command was expected at the given offset.
pub suberror PathError {
  PathError(String)
} derive(Debug)

///|
pub impl Show for PathError with fn output(self, logger) {
  match self {
    PathError(m) => logger.write_string(m)
  }
}

///|
fn arg_count(cmd : Char) -> Int {
  match cmd.to_ascii_lowercase() {
    'm' | 'l' | 't' => 2
    'h' | 'v' => 1
    'c' => 6
    's' | 'q' => 4
    'a' => 7
    'z' => 0
    _ => -1
  }
}

///|
/// Parse path data. Implicit command repetition is expanded into separate
/// segments (`M 1 2 3 4` becomes `M1 2` followed by `L3 4`).
pub fn parse(d : String) -> Array[Segment] raise PathError {
  let out : Array[Segment] = []
  parse_into(out, d)
  out
}

///|
/// Like `parse`, but keeps the segments read before the first error instead
/// of failing: browsers and svgo render a path up to its first invalid token.
/// With `until_drawing`, parsing also stops after the first segment that
/// draws something (see `is_drawing_command`), which is all a caller needs to
/// tell an empty or single-point path from a visible one without reading the
/// whole string.
pub fn parse_prefix(
  d : String,
  until_drawing? : Bool = false,
) -> Array[Segment] {
  let out : Array[Segment] = []
  parse_into(out, d, until_drawing~) catch {
    _ => ()
  }
  out
}

///|
/// True for the commands that produce geometry (`L H V C S Q T A` in either
/// case); `M` and `Z` alone leave a path invisible.
pub fn is_drawing_command(cmd : Char) -> Bool {
  match cmd.to_ascii_lowercase() {
    'l' | 'h' | 'v' | 'c' | 's' | 'q' | 't' | 'a' => true
    _ => false
  }
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
        let (v, ni) = scan_number(cu, i)
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
/// Serialize segments to the shortest valid path data string.
pub fn stringify(segments : Array[Segment], precision? : Int = 3) -> String {
  let sb = StringBuilder()
  write_path(sb, segments, precision)
  sb.to_string()
}

///|
/// Append the path data for `segments` to `sb`.
pub fn write_path(
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
        let (neg, int_part, frac, _) = decompose(a, precision)
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
      prev_shape = write_number_shaped(sb, a, precision)
      prev_was_flag = false
    }
    prev_cmd = cmd
  }
}
