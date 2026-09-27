///|
fn Term::plain(width? : Int = 80) -> Term {
  { style: false, color: false, unicode: true, width, }
}

///|
fn result(original : Int, size : Int) -> @svgo.Result {
  { data: "", original_size: original, size, passes: 1, applied: [], }
}

///|
test "human units" {
  assert_eq(human_size(0), "0 B")
  assert_eq(human_size(836), "836 B")
  assert_eq(human_size(1000), "1.0 KB")
  assert_eq(human_size(4217), "4.2 KB")
  assert_eq(human_size(999_960), "1.0 MB")
  assert_eq(human_size(12_345_678), "12.3 MB")
  assert_eq(human_ms(12.4), "12 ms")
  assert_eq(human_ms(2.06), "2.1 ms")
  assert_eq(human_ms(0.105), "0.11 ms")
  assert_eq(human_ms(0.0), "0.00 ms")
}

///|
test "change percent is signed and rounded" {
  assert_eq(change_percent(836, 300), -64)
  assert_eq(change_percent(9100, 9400), 3)
  assert_eq(change_percent(100, 100), 0)
  assert_eq(change_percent(0, 10), 0)
}

///|
test "long paths keep their end" {
  assert_eq(shorten_left("icons/close.svg", 20, "…"), "icons/close.svg")
  assert_eq(
    shorten_left("very/long/icons/close.svg", 12, "…"),
    "…s/close.svg",
  )
  assert_eq(
    shorten_left("very/long/icons/close.svg", 12, "..."),
    "...close.svg",
  )
}

///|
test "report rows align and end in a bold totals line" {
  let labels = ["icons/close.svg", "icons/logo.svg", "icons/big.svg"]
  let r = Report::new(Term::plain(), labels)
  let lines = [
    r.row(labels[0], result(836, 300)),
    r.row(labels[1], result(4200, 4200)),
    r.row(labels[2], result(9100, 9400)),
    r.totals(files=3, failed=0, original=14136, size=13900, elapsed_ms=12.3),
  ]
  inspect(
    lines.join("\n"),
    content=(
      #|  icons/close.svg     836 B →    300 B   −64%
      #|  icons/logo.svg     4.2 KB →   4.2 KB     0%
      #|  icons/big.svg      9.1 KB →   9.4 KB    +3%
      #|  3 files           14.1 KB →  13.9 KB    −2%  12 ms
    ),
  )
}

///|
test "failures keep their row and are counted in the totals" {
  let labels = ["a.svg", "icons/bad.svg"]
  let r = Report::new(Term::plain(), labels)
  inspect(
    [
      r.error(labels[1], "unclosed element <g> at offset 8"),
      r.failed_row(labels[1]),
      r.totals(files=2, failed=1, original=836, size=300, elapsed_ms=3.0),
      r.totals(files=2, failed=2, original=0, size=0, elapsed_ms=3.0),
    ].join("\n"),
    content=(
      #|svgo-mbt: icons/bad.svg: unclosed element <g> at offset 8
      #|  icons/bad.svg  failed
      #|  2 files, 1 failed     836 B →    300 B   −64%  3.0 ms
      #|  2 files, 2 failed  3.0 ms
    ),
  )
}

///|
test "styles nest inside the bold totals line" {
  let term = { ..Term::plain(), style: true, color: true, }
  let r = Report::new(term, ["a.svg", "b.svg"])
  assert_eq(
    r.totals(files=2, failed=0, original=1000, size=500, elapsed_ms=1.0),
    "\u{1b}[1m  2 files    1.0 KB →    500 B  \u{1b}[32m −50%\u{1b}[39m  1.0 ms\u{1b}[22m",
  )
  // NO_COLOR keeps bold and dim
  let r = Report::new({ ..term, color: false, }, ["a.svg"])
  assert_eq(r.failed_row("a.svg"), "  a.svg  failed")
}

///|
test "the plugin line wraps to the terminal width" {
  let r = Report::new(Term::plain(width=30), ["a.svg"])
  inspect(
    r.plugins(["removeComments", "cleanupIds", "convertColors", "sortAttrs"]),
    content=(
      #|  removeComments cleanupIds
      #|  convertColors sortAttrs
    ),
  )
}

///|
test "bench row" {
  let r = Report::new(Term::plain(), ["logo.svg"])
  inspect(
    r.bench("logo.svg", runs=20, total_ms=2.1, input_size=570),
    content="  logo.svg  20 runs    2.1 ms   0.11 ms/run     570 B",
  )
}

///|
test "plugin list groups preset-default and optional" {
  inspect(
    plugin_list(Term::plain(), [
      ("removeDoctype", "remove the doctype declaration", true),
      ("sortAttrs", "sort attributes", true),
      ("moveGroupAttrsToElems", "moves some group attributes", false),
    ]),
    content=(
      #|preset-default
      #|  removeDoctype          remove the doctype declaration
      #|  sortAttrs              sort attributes
      #|
      #|optional
      #|  moveGroupAttrsToElems  moves some group attributes
    ),
  )
}

///|
test "help carries the version and bold headings" {
  let term = { ..Term::plain(), style: true, }
  let text = help(term)
  assert_true(text.has_prefix("svgo-mbt \{VERSION}, "))
  assert_true(text.contains("\u{1b}[1mexit status:\u{1b}[22m\n  0  success"))
  assert_false(text.contains("usage: svgo "))
}
