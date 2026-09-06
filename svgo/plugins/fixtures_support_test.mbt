///|
/// Run one plugin on `input` and compare with `expected`, ignoring
/// whitespace between tags so fixtures can be indented. Used by the
/// generated `fixtures_test.mbt`.
fn check_fixture(
  plugin : String,
  input : String,
  expected : String,
  precision~ : Int,
  multipass~ : Bool,
) -> Unit raise {
  guard @plugins.find_plugin(plugin) is Some(p) else {
    fail("unknown plugin \{plugin}")
  }
  let doc = @xml.parse(input)
  let ctx = @plugins.Context::new(precision~)
  let mut passes = 0
  while (p.run)(doc, ctx) && multipass && passes < 10 {
    passes += 1
  }
  let actual = compact(doc.to_string())
  let want = compact(expected)
  if actual != want {
    fail("fixture \{plugin} mismatch\n  want: \{want}\n  got:  \{actual}")
  }
}

///|
/// Drop whitespace between tags and around the document.
fn compact(s : String) -> String {
  let sb = StringBuilder()
  let mut pending = ""
  for c in s.trim() {
    if c == '\n' || c == '\r' || c == '\t' || c == ' ' {
      pending = pending + c.to_string()
      continue
    }
    if c != '<' && pending.length() > 0 {
      sb.write_string(pending)
    }
    pending = ""
    sb.write_char(c)
  }
  sb.to_string()
}
