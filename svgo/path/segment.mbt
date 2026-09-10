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
/// True for the commands that produce geometry (`L H V C S Q T A` in either
/// case); `M` and `Z` alone leave a path invisible.
fn is_drawing_command(cmd : Char) -> Bool {
  match cmd.to_ascii_lowercase() {
    'l' | 'h' | 'v' | 'c' | 's' | 'q' | 't' | 'a' => true
    _ => false
  }
}
