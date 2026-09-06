///|
/// Exact powers of ten. Every entry up to 10^22 is exactly representable as a
/// Double, so multiplying or dividing by one of them is a single correctly
/// rounded IEEE operation.
let pow10 : Array[Double] = [
  1.0, 1.0e1, 1.0e2, 1.0e3, 1.0e4, 1.0e5, 1.0e6, 1.0e7, 1.0e8, 1.0e9, 1.0e10, 1.0e11,
  1.0e12, 1.0e13, 1.0e14, 1.0e15, 1.0e16, 1.0e17, 1.0e18, 1.0e19, 1.0e20, 1.0e21,
  1.0e22,
]

///|
let pow10_i64 : Array[Int64] = [
  1, 10, 100, 1000, 10000, 100000, 1000000, 10000000, 100000000, 1000000000, 10000000000,
  100000000000, 1000000000000, 10000000000000, 100000000000000, 1000000000000000,
]

///|
/// Round to `precision` decimal places (0..15; anything larger is identity).
pub fn round_to(v : Double, precision : Int) -> Double {
  if precision >= 15 {
    return v
  }
  let m = pow10[if precision < 0 { 0 } else { precision }]
  let r = @math.round(v * m) / m
  if r == 0.0 {
    0.0
  } else {
    r
  }
}

///|
/// Parse the number in `cu[i:]`; returns the value and the index just past
/// it. Numbers with at most 15 significant digits are decoded exactly with
/// integer arithmetic and one correctly rounded division; longer ones fall
/// back to the general parser.
fn scan_number(
  cu : ArrayView[UInt16],
  i : Int,
) -> (Double, Int) raise PathError {
  let n = cu.length()
  let start = i
  let mut j = i
  let mut neg = false
  if j < n && (cu[j] == 43 || cu[j] == 45) {
    neg = cu[j] == 45
    j += 1
  }
  let mut mantissa : Int64 = 0
  let mut sig = 0 // significant digits folded into `mantissa`
  let mut exp10 = 0 // decimal exponent to apply to `mantissa`
  let mut digits = 0
  while j < n && cu[j] >= 48 && cu[j] <= 57 {
    if sig < 15 {
      mantissa = mantissa * 10 + (cu[j].to_int() - 48).to_int64()
      if mantissa != 0 {
        sig += 1
      }
    } else {
      exp10 += 1
    }
    j += 1
    digits += 1
  }
  if j < n && cu[j] == 46 {
    j += 1
    while j < n && cu[j] >= 48 && cu[j] <= 57 {
      if sig < 15 {
        mantissa = mantissa * 10 + (cu[j].to_int() - 48).to_int64()
        if mantissa != 0 {
          sig += 1
        }
        exp10 -= 1
      }
      j += 1
      digits += 1
    }
  }
  guard digits > 0 else { raise PathError("expected number at \{start}") }
  if j < n && (cu[j] == 101 || cu[j] == 69) {
    let mut k = j + 1
    let mut eneg = false
    if k < n && (cu[k] == 43 || cu[k] == 45) {
      eneg = cu[k] == 45
      k += 1
    }
    if k < n && cu[k] >= 48 && cu[k] <= 57 {
      let mut e = 0
      while k < n && cu[k] >= 48 && cu[k] <= 57 {
        if e < 10000 {
          e = e * 10 + (cu[k].to_int() - 48)
        }
        k += 1
      }
      exp10 += if eneg { -e } else { e }
      j = k
    }
  }
  let v = if mantissa == 0 {
    0.0
  } else if exp10 == 0 {
    mantissa.to_double()
  } else if exp10 < 0 && exp10 >= -22 {
    mantissa.to_double() / pow10[-exp10]
  } else if exp10 > 0 && exp10 <= 22 {
    mantissa.to_double() * pow10[exp10]
  } else {
    let text = String::from_iter(
      cu[start:j].iter().map(u => u.to_int().unsafe_to_char()),
    )
    @string.parse_double(text) catch {
      _ => raise PathError("bad number '\{text}'")
    }
  }
  (if neg { -v } else { v }, j)
}

///|
/// Decompose `v` rounded to `precision` places into sign, integer part and
/// fraction digits (`frac` scaled by 10^frac_len, trailing zeros removed).
/// Returns (neg, int_part, frac, frac_len); (false, 0, 0, 0) for 0, NaN, inf.
fn decompose(v : Double, precision : Int) -> (Bool, Int64, Int64, Int) {
  if v.is_nan() || v.is_inf() {
    return (false, 0, 0, 0)
  }
  let p = if precision < 0 {
    0
  } else if precision > 15 {
    15
  } else {
    precision
  }
  let av = v.abs()
  if av >= 9.0e15 {
    // beyond exact Int64 scaling; integers only at this magnitude
    return (v < 0.0, av.to_int64(), 0, 0)
  }
  let scaled = @math.round(av * pow10[p]).to_int64()
  if scaled == 0 {
    return (false, 0, 0, 0)
  }
  let m = pow10_i64[p]
  let int_part = scaled / m
  let mut frac = scaled % m
  let mut frac_len = p
  while frac_len > 0 && frac % 10 == 0 {
    frac = frac / 10
    frac_len -= 1
  }
  if frac == 0 {
    frac_len = 0
  }
  (v < 0.0, int_part, frac, frac_len)
}

///|
fn digits_of(v : Int64) -> Int {
  let mut n = 1
  let mut v = v
  while v >= 10 {
    v = v / 10
    n += 1
  }
  n
}

///|
/// Shortest decimal representation of a number for path data:
/// no trailing zeros, no leading zero before the decimal point.
pub fn format_number(v : Double, precision : Int) -> String {
  let sb = StringBuilder()
  write_number(sb, v, precision)
  sb.to_string()
}

///|
/// Append `format_number(v, precision)` to `sb` without intermediate strings.
pub fn write_number(sb : StringBuilder, v : Double, precision : Int) -> Unit {
  let (neg, int_part, frac, frac_len) = decompose(v, precision)
  if int_part == 0 && frac == 0 {
    sb.write_char('0')
    return
  }
  if neg {
    sb.write_char('-')
  }
  if int_part != 0 {
    sb.write_string(int_part.to_string())
  }
  if frac != 0 {
    sb.write_char('.')
    for _ in digits_of(frac)..<frac_len {
      sb.write_char('0')
    }
    sb.write_string(frac.to_string())
  }
}

///|
/// Shape of a formatted number packed into an Int, so callers can measure
/// output without building strings: bits 0..1 flags, bit 2.. length.
/// flag 1: starts with '-', flag 2: starts with '.', (a '.' is present iff
/// bit 2 is set or the number starts with '.').
fn number_shape(v : Double, precision : Int) -> Int {
  let (neg, int_part, frac, frac_len) = decompose(v, precision)
  if int_part == 0 && frac == 0 {
    return 1 << 3
  }
  let mut len = 0
  let mut flags = 0
  if neg {
    len += 1
    flags = flags | 1
  }
  if int_part != 0 {
    len += digits_of(int_part)
  } else if !neg {
    flags = flags | 2
  }
  if frac != 0 {
    len += 1 + frac_len
    flags = flags | 4
  }
  (len << 3) | flags
}

///|
/// Length of `stringify([seg])`: the command letter plus its arguments with
/// the same separator rules as `stringify`.
pub fn segment_len(seg : Segment, precision : Int) -> Int {
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
      let shape = number_shape(a, precision)
      let starts_neg = (shape & 1) != 0 && !prev_was_flag
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
