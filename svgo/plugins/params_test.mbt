///|
test "typed params accept strings and arrays and fall back on wrong types" {
  let ctx = @plugins.Context::new()
  ctx.set_params({
    "bool": false,
    "int": 2,
    "one": "a",
    "many": ["a", 7, "b"],
    "empty": [],
  })
  assert_eq(ctx.param_bool("bool", true), false)
  assert_eq(ctx.param_bool("one", true), true)
  assert_eq(ctx.param_int("int", 3), 2)
  assert_eq(ctx.param_int("one", 3), 3)
  assert_eq(ctx.param_string("int", "fallback"), "fallback")
  assert_eq(ctx.param_strings("one"), ["a"])
  assert_eq(ctx.param_strings("many"), ["a", "b"])
  assert_true(ctx.has_param("empty"))
  ctx.set_params(Json::null())
  assert_false(ctx.has_param("empty"))
  assert_eq(ctx.param_strings("many"), [])
}

///|
test "cleanupIds reports no change after renaming stabilizes" {
  let doc = @xml.parse("<svg><path id=\"long\"/><use href=\"#long\"/></svg>")
  let ctx = @plugins.Context::new()
  assert_true((@plugins.cleanup_ids.run)(doc, ctx))
  assert_false((@plugins.cleanup_ids.run)(doc, ctx))
}
