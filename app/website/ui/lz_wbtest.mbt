///|
test "lz roundtrip" {
  for
    s in [
      "", "a", "Hello, world!", "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 24 24\"><path d=\"M4 4l12 12M16 4 4 16\"/></svg>",
      "中文也可以 · émoji-free but non-latin",
    ] {
    let packed = lz_compress(s)
    assert_eq(lz_decompress(packed), Some(s))
    for u in packed.code_units() {
      assert_true(lz_reverse.contains(u.to_int()))
    }
  }
}

///|
test "lz matches the reference implementation" {
  // lz-string 1.5.0: compressToEncodedURIComponent("Hello, world!")
  inspect(lz_compress("Hello, world!"), content="BIUwNmD2A0AEDukBOYAmBCIA")
  assert_eq(lz_decompress("BIUwNmD2A0AEDukBOYAmBCIA"), Some("Hello, world!"))
}

///|
test "lz compresses every bundled sample and shrinks the big ones" {
  for s in samples {
    let packed = lz_compress(s.svg)
    assert_eq(lz_decompress(packed), Some(s.svg))
    // 6 bits per output char: about 70% of the text for small files,
    // about half for the big ones; base64 would be 133%.
    assert_true(packed.length() < s.svg.length())
    if s.svg.length() > 20000 {
      assert_true(packed.length() < s.svg.length() * 6 / 10)
    }
  }
}

///|
test "lz rejects garbage" {
  assert_eq(lz_decompress("!!!"), None)
}
