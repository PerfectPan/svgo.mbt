///|
fn anchor(pkg : ApiPackage, name : String) -> String {
  pkg.short[1:].to_owned() + "-" + name
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
      pre(m.signature),
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
    pre(it.signature),
    doc_html(it.doc),
    if methods.is_empty() && impls.is_empty() {
      nothing
    } else {
      div(class="methods", [..methods, ..impls])
    },
  ])
}

///|
fn side_nav() -> Html {
  let entries : Array[Html] = []
  for pkg in api_packages {
    entries.push(h4(a(href="#/api#\{anchor(pkg, "pkg")}", pkg.short)))
    for it in pkg.items {
      entries.push(a(href="#/api#\{anchor(pkg, it.name)}", it.name))
    }
  }
  aside(
    class="api-side text-[13px] min-[901px]:sticky min-[901px]:top-20 min-[901px]:max-h-[calc(100vh-100px)] min-[901px]:self-start min-[901px]:overflow-auto",
    [
      p(
        class="mb-1.5 text-xs text-muted",
        tm(
          [
            text("From "),
            code("moon doc"),
            text(". Also on "),
            a(class="text-ink-2", href=MOONCAKES_URL, "mooncakes.io"),
          ],
          [
            text("来自 "),
            code("moon doc"),
            text("，"),
            a(class="text-ink-2", href=MOONCAKES_URL, "mooncakes.io"),
            text(" 上也有"),
          ],
        ),
      ),
      ..entries,
    ],
  )
}

///|
/// The API reference page.
pub fn api_page(chrome : Chrome) -> Val[Html] {
  chrome.prefs.view(p => {
    let sections : Array[Html] = []
    for pkg in api_packages {
      sections.push(h2(id=anchor(pkg, "pkg"), class="display", pkg.path))
      for it in pkg.items {
        sections.push(api_member(pkg, it))
      }
    }
    div(class="pt-[60px]", [
      top_nav(Api, "API", p, chrome.emit),
      page_head(
        t("API reference · from moon doc", "API 文档 · 来自 moon doc"),
        tm([text("Plain structs, "), span(class="grad", "no globals.")], [
          text("都是普通结构体，"),
          span(class="grad", "没有全局变量。"),
        ]),
        t(
          "The public API of PerfectPan/svgo and its packages, pulled from the doc comments in the source. Same text you see on mooncakes.io, and every item links to the file that defines it.",
          "PerfectPan/svgo 及其子包的公开接口，都是从源码里的文档注释提出来的，和 mooncakes.io 上看到的是同一份。每一项都能点进定义它的源文件。",
        ),
      ),
      div(
        class="wrap grid gap-10 pb-20 pt-2 min-[901px]:grid-cols-[240px_1fr]",
        [side_nav(), main_(class="api-main min-w-0", sections)],
      ),
      page_footer(),
    ])
  })
}
