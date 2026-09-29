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
/// A short noun-phrase title for the page head: what the package is for,
/// not its namespace (that goes next to it as a mono label).
fn package_title(name : String) -> String {
  match name {
    "xml" => t("Document and Element", "Document 与 Element")
    "path" => t("Path data", "路径数据")
    "plugins" => t("Plugins and Context", "插件与 Context")
    _ => t("optimize and Config", "optimize 与 Config")
  }
}

///|
/// One sentence per package for the lead paragraph under the title.
fn package_blurb(name : String) -> String {
  let count = @svgo.list_plugins().length()
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
        "The \{count} plugins, the preset order and the execution context.",
        "\{count} 个插件、预设顺序与执行上下文。",
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
priv enum ApiMsg {
  Copy(String)
}

///|
/// A signature block with a text "copy" action, kept only for signatures of
/// two lines or more — a one-liner is short enough to select by hand, and a
/// copy link on every row was noise; the confirmation is the site toast.
/// A zero-width space after `(` and after each `, ` — invisible characters
/// the highlighter just colours as ordinary punctuation and passes
/// through unchanged, but they give the browser a wrap point at an
/// argument boundary. Only for one-line signatures: a multi-line struct
/// already has its own real line breaks and manual field indent, which
/// this would double up on.
fn break_points(sig : String) -> String {
  sig
  .replace_all(old="(", new="(\u{200B}")
  .replace_all(old=", ", new=", \u{200B}")
}

///|
/// `overlay_copy` renders the corner "copy" action on a multi-line block.
/// A member's own top-level declaration turns it off — that action moved to
/// the heading row instead (see `api_member`'s `member-actions`) — while a
/// method's signature and the usage example keep their own.
fn sig_block(
  signature : String,
  emit : Emit[ApiMsg],
  overlay_copy? : Bool = true,
) -> Html {
  let multiline = signature.contains("\n")
  let display = if multiline { signature } else { break_points(signature) }
  let show_button = multiline && overlay_copy
  let card_class = if multiline {
    if show_button {
      "sig sig-has-copy"
    } else {
      "sig sig-card"
    }
  } else {
    "sig"
  }
  div(class=card_class, [
    pre(highlight_mbt(display)),
    if show_button {
      button(
        class="sig-copy",
        on_click=emit(Copy(signature)),
        t("copy", "复制"),
      )
    } else {
      nothing
    },
  ])
}

///|
/// The MoonBit keyword the member actually starts with — `struct` and
/// `enum` share `it.kind == "type"` in the generated data, so tell them
/// apart from the signature text. Reads the same in both languages.
fn kind_label(it : ApiItem) -> String {
  match it.kind {
    "type" => if it.signature.contains("enum ") { "enum" } else { "struct" }
    "error" => "suberror"
    kind => kind
  }
}

///|
fn api_member(pkg : ApiPackage, it : ApiItem, emit : Emit[ApiMsg]) -> Html {
  let methods = it.methods.map(meth => {
    let id = anchor(pkg, it.name + "::" + meth.name)
    div([
      h4(id~, meth.name),
      sig_block(meth.signature, emit),
      doc_html(meth.doc),
    ])
  })
  // a trait impl has no signature of its own, so it's a mono tag on the
  // heading row after the name, not a stranded line under the doc text
  let impls_tag = if it.impls.is_empty() {
    nothing
  } else {
    span(
      class="impls-tag",
      it.impls.map(tr => t("implements \{tr}", "实现 \{tr}")).join("; "),
    )
  }
  let src_dir = match pkg.path.find("PerfectPan/svgo/") {
    Some(_) => pkg.path["PerfectPan/svgo/".length():].to_owned() + "/"
    None => ""
  }
  let id = anchor(pkg, it.name)
  // "copy · source" together on the right of the heading row: copy acts on
  // this member's own signature, so it moved out of the signature card
  // itself (see sig_block's overlay_copy) rather than doubling as a second
  // right-aligned label under it.
  let actions = [
    button(class="src", on_click=emit(Copy(it.signature)), t("copy", "复制")),
    if it.file.is_empty() {
      nothing
    } else {
      span(class="text-muted", " · ")
    },
    if it.file.is_empty() {
      nothing
    } else {
      a(
        class="src",
        href="\{REPO_URL}/blob/main/svgo/\{src_dir}\{it.file}",
        t("source", "源码"),
      )
    },
  ]
  div(class="member", id~, [
    h3([
      span(class="kind", kind_label(it)),
      text(it.name),
      impls_tag,
      div(class="member-actions", actions),
    ]),
    sig_block(it.signature, emit, overlay_copy=false),
    doc_html(it.doc),
    if methods.is_empty() {
      nothing
    } else {
      div(class="methods", methods)
    },
  ])
}

///|
/// Packages excluded from the API pages (e.g. wasm FFI exports).
let excluded_packages : Set[String] = Set(["wasm"])

///|
/// The packages shown in the switcher, in display order.
fn shown_packages() -> Array[ApiPackage] {
  api_packages.filter(pkg => !excluded_packages.contains(short_name(pkg)))
}

///|
/// A row of package links: the desktop sidebar's top block and, below
/// 961 px, the whole of the sidebar (a package switcher, not a long list).
fn package_switcher(current : ApiPackage) -> Html {
  div(
    class="api-pkgs",
    shown_packages().map(pkg => {
      let name = short_name(pkg)
      let is_current = name == short_name(current)
      a(
        class=if is_current { "api-pkg api-pkg-current" } else { "api-pkg" },
        href="#/api/\{name}",
        [code(pkg.short), span(class="count", pkg.items.length().to_string())],
      )
    }),
  )
}

///|
/// The current package's members, grouped by kind, as anchors for the
/// scrollspy. Collapses under the package switcher on narrow screens behind
/// a checkbox-driven disclosure (no JS); forced visible again above 961 px
/// (style.css).
fn table_of_contents(pkg : ApiPackage) -> Html {
  let name = short_name(pkg)
  let blocks : Array[Html] = []
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
  div(class="api-toc", [
    input(
      input_type=Checkbox,
      id="api-toc-toggle",
      class="pg-toggle",
      hidden=true,
    ),
    label(
      for_="api-toc-toggle",
      class="lg:hidden",
      t(
        "On this page (\{pkg.items.length()})",
        "本页内容（\{pkg.items.length()}）",
      ),
    ),
    div(
      class="api-toc-body",
      attrs=Attrs::build().data_set("slide", "rail"),
      blocks,
    ),
  ])
}

///|
/// Left column: the package switcher and the current package's table of
/// contents.
fn side_nav(current : ApiPackage) -> Html {
  aside(
    class="api-side text-code lg:sticky lg:top-20 lg:flex lg:max-h-[calc(100vh-var(--api-side-clearance))] lg:flex-col lg:self-start lg:overflow-auto",
    [package_switcher(current), table_of_contents(current)],
  )
}

///|
/// A minimal call, right after the title on the `svgo` package page (the
/// entry point most readers land on) so the shape of a call is visible
/// before the member list. Comments sit above the expression they describe
/// and every line stays within about 38 columns, so it never clips on a
/// narrow screen.
fn usage_example(emit : Emit[ApiMsg]) -> Html {
  let code = t(
    "let r = @svgo.optimize(svg, config={\n  ..@svgo.Config::default(),\n  precision: 2,\n})\n\nr.data             // optimized SVG\nr.original_size    // input bytes\nr.size             // output bytes\nr.saved_percent()  // % saved",
    "let r = @svgo.optimize(svg, config={\n  ..@svgo.Config::default(),\n  precision: 2,\n})\n\nr.data             // 优化后的 SVG\nr.original_size    // 输入字节数\nr.size             // 输出字节数\nr.saved_percent()  // 节省的字节占比",
  )
  div(class="mt-6", [
    div(class="example-label", t("Example", "示例")),
    sig_block(code, emit),
  ])
}

///|
/// The API reference for one package.
pub fn api_page(chrome : Chrome, name : String) -> Val[Html] {
  let (state, emit) = @rabbita.create_state((), update=(
    m : Unit,
    msg : ApiMsg,
    _,
  ) => {
    match msg {
      Copy(text) =>
        (
          m,
          @rabbita.batch([
            @rabbita.effect(fn() noraise { copy_text(text) }),
            toast_success(t("Copied", "已复制")),
          ]),
        )
    }
  })
  state.view2(chrome.prefs, (_, prefs) => {
    let pkg = find_package(name)
    // one content column, top to bottom: title, subtitle, framing line, the
    // usage example (svgo only), then the reference — no separate full-width
    // header, so the two-column grid starts at the very top of the page and
    // never changes shape partway down.
    let content : Array[Html] = [
      h1(class="display text-page", t("MoonBit API", "MoonBit API")),
      div(class="mt-3 flex flex-wrap items-baseline gap-2 text-sm text-ink-2", [
        code(class="text-code text-muted", pkg.short),
        span("·"),
        span(package_title(short_name(pkg))),
      ]),
      // one summary sentence: what the package does, then where the other
      // two entry points are — not three lines repeating the same pointer
      p(
        class="mt-4 max-w-read text-base text-ink-2",
        [
          text(package_blurb(short_name(pkg))),
          text(" "),
          ..tm(
            [
              text("For JavaScript, see the "),
              a(class="text-ink-2", href=NPM_URL, "npm package README"),
              text("; for the command line, "),
              code("svgo-mbt -h"),
              text("."),
            ],
            [
              text("JavaScript 参见 "),
              a(class="text-ink-2", href=NPM_URL, "npm 包 README"),
              text("；命令行参见 "),
              code("svgo-mbt -h"),
              text("。"),
            ],
          ),
        ],
      ),
      // meta line: the zh docs-are-English note (zh only) and the
      // mooncakes.io pointer — both belong under the title, not stranded
      // between the mobile TOC and the title (see side_nav)
      p(
        class="mt-2 max-w-read text-code text-ink-2",
        [
          if lang.val == Zh {
            text("说明文字取自源码文档注释，为英文。 ")
          } else {
            nothing
          },
          ..tm(
            [
              text("Also on "),
              a(class="text-ink-2", href=MOONCAKES_URL, "mooncakes.io"),
              text("."),
            ],
            [
              text("另见 "),
              a(class="text-ink-2", href=MOONCAKES_URL, "mooncakes.io"),
              text("。"),
            ],
          ),
        ],
      ),
    ]
    if short_name(pkg) == "svgo" {
      content.push(usage_example(emit))
    }
    for group in kind_groups {
      let (kind, (en, zh)) = group
      let items = items_of_kind(pkg, kind)
      if items.is_empty() {
        continue
      }
      content.push(h2(class="display", t(en, zh)))
      for it in items {
        content.push(api_member(pkg, it, emit))
      }
    }
    div(class="page pt-14", [
      top_nav(Api(short_name(pkg)), "API", prefs, chrome.emit),
      div(
        class="wrap grid gap-10 pb-20 pt-14 lg:grid-cols-[var(--api-side-w)_minmax(0,var(--api-main-w))]",
        [side_nav(pkg), main_(class="api-main min-w-0", content)],
      ),
      page_footer(route=Api(short_name(pkg))),
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
    let name = short_name(pkg)
    // wasm is excluded from the API pages (FFI exports only)
    if excluded_packages.contains(name) {
      continue
    }
    assert_true(api_package_names.contains(name), msg=pkg.short)
  }
}
