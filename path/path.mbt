///|
/// One path segment. `cmd` is the command letter as written (absolute when
/// uppercase), `args` the numeric arguments of exactly one command instance.
pub(all) struct Segment {
  cmd : Char
  args : Array[Double]
} derive(Debug, Eq)

///|
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
  // read a number starting at i; returns (value, new index)
  fn number(i : Int, flag : Bool) -> (Double, Int) raise PathError {
    let start = i
    let mut j = i
    if flag {
      // arc flags are single digits that may be glued together: "10" is two flags
      guard j < n && (cu[j] == 48 || cu[j] == 49) else {
        raise PathError("expected arc flag at \{j}")
      }
      return ((cu[j].to_int() - 48).to_double(), j + 1)
    }
    if j < n && (cu[j] == 43 || cu[j] == 45) {
      j += 1
    }
    let mut digits = 0
    while j < n && cu[j] >= 48 && cu[j] <= 57 {
      j += 1
      digits += 1
    }
    if j < n && cu[j] == 46 {
      j += 1
      while j < n && cu[j] >= 48 && cu[j] <= 57 {
        j += 1
        digits += 1
      }
    }
    guard digits > 0 else { raise PathError("expected number at \{start}") }
    if j < n && (cu[j] == 101 || cu[j] == 69) {
      let mut k = j + 1
      if k < n && (cu[k] == 43 || cu[k] == 45) {
        k += 1
      }
      if k < n && cu[k] >= 48 && cu[k] <= 57 {
        while k < n && cu[k] >= 48 && cu[k] <= 57 {
          k += 1
        }
        j = k
      }
    }
    let text = String::from_iter(
      cu[start:j].iter().map(u => u.to_int().unsafe_to_char()),
    )
    let v = @string.parse_double(text) catch {
      _ => raise PathError("bad number '\{text}'")
    }
    (v, j)
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
      let (v, ni) = number(i, is_flag)
      args.push(v)
      i = skip(ni)
    }
    out.push({ cmd, args, })
  }
  out
}

///|
/// Round to `precision` decimal places.
pub fn round_to(v : Double, precision : Int) -> Double {
  if precision >= 15 {
    return v
  }
  let m = @math.pow(10.0, precision.to_double())
  let r = @math.round(v * m) / m
  if r == 0.0 {
    0.0
  } else {
    r
  }
}

///|
/// Shortest decimal representation of a number for path data:
/// no trailing zeros, no leading zero before the decimal point.
pub fn format_number(v : Double, precision : Int) -> String {
  let v = round_to(v, precision)
  if v.is_nan() || v.is_inf() {
    return "0"
  }
  if v == v.trunc() && v.abs() < 1.0e15 {
    return v.to_int64().to_string()
  }
  let neg = v < 0.0
  let av = v.abs()
  // fixed notation with `precision` decimals, then strip trailing zeros
  let m = @math.pow(10.0, precision.to_double())
  let scaled = @math.round(av * m).to_int64()
  let int_part = scaled / m.to_int64()
  let frac_part = scaled % m.to_int64()
  let mut frac = frac_part.to_string().pad_start(precision, '0')
  let mut end = frac.length()
  while end > 0 && frac.get_char(end - 1) == Some('0') {
    end -= 1
  }
  frac = frac[:end].to_owned()
  let sb = StringBuilder()
  if neg {
    sb.write_char('-')
  }
  if int_part != 0 {
    sb.write_string(int_part.to_string())
  }
  if frac.length() > 0 {
    sb.write_char('.')
    sb.write_string(frac)
  } else if int_part == 0 {
    sb.write_char('0')
  }
  sb.to_string()
}

///|
/// Serialize segments to the shortest valid path data string.
pub fn stringify(segments : Array[Segment], precision? : Int = 3) -> String {
  let sb = StringBuilder()
  let mut prev_cmd : Char = ' '
  // last number written in the current command, "" right after a command letter
  let mut prev_num = ""
  let mut prev_was_flag = false
  for seg in segments {
    let cmd = seg.cmd
    // implicit repetition saves the command letter; `M x y L` pairs use it too
    let implicit = (
        cmd == prev_cmd && cmd != 'M' && cmd != 'm' && cmd != 'z' && cmd != 'Z'
      ) ||
      (prev_cmd == 'M' && cmd == 'L') ||
      (prev_cmd == 'm' && cmd == 'l')
    if !implicit {
      sb.write_char(cmd)
      prev_num = ""
      prev_was_flag = false
    }
    let is_arc = cmd == 'a' || cmd == 'A'
    for k, a in seg.args {
      let is_flag = is_arc && (k == 3 || k == 4)
      let s = if is_flag {
        if a != 0.0 {
          "1"
        } else {
          "0"
        }
      } else {
        format_number(a, precision)
      }
      if prev_num.length() > 0 {
        // a separator is needed unless the number starts with '-', or starts
        // with '.' after a number that already has a '.'. Arc flags are always
        // separated: gluing them is valid but trips up older renderers.
        let starts_neg = s.has_prefix("-") && !prev_was_flag
        let starts_dot = s.has_prefix(".") &&
          prev_num.contains(".") &&
          !prev_num.contains("e") &&
          !prev_was_flag
        if !(starts_neg || starts_dot) {
          sb.write_char(' ')
        }
      }
      sb.write_string(s)
      prev_num = s
      prev_was_flag = is_flag
    }
    prev_cmd = cmd
  }
  sb.to_string()
}
