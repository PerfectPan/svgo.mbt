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
  params~ : String,
) -> Unit raise {
  guard @plugins.find_plugin(plugin) is Some(p) else {
    fail("unknown plugin \{plugin}")
  }
  let doc = @xml.parse(input)
  let ctx = @plugins.Context::new(precision~)
  ctx.set_params(@json.parse(params))
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
  params~ : String,
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
    let parameters = @json.parse(params)
    for i in 0..<passes {
      ctx.set_params(parameters)
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
/// and compact serializations compare equal. Also trims whitespace at the
/// boundaries of XML comments, matching svgo's serializer.
fn compact(s : String) -> String {
  let sb = StringBuilder()
  let mut pending = ""
  let mut after_tag = false
  let mut in_comment = false
  let trimmed = s.trim().to_owned()
  let cu = trimmed.code_units()
  let len = cu.length()
  let mut i = 0
  while i < len {
    let c = cu[i]
    if c == 10 || c == 13 || c == 9 || c == 32 {
      if !after_tag && !in_comment {
        pending = pending + " "
      }
      i += 1
      continue
    }
    if c != 60 && pending.length() > 0 {
      sb.write_string(pending)
    }
    pending = ""
    // detect comment start <!--
    if c == 60 &&
      i + 3 < len &&
      cu[i + 1] == 33 &&
      cu[i + 2] == 45 &&
      cu[i + 3] == 45 {
      in_comment = true
      sb.write_string("<!--")
      i += 4
      continue
    }
    // detect comment end -->
    if in_comment &&
      c == 45 &&
      i + 2 < len &&
      cu[i + 1] == 45 &&
      cu[i + 2] == 62 {
      in_comment = false
      sb.write_string("-->")
      after_tag = true
      i += 3
      continue
    }
    after_tag = c == 62
    match c.to_char() {
      Some(ch) => sb.write_char(ch)
      None => ()
    }
    i += 1
  }
  sb.to_string()
}
