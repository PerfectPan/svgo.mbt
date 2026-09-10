///|
test "cleanupIds reports no change after renaming stabilizes" {
  let doc = @xml.parse("<svg><path id=\"long\"/><use href=\"#long\"/></svg>")
  let ctx = Context::new()
  let cleanup_ids = find_plugin("cleanupIds").unwrap()
  assert_true((cleanup_ids.run)(doc, ctx))
  assert_false((cleanup_ids.run)(doc, ctx))
}
