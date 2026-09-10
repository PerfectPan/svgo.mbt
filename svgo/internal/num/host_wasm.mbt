// The wasm-gc build takes its transcendentals and the slow path of number
// parsing from the embedder. V8's `Math` is the same fdlibm port the js build
// already uses through core, and importing it keeps MoonBit's own
// implementations (about 10 KB after wasm-opt) out of the artifact.
// packages/svgo-mbt/index.mjs supplies the `Math` and `Number` import objects.
// moonrun provides neither, so `moon test` runs on the js and native targets;
// the artifact itself is exercised by `node --test` in packages/svgo-mbt.

///|
pub fn sin(x : Double) -> Double = "Math" "sin"

///|
pub fn cos(x : Double) -> Double = "Math" "cos"

///|
pub fn tan(x : Double) -> Double = "Math" "tan"

///|
pub fn asin(x : Double) -> Double = "Math" "asin"

///|
pub fn acos(x : Double) -> Double = "Math" "acos"

///|
pub fn atan(x : Double) -> Double = "Math" "atan"

///|
fn parse_float(s : String) -> Double = "Number" "parseFloat"

///|
/// Correctly rounded conversion for numbers `scan_number` cannot decode
/// exactly on its own; None when `s` is not a number.
fn parse_double_slow(s : String) -> Double? {
  let v = parse_float(s)
  if v.is_nan() {
    None
  } else {
    Some(v)
  }
}
