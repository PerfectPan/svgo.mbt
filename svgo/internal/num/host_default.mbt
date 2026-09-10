// On the js and native targets the transcendentals are core's, which resolve
// to `Math` and libm respectively. See host_wasm.mbt for the wasm-gc build.

///|
pub fn sin(x : Double) -> Double {
  @math.sin(x)
}

///|
pub fn cos(x : Double) -> Double {
  @math.cos(x)
}

///|
pub fn tan(x : Double) -> Double {
  @math.tan(x)
}

///|
pub fn asin(x : Double) -> Double {
  @math.asin(x)
}

///|
pub fn acos(x : Double) -> Double {
  @math.acos(x)
}

///|
pub fn atan(x : Double) -> Double {
  @math.atan(x)
}

///|
/// Correctly rounded conversion for numbers `scan_number` cannot decode
/// exactly on its own; None when `s` is not a number.
fn parse_double_slow(s : String) -> Double? {
  Some(@string.parse_double(s)) catch {
    _ => None
  }
}
