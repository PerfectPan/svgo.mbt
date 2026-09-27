// The wasm-gc build takes its transcendentals, the slow path of number
// parsing and shortest number formatting from the embedder. V8's `Math` is
// the same fdlibm port the js build already uses through core, and core's
// Double::to_string follows the ECMAScript spelling that the js build gets
// from `toString`. Importing them keeps MoonBit's own implementations (about
// 15 KB after wasm-opt, ryu's tables included) out of the artifact.
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
/// Shortest decimal spelling that reads back as `x`, as JavaScript's
/// `String(x)` writes it (exponent form below 1e-6 and from 1e21).
pub fn number_to_string(x : Double) -> String = "Number" "toString"

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
