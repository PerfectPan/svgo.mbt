///|
/// Element id of a member: `<pkg>-<Item>`, also the tail of its route
/// `#/api/<pkg>/<Item>`.
fn anchor(pkg : ApiPackage, name : String) -> String {
  short_name(pkg) + "-" + name
}

///|
/// `@xml` → `xml`.
fn short_name(pkg : ApiPackage) -> String {
  pkg.short[1:].to_owned()
}

///|
fn find_package(name : String) -> ApiPackage {
  match api_packages.iter().find_first(p => short_name(p) == name) {
    Some(p) => p
    None => api_packages[0]
  }
}

///|
/// One sentence per package for the page head.
fn package_blurb(name : String) -> String {
  match name {
    "xml" =>
      t(
        "Parse and serialize SVG documents. Plugins operate on this tree.", "解析与序列化 SVG 文档。插件在这棵树上工作。",
      )
    "path" =>
      t(
        "Path data: parse, optimize and print d attributes.", "路径数据：解析、优化并输出 d 属性。",
      )
    "wasm" =>
      t(
        "Exports of the wasm module: the length-prefixed token protocol behind @rivus/svgo.",
        "wasm 模块的导出：@rivus/svgo 背后基于长度前缀 token 的调用协议。",
      )
    "plugins" =>
      t(
        "The 36 plugins, the preset order and the execution context.", "36 个插件、预设顺序与执行上下文。",
      )
    _ =>
      t(
        "Optimize an SVG document: Config, optimize, Result and the plugin list.",
        "优化 SVG 文档：Config、optimize、Result 与插件列表。",
      )
  }
}

///|
/// Member kinds in display order with their group titles.
let kind_groups : Array[(String, (String, String))] = [
  ("type", ("Types", "类型")),
  ("fn", ("Functions", "函数")),
  ("error", ("Errors", "错误")),
]

///|
fn items_of_kind(pkg : ApiPackage, kind : String) -> Array[ApiItem] {
  pkg.items.filter(it => it.kind == kind)
}

///|
/// Docstrings are markdown-ish: paragraphs separated by blank lines, `code`
/// spans in backticks.
fn doc_html(doc : String) -> Html {
  if doc.trim().is_empty() {
    return nothing
  }
  let paras = doc
    .trim()
    .to_owned()
    .split("\n\n")
    .map(s => s.to_owned())
    .to_array()
  div(
    class="doc",
    paras.map(para => {
      let flat = para
        .split("\n")
        .map(s => s.trim().to_owned())
        .to_array()
        .join(" ")
      let parts : Array[Html] = []
      let mut in_code = false
      for piece in flat.split("`") {
        let s = piece.to_owned()
        if in_code {
          parts.push(code(s))
        } else if !s.is_empty() {
          parts.push(text(s))
        }
        in_code = !in_code
      }
      p(parts)
    }),
  )
}

///|
fn api_member(pkg : ApiPackage, it : ApiItem) -> Html {
  let methods = it.methods.map(m => {
    div([
      h4(id=anchor(pkg, it.name + "::" + m.name), m.name),
      pre(highlight_mbt(m.signature)),
      doc_html(m.doc),
    ])
  })
  let impls = it.impls.map(tr => h4("impl \{tr}"))
  let src_dir = match pkg.path.find("PerfectPan/svgo/") {
    Some(_) => pkg.path["PerfectPan/svgo/".length():].to_owned() + "/"
    None => ""
  }
  div(class="member", id=anchor(pkg, it.name), [
    h3([
      span(class="kind", it.kind),
      text(it.name),
      if it.file.is_empty() {
        nothing
      } else {
        a(
          class="src",
          href="\{REPO_URL}/blob/main/svgo/\{src_dir}\{it.file}",
          t("source", "源码"),
        )
      },
    ]),
    pre(highlight_mbt(it.signature)),
    doc_html(it.doc),
    if methods.is_empty() && impls.is_empty() {
      nothing
    } else {
      div(class="methods", [..methods, ..impls])
    },
  ])
}

///|
/// Left column: every package, the current one expanded into its members
/// grouped by kind. Member links carry `data-target` for the scrollspy.
fn side_nav(current : ApiPackage) -> Html {
  let blocks : Array[Html] = []
  for pkg in api_packages {
    let name = short_name(pkg)
    let is_current = name == short_name(current)
    blocks.push(
      a(
        class=if is_current { "api-pkg api-pkg-current" } else { "api-pkg" },
        href="#/api/\{name}",
        [
          span(class="dot", nothing),
          code(pkg.short),
          span(class="count", pkg.items.length().to_string()),
        ],
      ),
    )
    if is_current {
      for group in kind_groups {
        let (kind, (en, zh)) = group
        let items = items_of_kind(pkg, kind)
        if items.is_empty() {
          continue
        }
        blocks.push(h4(t(en, zh)))
        for it in items {
          blocks.push(
            a(
              href="#/api/\{name}/\{it.name}",
              attrs=Attrs::build().data_set("target", anchor(pkg, it.name)),
              it.name,
            ),
          )
        }
      }
    }
  }
  aside(
    class="api-side text-[13px] min-[961px]:sticky min-[961px]:top-20 min-[961px]:max-h-[calc(100vh-100px)] min-[961px]:self-start min-[961px]:overflow-auto",
    [
      ..blocks,
      p(
        class="mt-6 text-xs text-muted",
        tm(
          [
            text("Also on "),
            a(class="text-ink-2", href=MOONCAKES_URL, "mooncakes.io"),
          ],
          [
            text("也见 "),
            a(class="text-ink-2", href=MOONCAKES_URL, "mooncakes.io"),
          ],
        ),
      ),
    ],
  )
}

///|
/// The API reference for one package.
pub fn api_page(chrome : Chrome, name : String) -> Val[Html] {
  chrome.prefs.view(p => {
    let pkg = find_package(name)
    let sections : Array[Html] = []
    for group in kind_groups {
      let (kind, (en, zh)) = group
      let items = items_of_kind(pkg, kind)
      if items.is_empty() {
        continue
      }
      sections.push(h2(class="display", t(en, zh)))
      for it in items {
        sections.push(api_member(pkg, it))
      }
    }
    div(class="pt-[60px]", [
      top_nav(Api(short_name(pkg)), "API", p, chrome.emit),
      page_head(
        t("API reference", "API 文档"),
        [text(pkg.path)],
        package_blurb(short_name(pkg)),
      ),
      div(
        class="wrap grid gap-10 pb-20 pt-2 min-[961px]:grid-cols-[240px_minmax(0,1fr)]",
        [side_nav(pkg), main_(class="api-main min-w-0", sections)],
      ),
      page_footer(),
    ])
  })
}

///|
test "api routes parse" {
  assert_eq(parse_api_path("/api"), ("svgo", None))
  assert_eq(parse_api_path("/api/xml"), ("xml", None))
  assert_eq(parse_api_path("/api/path/Options"), ("path", Some("Options")))
  assert_eq(parse_api_path("/api/nope/X"), ("svgo", Some("X")))
}

///|
test "every package name has a page" {
  for pkg in api_packages {
    assert_true(api_package_names.contains(short_name(pkg)), msg=pkg.short)
  }
}
