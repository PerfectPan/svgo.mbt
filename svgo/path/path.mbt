///|
/// Parse path data. Implicit command repetition is expanded into separate
/// segments (`M 1 2 3 4` becomes `M1 2` followed by `L3 4`).
pub fn parse(d : String) -> Array[Segment] raise PathError {
  let out : Array[Segment] = []
  parse_into(out, d)
  out
}

///|
/// Serialize segments to the shortest valid path data string.
pub fn stringify(segments : Array[Segment], precision? : Int = 3) -> String {
  let sb = StringBuilder()
  write_path(sb, segments, precision)
  sb.to_string()
}
