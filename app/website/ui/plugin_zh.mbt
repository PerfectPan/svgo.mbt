///|
/// Chinese descriptions for every plugin the site can show. The English text
/// comes straight from the library (`@svgo.list_plugins`); this map supplies
/// the translation used when the UI language is `Zh`. Keep one entry per
/// plugin, no full stops, plain words, say what is removed or rewritten.
let plugin_zh : Map[String, String] = Map([
  ("removeDoctype", "去掉 doctype 声明"),
  ("removeXMLProcInst", "去掉 <?xml ...?> 声明"),
  ("removeComments", "去掉注释"),
  ("removeDeprecatedAttrs", "去掉已废弃的属性"),
  ("removeMetadata", "去掉 <metadata>"),
  ("removeEditorsNSData", "去掉编辑器的命名空间、元素和属性"),
  ("cleanupAttrs", "清理属性值里的空白"),
  ("mergeStyles", "合并多个 <style> 元素"),
  ("inlineStyles", "把 <style> 里的样式内联到 style 属性"),
  ("minifyStyles", "压缩 <style> 和 style 属性里的 CSS"),
  ("cleanupIds", "去掉没用的 id，压缩被引用的 id"),
  ("removeUselessDefs", "去掉 <defs> 里没有 id 的子元素"),
  ("cleanupNumericValues", "四舍五入数值，去掉 px 单位"),
  ("convertColors", "把颜色转成最短形式"),
  ("removeUnknownsAndDefaults", "去掉未知元素/属性和默认属性值"),
  (
    "removeNonInheritableGroupAttrs", "去掉 <g> 上不能继承的表现属性",
  ),
  ("removeUselessStrokeAndFill", "去掉没用的 stroke 和 fill 属性"),
  ("cleanupEnableBackground", "去掉没有滤镜用到的 enable-background"),
  ("removeHiddenElems", "去掉不渲染的元素"),
  ("removeEmptyText", "去掉空的 <text>、<tspan>、<tref>"),
  ("convertShapeToPath", "把 rect、line、polyline、polygon 转成 path"),
  ("convertEllipseToCircle", "把半径相等的 ellipse 转成 circle"),
  ("moveElemsAttrsToGroup", "把子元素共有的属性提到 <g> 上"),
  ("collapseGroups", "折叠没用的 <g>"),
  ("convertPathData", "优化 path 数据"),
  ("convertTransform", "简化 transform 列表"),
  ("removeEmptyAttrs", "去掉值为空的属性"),
  ("removeEmptyContainers", "去掉空的容器元素"),
  ("mergePaths", "合并相邻、属性相同且不重叠的 path"),
  ("removeUnusedNS", "去掉没用的命名空间声明"),
  ("sortAttrs", "给属性排序"),
  ("sortDefsChildren", "给 <defs> 的子元素排序以利压缩"),
  ("removeDesc", "去掉编辑器生成的 <desc>"),
  ("removeDimensions", "有 viewBox 时去掉根元素的 width/height"),
  ("removeTitle", "去掉 <title>"),
  ("moveGroupAttrsToElems", "把 <g> 的部分属性移到内容元素上"),
])

///|
/// Pick the description for `name` in the given language. Returns the Chinese
/// entry when `lang` is `Zh` and one exists, otherwise the English `en`.
pub fn plugin_description(name : String, en : String, lang : Lang) -> String {
  match lang {
    En => en
    Zh => plugin_zh.get(name).unwrap_or(en)
  }
}

///|
test "every plugin has a non-empty Chinese description" {
  let names = @svgo.list_plugins().map(it => it.0)
  for name in names {
    match plugin_zh.get(name) {
      None => fail("missing Chinese description for \{name}")
      Some(desc) =>
        if desc.is_empty() {
          fail("empty Chinese description for \{name}")
        }
    }
  }
}
