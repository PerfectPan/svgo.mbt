///|
test "plugin params are isolated on every multipass run" {
  let config : @svgo.Config = {
    ..@svgo.Config::default(),
    plugins: [
      "removeUselessStrokeAndFill", "removeUnknownsAndDefaults", "cleanupIds",
    ],
    params: {
      "removeUselessStrokeAndFill": {
        "fill": false,
        "keepRoleAttr": true,
        "preserve": ["unused"],
      },
      "removeUnknownsAndDefaults": { "defaultAttrs": false },
      "cleanupIds": { "minify": false },
    },
  }
  let result = @svgo.optimize(
    "<svg><path id=\"unused\" role=\"img\" fill=\"none\" fill-opacity=\".5\"/></svg>",
    config~,
  )
  assert_eq(result.data, "<svg><path fill=\"none\" fill-opacity=\".5\"/></svg>")
  assert_eq(result.passes, 2)
  assert_eq(@svgo.optimize(result.data, config~).data, result.data)
}

///|
test "precision override belongs to its plugin" {
  let result = @svgo.optimize(
    "<svg><path x=\"1.2345\" transform=\"translate(1.2345 0)\"/></svg>",
    config={
      ..@svgo.Config::default(),
      plugins: ["convertTransform", "cleanupNumericValues"],
      params: { "convertTransform": { "floatPrecision": 1 } },
    },
  )
  assert_eq(
    result.data,
    "<svg><path x=\"1.235\" transform=\"translate(1.2)\"/></svg>",
  )
}
