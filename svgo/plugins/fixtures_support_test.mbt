///|
/// Run one plugin on `input` and compare with `expected`, ignoring
/// whitespace between tags so fixtures can be indented. Used by the
/// generated `fixtures_test.mbt` for our own cases.
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
/// svgo's own runner semantics for the upstream suite: run the plugin
/// `passes` times and require the tree to equal `expected` after every run
/// (the second run checks idempotence). With `expect_fail` the case is a
/// known gap: it must still fail, so a fix also has to remove it from
/// fixtures/upstream/KNOWN_FAILURES.txt.
fn check_fixture_upstream(
  plugin : String,
  input : String,
  expected : String,
  precision~ : Int,
  passes~ : Int,
  expect_fail~ : Bool,
) -> Unit raise {
  guard @plugins.find_plugin(plugin) is Some(p) else {
    fail("unknown plugin \{plugin}")
  }
  let want = compact(expected)
  let problem : String? = try {
    let doc = @xml.parse(input)
    let ctx = @plugins.Context::new(precision~)
    let mut found : String? = None
    for i in 0..<passes {
      ignore((p.run)(doc, ctx))
      let actual = compact(doc.to_string())
      if actual != want {
        found = Some("pass \{i + 1}\n  want: \{want}\n  got:  \{actual}")
        break
      }
    }
    found
  } catch {
    e => Some("error: \{e}")
  }
  match (problem, expect_fail) {
    (None, false) => ()
    (Some(why), false) => fail("upstream \{plugin} mismatch, \{why}")
    (Some(_), true) => ()
    (None, true) =>
      fail(
        "upstream \{plugin} case now passes: remove it from fixtures/upstream/KNOWN_FAILURES.txt",
      )
  }
}

///|
/// Drop whitespace around tags and around the document, so pretty-printed
/// and compact serializations compare equal.
fn compact(s : String) -> String {
  let sb = StringBuilder()
  let mut pending = ""
  let mut after_tag = false
  for c in s.trim() {
    if c == '\n' || c == '\r' || c == '\t' || c == ' ' {
      if !after_tag {
        pending = pending + c.to_string()
      }
      continue
    }
    if c != '<' && pending.length() > 0 {
      sb.write_string(pending)
    }
    pending = ""
    after_tag = c == '>'
    sb.write_char(c)
  }
  sb.to_string()
}
