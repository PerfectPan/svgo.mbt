///|
/// Chinese descriptions for the CLI flags shown on the landing page. The
/// English text is parsed from the CLI's usage string (`cli_data.mbt`); this
/// map supplies the translation used when the UI language is `Zh`. Keyed by
/// the full flag string so a renamed flag fails the test below instead of
/// silently falling back to English.
let cli_zh : Map[String, String] = Map([
  (
    "-o, --output <file>", "写入文件（默认 stdout）；多个输入或 -r 时为输出目录",
  ),
  ("-r, --recursive", "递归处理目录"),
  ("-p, --precision <n>", "保留的小数位数（默认 3）"),
  ("--pretty", "缩进输出"),
  ("--no-multipass", "插件流水线只运行一轮"),
  ("--disable <plugin>", "跳过某个插件（可重复）"),
  (
    "--enable <plugin>", "启用可选插件，如 removeDimensions（可重复）",
  ),
  ("--plugins <a,b,c>", "只运行这些插件，按给定顺序"),
  ("--param <plugin>.<key>=<value>", "设置插件参数（可重复）"),
  ("--stats", "打印体积统计（输出到 stdout 时统计写到 stderr）"),
  ("--json", "输出 JSON 对象 {data, originalSize, size, passes, applied}"),
  ("--bench <n>", "进程内重复优化 n 次并报告耗时"),
  ("-q, --quiet", "不打印统计行"),
  ("--version", "打印版本并退出"),
  ("--list", "列出可用插件"),
  ("-h, --help", "显示帮助"),
])

///|
/// Pick the description for `flag` in the given language. Returns the Chinese
/// entry when `lang` is `Zh` and one exists, otherwise the English `en`.
pub fn flag_description(flag : String, en : String, lang : Lang) -> String {
  match lang {
    En => en
    Zh => cli_zh.get(flag).unwrap_or(en)
  }
}

///|
test "every CLI flag has a non-empty Chinese description" {
  for f in cli_flags {
    match cli_zh.get(f.flag) {
      Some(zh) => assert_true(!zh.is_empty(), msg="empty zh for \{f.flag}")
      None => fail("no zh description for \{f.flag}")
    }
  }
}
