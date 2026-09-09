///|
test "CLI repeatable params preserve value types and reject malformed keys" {
  let params : Map[String, Json] = Map([])
  assert_true(parse_param("cleanupIds.minify=false", params))
  assert_true(parse_param("cleanupIds.preserve=a,b", params))
  assert_true(parse_param("convertTransform.floatPrecision=2", params))
  assert_true(parse_param("convertColors.currentColor=#fff", params))
  assert_true(parse_param("cleanupIds.force=true", params))
  assert_false(parse_param("cleanupIds=foo", params))
  assert_false(parse_param("cleanupIds.=foo", params))
  assert_false(parse_param(".key=foo", params))
  assert_false(parse_param("cleanupIds.key", params))
  assert_eq(Json::object(params), {
    "cleanupIds": { "minify": false, "preserve": ["a", "b"], "force": true },
    "convertTransform": { "floatPrecision": 2 },
    "convertColors": { "currentColor": "#fff" },
  })
}
