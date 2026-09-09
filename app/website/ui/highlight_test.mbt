///|
test "tokenize is lossless" {
  for
    s in [
      "<svg viewBox=\"0 0 24 24\"><path d='M0 0'/></svg>", "<?xml version=\"1.0\"?>\n<!-- hi -->\n<a b=\"c\">text & more</a>",
      "<!DOCTYPE svg><svg><![CDATA[ <x> ]]></svg>", "broken <tag attr=\"unterminated",
      "no tags at all", "",
    ] {
    let joined = tokenize(s).map(t => t.1).join("")
    assert_eq(joined, s)
  }
}

///|
test "tokenize classes" {
  let toks = tokenize("<g id=\"x\"><!--c--></g>").map(tk => "\{tk.0}:\{tk.1}")
  inspect(
    toks.join(" | "),
    content=(
      #|hl-p:< | hl-tag:g | :  | hl-attr:id | hl-p:= | hl-val:"x" | hl-p:> | hl-cmt:<!--c--> | hl-p:</ | hl-tag:g | hl-p:>
    ),
  )
}

///|
test "huge documents are left plain" {
  let big = String::make(highlight_limit + 1, 'a')
  inspect(tokenize(big).length(), content="1")
  inspect(highlight(big).length(), content="1")
}
