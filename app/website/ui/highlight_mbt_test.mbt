///|
test "tokenize_mbt is lossless" {
  for
    s in [
      "fn add(a : Int, b : Int) -> Int { a + b }", "let x = @svgo.optimize(svg, config={ precision: 3 })",
      "// comment\n///| doc comment\nlet s = \"hello \\{name}\"", "struct Config { plugins : Array[String] } derive(Debug)",
      "let n = 0x1F\nlet f = 3.14\nlet b = true", "#skip\n#export_name(\"foo\")",
      "match x { Some(v) => v, None => 0 }", "",
    ] {
    let joined = tokenize_mbt(s).map(t => t.1).join("")
    assert_eq(joined, s)
  }
}

///|
test "tokenize_mbt classes" {
  let toks = tokenize_mbt("let x: Int = 42").map(tk => "\{tk.0}:\{tk.1}")
  inspect(
    toks.join(" | "),
    content=(
      #|hl-kw:let | :  | :x | hl-p:: | :  | hl-type:Int | :  | hl-p:= | :  | hl-val:42
    ),
  )
}

///|
test "tokenize_mbt keywords and types" {
  let src = "fn f(self : Config) -> Result raise { return self }"
  let toks = tokenize_mbt(src).map(tk => tk.0)
  // fn, return are keywords; Config, Result are types; self is keyword
  assert_eq(toks.contains("hl-kw"), true)
  assert_eq(toks.contains("hl-type"), true)
}

///|
test "tokenize_mbt string interpolation stays in string" {
  let src = "\"hello \\{name}\""
  let toks = tokenize_mbt(src)
  // the whole thing is one string token
  assert_eq(toks.length(), 1)
  assert_eq(toks[0].0, "hl-val")
  assert_eq(toks[0].1, src)
}

///|
test "tokenize_mbt minus is not swallowed by numbers" {
  // "a-1" must be three tokens: name "a", punct "-", number "1"
  let toks = tokenize_mbt("a-1").map(tk => tk.1)
  assert_eq(toks.length(), 3)
  assert_eq(toks[0], "a")
  assert_eq(toks[1], "-")
  assert_eq(toks[2], "1")
  // same for "x-2"
  let toks2 = tokenize_mbt("x-2").map(tk => tk.1)
  assert_eq(toks2.length(), 3)
  assert_eq(toks2[0], "x")
  assert_eq(toks2[1], "-")
  assert_eq(toks2[2], "2")
}

///|
test "tokenize_mbt @ path includes slashes" {
  let src = "@moonbitlang/core/debug.Debug"
  let toks = tokenize_mbt(src)
  // the whole @-path is one type token
  assert_eq(toks.length(), 1)
  assert_eq(toks[0].0, "hl-type")
  assert_eq(toks[0].1, src)
}

///|
test "tokenize_mbt hex and exponent numbers" {
  // 0x1F is one number token
  let hex = tokenize_mbt("0x1F").map(tk => tk.1)
  assert_eq(hex.length(), 1)
  assert_eq(hex[0], "0x1F")
  // 1e10 and 1.5e-3 are single number tokens
  let exp = tokenize_mbt("1e10").map(tk => tk.1)
  assert_eq(exp.length(), 1)
  assert_eq(exp[0], "1e10")
  let negexp = tokenize_mbt("1.5e-3").map(tk => tk.1)
  assert_eq(negexp.length(), 1)
  assert_eq(negexp[0], "1.5e-3")
}

///|
test "tokenize_mbt is lossless on api signatures" {
  for pkg in api_packages {
    for it in pkg.items {
      let joined = tokenize_mbt(it.signature).map(t => t.1).join("")
      assert_eq(joined, it.signature)
      for m in it.methods {
        let joined = tokenize_mbt(m.signature).map(t => t.1).join("")
        assert_eq(joined, m.signature)
      }
    }
  }
}
