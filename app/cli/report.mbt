///|
/// What one output stream can show. Every layout reads correctly with all of
/// it off, because that is what ends up in CI logs.
struct Term {
  /// bold and dim
  style : Bool
  /// red and green; `NO_COLOR` turns these off but keeps bold and dim
  color : Bool
  /// `→`, `−` and `…`, else `->`, `-` and `...`
  unicode : Bool
  /// columns available for a line
  width : Int
}

///|
/// Capabilities of file descriptor `fd` (1 stdout, 2 stderr), from the
/// environment. Only callers that never write SVG data to `fd` may style it.
fn Term::detect(fd : Int) -> Term {
  let env = (key : String) => {
    match @env.get_env_var(key) {
      Some("") | None => None
      v => v
    }
  }
  let forced = env("FORCE_COLOR") is Some(v) && v != "0"
  let style = (forced || svgo_is_tty(fd)) && env("TERM") != Some("dumb")
  // POSIX precedence: the first of these that is set decides the charset
  let locale = match (env("LC_ALL"), env("LC_CTYPE"), env("LANG")) {
    (Some(l), _, _) | (None, Some(l), _) | (None, None, Some(l)) => l
    _ => ""
  }
  let upper = locale.to_upper()
  let columns = env("COLUMNS").map(c => @string.parse_int(c) catch { _ => 0 })
  let width = match columns {
    Some(w) if w > 0 => w
    _ => 80
  }
  {
    style,
    color: style && env("NO_COLOR") is None,
    unicode: upper.contains("UTF-8") || upper.contains("UTF8"),
    width,
  }
}

///|
/// SGR codes are closed with their specific reset (22 intensity, 39
/// foreground), so a coloured cell can sit inside a bold line.
fn Term::bold(self : Term, s : String) -> String {
  if self.style {
    "\u{1b}[1m\{s}\u{1b}[22m"
  } else {
    s
  }
}

///|
fn Term::dim(self : Term, s : String) -> String {
  if self.style {
    "\u{1b}[2m\{s}\u{1b}[22m"
  } else {
    s
  }
}

///|
fn Term::red(self : Term, s : String) -> String {
  if self.color {
    "\u{1b}[31m\{s}\u{1b}[39m"
  } else {
    s
  }
}

///|
fn Term::green(self : Term, s : String) -> String {
  if self.color {
    "\u{1b}[32m\{s}\u{1b}[39m"
  } else {
    s
  }
}

///|
fn Term::arrow(self : Term) -> String {
  if self.unicode {
    "→"
  } else {
    "->"
  }
}

///|
/// U+2212 has the width of a digit, so signed columns stay aligned.
fn Term::minus(self : Term) -> String {
  if self.unicode {
    "−"
  } else {
    "-"
  }
}

///|
fn Term::ellipsis(self : Term) -> String {
  if self.unicode {
    "…"
  } else {
    "..."
  }
}

///|
/// Byte count in 1000-based units, one decimal from 1 KB up: `836 B`, `4.2 KB`.
fn human_size(bytes : Int) -> String {
  if bytes < 1000 {
    return "\{bytes} B"
  }
  let units = ["KB", "MB", "GB"]
  let mut v = bytes.to_double() / 1000.0
  let mut i = 0
  // decide the unit on the rounded value, so 999,960 B is 1.0 MB, not 1000.0 KB
  while (v * 10.0).round() >= 10000.0 && i < units.length() - 1 {
    v = v / 1000.0
    i += 1
  }
  "\{fixed(v, 1)} \{units[i]}"
}

///|
/// Milliseconds with the digits that matter at that scale: `12 ms`, `2.1 ms`, `0.11 ms`.
fn human_ms(ms : Double) -> String {
  if ms >= 10.0 {
    "\{ms.round().to_int()} ms"
  } else if ms >= 1.0 {
    "\{fixed(ms, 1)} ms"
  } else {
    "\{fixed(ms, 2)} ms"
  }
}

///|
/// `x` rounded to `digits` decimals (1 or 2), always printing them.
fn fixed(x : Double, digits : Int) -> String {
  let scale = if digits == 1 { 10 } else { 100 }
  let n = (x * scale.to_double()).round().to_int()
  let frac = (n % scale).to_string()
  "\{n / scale}.\{frac.pad_start(digits, '0')}"
}

///|
/// Size change in whole percent of the original: negative when it shrank.
fn change_percent(original : Int, size : Int) -> Int {
  if original == 0 {
    0
  } else {
    ((size - original).to_double() * 100.0 / original.to_double())
    .round()
    .to_int()
  }
}

///|
/// Keep the end of `s`, the part that names the file, within `max` columns.
fn shorten_left(s : String, max : Int, ellipsis : String) -> String {
  if s.length() <= max {
    return s
  }
  let keep = max - ellipsis.length()
  if keep <= 0 {
    return s
  }
  ellipsis + s[s.length() - keep:].to_owned()
}

///|
const SIZE_WIDTH = 8

///|
const PERCENT_WIDTH = 5

///|
/// Left margin plus every column after the path in a report row.
const ROW_TAIL : Int = 2 + 2 + SIZE_WIDTH + 4 + SIZE_WIDTH + 2 + PERCENT_WIDTH

///|
/// The size table printed after files are optimized: one row per file as it
/// finishes, then a totals line when there is more than one.
struct Report {
  term : Term
  /// width of the first column, fixed up front so rows can print one by one
  label_width : Int
}

///|
fn Report::new(term : Term, labels : Array[String]) -> Report {
  let mut widest = 0
  for l in labels {
    widest = widest.max(l.length())
  }
  if labels.length() > 1 {
    widest = widest.max("\{labels.length()} files".length())
  }
  { term, label_width: widest.min((term.width - ROW_TAIL).max(12)), }
}

///|
fn Report::label(self : Report, s : String) -> String {
  shorten_left(s, self.label_width, self.term.ellipsis()).pad_end(
    self.label_width,
    ' ',
  )
}

///|
/// `836 B →  300 B   −64%`, the percentage coloured by its sign. `dim` greys
/// the arrow and a 0% change; off inside a bold line, because dim and bold
/// share one reset code.
fn Report::sizes(
  self : Report,
  original : Int,
  size : Int,
  dim~ : Bool,
) -> String {
  let t = self.term
  let p = change_percent(original, size)
  let text = if p < 0 {
    "\{t.minus()}\{-p}%"
  } else if p > 0 {
    "+\{p}%"
  } else {
    "0%"
  }
  let cell = text.pad_start(PERCENT_WIDTH, ' ')
  let pct = if p < 0 {
    t.green(cell)
  } else if p > 0 {
    t.red(cell)
  } else if dim {
    t.dim(cell)
  } else {
    cell
  }
  let from = human_size(original).pad_start(SIZE_WIDTH, ' ')
  let to = human_size(size).pad_start(SIZE_WIDTH, ' ')
  let arrow = if dim { t.dim(t.arrow()) } else { t.arrow() }
  "\{from} \{arrow} \{to}  \{pct}"
}

///|
fn Report::row(self : Report, label : String, r : @svgo.Result) -> String {
  "  \{self.label(label)}  \{self.sizes(r.original_size, r.size, dim=true)}"
}

///|
fn Report::failed_row(self : Report, label : String) -> String {
  "  \{self.label(label)}  \{self.term.red("failed")}"
}

///|
/// The diagnostic for a file that could not be read, parsed, optimized or written.
fn Report::error(self : Report, label : String, message : String) -> String {
  "\{PROG}: \{self.term.bold(label)}: \{self.term.red(message)}"
}

///|
/// The plugins that changed a single file, space separated and wrapped.
fn Report::plugins(self : Report, applied : Array[String]) -> String {
  let lines : Array[String] = []
  let mut line = ""
  for name in applied {
    if !line.is_empty() &&
      2 + line.length() + 1 + name.length() > self.term.width {
      lines.push(line)
      line = ""
    }
    line = if line.is_empty() { name } else { "\{line} \{name}" }
  }
  if !line.is_empty() {
    lines.push(line)
  }
  lines.map(l => "  " + self.term.dim(l)).join("\n")
}

///|
/// `4 files  15.0 KB → 14.2 KB  −5%  12 ms`, bold; sizes cover the files that
/// were optimized.
fn Report::totals(
  self : Report,
  files~ : Int,
  failed~ : Int,
  original~ : Int,
  size~ : Int,
  elapsed_ms~ : Double,
) -> String {
  let t = self.term
  let count = "\{files} files"
  let mut line = if failed == 0 {
    "  \{self.label(count)}"
  } else {
    let tail = ", \{failed} failed"
    let padding = self.label_width - count.length() - tail.length()
    "  \{count}, \{t.red("\{failed} failed")}\{" ".repeat(padding.max(0))}"
  }
  if failed < files {
    line = "\{line}  \{self.sizes(original, size, dim=false)}"
  }
  t.bold("\{line}  \{human_ms(elapsed_ms)}")
}

///|
/// `logo.svg  20 runs  2.1 ms  0.11 ms/run  570 B`, the per-run time bold.
fn Report::bench(
  self : Report,
  label : String,
  runs~ : Int,
  total_ms~ : Double,
  input_size~ : Int,
) -> String {
  let per = human_ms(total_ms / runs.to_double()) + "/run"
  "  \{self.label(label)}  \{runs} runs  \{human_ms(total_ms).pad_start(8, ' ')}  \{self.term.bold(per.pad_start(12, ' '))}  \{human_size(input_size).pad_start(SIZE_WIDTH, ' ')}"
}
