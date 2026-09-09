///|
/// Stable sort with a comparison function, the semantics svgo gets from
/// JavaScript's `Array.prototype.sort`: elements that compare equal keep
/// their document order. Core's `sort_by` is an unstable introsort and each
/// element type instantiates about 2 KB of it in the wasm; this merge sort
/// is a fraction of that per type and the arrays here are short.
fn[T] stable_sort_by(arr : Array[T], cmp : (T, T) -> Int) -> Unit {
  let n = arr.length()
  if n < 2 {
    return
  }
  if n <= 12 {
    for i in 1..<n {
      let x = arr[i]
      let mut j = i
      while j > 0 && cmp(arr[j - 1], x) > 0 {
        arr[j] = arr[j - 1]
        j -= 1
      }
      arr[j] = x
    }
    return
  }
  // Bottom-up merge sort, alternating between `arr` and a scratch copy.
  let mut src = arr
  let mut dst = arr.copy()
  let mut width = 1
  while width < n {
    let mut lo = 0
    while lo < n {
      let mid = if lo + width < n { lo + width } else { n }
      let hi = if lo + 2 * width < n { lo + 2 * width } else { n }
      let mut i = lo
      let mut j = mid
      for k in lo..<hi {
        if i < mid && (j >= hi || cmp(src[i], src[j]) <= 0) {
          dst[k] = src[i]
          i += 1
        } else {
          dst[k] = src[j]
          j += 1
        }
      }
      lo = hi
    }
    let t = src
    src = dst
    dst = t
    width *= 2
  }
  if !physical_equal(src, arr) {
    for k in 0..<n {
      arr[k] = src[k]
    }
  }
}
