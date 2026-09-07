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
/// svgo's "strong" rounding: round to `precision` places, but if the value is
/// within `10^-precision` of a `precision-1`-place boundary, snap to that
/// boundary. This kills near-zero values like 0.0005 (at precision 3 → 0)
/// instead of writing them as 0.001.
pub fn strong_round(v : Double, precision : Int) -> Double {
  if precision <= 0 {
    return round_to(v, precision)
  }
  let fixed = round_to(v, precision)
  if fixed == v {
    v
  } else {
    let rounded = round_to(v, precision - 1)
    let error = 1.0 / pow10[precision]
    if round_to((rounded - v).abs(), precision + 1) >= error {
      fixed
    } else {
      rounded
    }
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
  ignore(write_number_shaped(sb, v, precision))
}

///|
fn write_digits(sb : StringBuilder, v : Int64) -> Unit {
  if v >= 10 {
    write_digits(sb, v / 10)
  }
  sb.write_char(((v % 10).to_int() + 48).unsafe_to_char())
}

///|
/// Write the number and return its shape (see `number_shape`) in one pass.
fn write_number_shaped(sb : StringBuilder, v : Double, precision : Int) -> Int {
  let (neg, int_part, frac, frac_len) = decompose(v, precision)
  if int_part == 0 && frac == 0 {
    sb.write_char('0')
    return 1 << 3
  }
  // For small numbers (int_part == 0) check whether scientific notation is
  // shorter than the decimal form, e.g. 1e-7 vs .0000001.
  if int_part == 0 && frac > 0 {
    let mant_digits = digits_of(frac)
    let exponent = mant_digits - frac_len - 1 // negative for values < 1
    let mant_len = if mant_digits == 1 { mant_digits } else { mant_digits + 1 }
    let sci_len = mant_len + 1 + 1 + digits_of(exponent.abs().to_int64())
    let dec_len = 1 + frac_len
    if sci_len < dec_len {
      let mut len = 0
      let mut flags = 0
      if neg {
        sb.write_char('-')
        len += 1
        flags = flags | 1
      }
      // mantissa: first digit, then a dot and the rest if more than one digit
      let mut pow : Int64 = 1
      for _ in 1..<mant_digits {
        pow = pow * 10
      }
      let first = frac / pow
      sb.write_char((first.to_int() + 48).unsafe_to_char())
      len += 1
      if mant_digits > 1 {
        sb.write_char('.')
        len += 1
        flags = flags | 4
        write_digits(sb, frac % pow)
        len += mant_digits - 1
      }
      sb.write_char('e')
      len += 1
      if exponent < 0 {
        sb.write_char('-')
      } else {
        sb.write_char('+')
      }
      len += 1
      write_digits(sb, exponent.abs().to_int64())
      len += digits_of(exponent.abs().to_int64())
      return (len << 3) | flags
    }
  }
  let mut len = 0
  let mut flags = 0
  if neg {
    sb.write_char('-')
    len += 1
    flags = flags | 1
  }
  if int_part != 0 {
    write_digits(sb, int_part)
    len += digits_of(int_part)
  } else if !neg {
    flags = flags | 2
  }
  if frac != 0 {
    sb.write_char('.')
    for _ in digits_of(frac)..<frac_len {
      sb.write_char('0')
    }
    write_digits(sb, frac)
    len += 1 + frac_len
    flags = flags | 4
  }
  (len << 3) | flags
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
  if int_part == 0 && frac > 0 {
    let mant_digits = digits_of(frac)
    let exponent = mant_digits - frac_len - 1
    let mant_len = if mant_digits == 1 { mant_digits } else { mant_digits + 1 }
    let sci_len = mant_len + 1 + 1 + digits_of(exponent.abs().to_int64())
    let dec_len = 1 + frac_len
    if sci_len < dec_len {
      let mut len = sci_len
      let mut flags = 0
      if neg {
        len += 1
        flags = flags | 1
      }
      if mant_digits > 1 {
        flags = flags | 4
      }
      return (len << 3) | flags
    }
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
