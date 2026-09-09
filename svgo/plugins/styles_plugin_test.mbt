///|
/// The three style plugins have to sit where svgo puts them: after
/// `cleanupAttrs` and before `cleanupIds`, in the order mergeStyles,
/// inlineStyles, minifyStyles. A rule inlined after ids were minified would
/// be matched against the wrong ids. `-1` means the plugin is missing, which
/// fails the ordering assertions below.
test "the style plugins run in svgo's positions" {
  let names = @plugins.preset_default.map(p => p.name)
  let at = name => {
    match names.search(name) {
      Some(i) => i
      None => -1
    }
  }
  assert_true(at("cleanupAttrs") >= 0)
  assert_true(at("cleanupAttrs") < at("mergeStyles"))
  assert_true(at("mergeStyles") < at("inlineStyles"))
  assert_true(at("inlineStyles") < at("minifyStyles"))
  assert_true(at("minifyStyles") < at("cleanupIds"))
}
