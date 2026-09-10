///|
fn copy_pill(cmd : String) -> Html {
  span(class="install", [
    code(cmd),
    button(
      title=t("copy", "复制"),
      on_click=@rabbita.effect(fn() noraise { copy_text(cmd) }),
      attrs=Attrs::build().inner_html(
        (
          #|<svg viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.5"><rect x="5" y="5" width="8" height="8" rx="1.5"/><path d="M3 11V3.5A.5.5 0 0 1 3.5 3H11"/></svg>
        ),
      ),
      nothing,
    ),
  ])
}

///|
/// Median same-process speedup over svgo-js, from the generated data.
fn median_speedup() -> Double {
  let ratios = bench_rows.map(r => r.js_ms / r.mbt_ms)
  ratios.sort()
  ratios[ratios.length() / 2]
}

///|
fn hero(dark : Bool) -> Html {
  let times = to_fixed(median_speedup(), 0)
  let video_src = if dark { "hero-dark.mp4" } else { "hero.mp4" }
  let poster = if dark { "hero-dark-poster.jpg" } else { "hero-poster.jpg" }
  header(class="relative isolate overflow-hidden pb-16 pt-14", [
    div(
      class="pointer-events-none absolute inset-0 -z-10 overflow-hidden",
      attrs=Attrs::build().aria_hidden("true"),
      [
        span(
          class="blob -left-[8%] -top-[30%] size-[640px] bg-accent/20",
          nothing,
        ),
        span(
          class="blob -right-[6%] -top-[10%] size-[560px] bg-teal/20 [animation-delay:-7s]",
          nothing,
        ),
        span(
          class="blob -bottom-[25%] left-[42%] size-[480px] bg-amber-300/25 [animation-delay:-14s]",
          nothing,
        ),
      ],
    ),
    div(class="wrap", [
      div(
        class="grid items-center gap-12 max-[960px]:grid-cols-1 max-[960px]:gap-7 min-[961px]:grid-cols-[minmax(0,1.05fr)_minmax(0,1fr)]",
        [
          div([
            div(class="eyebrow rise", [
              span(class="dot", nothing),
              text(" MoonBit · WebAssembly · \{wasm_bytes / 1000} KB"),
            ]),
            h1(
              class="display rise mt-3.5 text-[clamp(42px,5.6vw,68px)] leading-[1.02]",
              style=["--d: 80ms"],
              tm(
                [
                  text("Smaller SVGs,"),
                  br(),
                  span(class="grad", "\{times}× faster."),
                ],
                [
                  text("更小的 SVG，"),
                  br(),
                  span(class="grad", "快 \{times} 倍。"),
                ],
              ),
            ),
            p(
              class="rise mt-[22px] max-w-[54ch] text-[17px] leading-relaxed text-ink-2",
              style=["--d: 160ms"],
              t(
                "svgo's 34 preset optimizations, rewritten in MoonBit and compiled to a single \{wasm_bytes / 1000} KB wasm file. Runs in the browser, in Node.js and on the command line. Every output is render-checked pixel by pixel: smaller files, identical rendering.",
                "svgo 预设的 34 个优化插件，用 MoonBit 完整重写，编译为一个 \{wasm_bytes / 1000} KB 的 wasm 文件，可在浏览器、Node.js 和命令行中使用。每次输出都经过逐像素渲染比对：文件更小，渲染结果不变。",
              ),
            ),
            div(
              class="rise mt-7 flex flex-wrap items-center gap-3",
              style=["--d: 240ms"],
              [
                a(
                  class="btn btn-primary",
                  href="#/playground",
                  t("Open the playground", "打开在线体验"),
                ),
                copy_pill("npm i @rivus/svgo"),
                copy_pill("moon add PerfectPan/svgo"),
              ],
            ),
          ]),
          div(
            class="rise relative aspect-video overflow-hidden rounded-[22px] border border-line bg-surface shadow-card",
            style=["--d: 200ms"],
            attrs=Attrs::build().aria_hidden("true"),
            [
              video(
                class="block size-full object-cover motion-reduce:hidden",
                autoplay=true,
                muted=true,
                loop_=true,
                preload="none",
                poster~,
                src=video_src,
                nothing,
              ),
              img(
                class="hidden size-full object-cover motion-reduce:block",
                src=poster,
                alt="",
              ),
              span(
                class="absolute bottom-3 left-3.5 rounded-full border border-line bg-bg/80 px-2.5 py-1 text-[11.5px] text-muted backdrop-blur-sm",
                t(
                  "one optimize() call, step by step · rendered with Remotion",
                  "一次 optimize() 调用的全过程 · 由 Remotion 渲染",
                ),
              ),
            ],
          ),
        ],
      ),
    ]),
  ])
}

///|
fn section_head(title : String, blurb : Array[Html]) -> Html {
  div(
    class="reveal mb-9 grid items-end gap-8 max-[800px]:gap-3 min-[801px]:grid-cols-[minmax(0,1fr)_minmax(0,1.3fr)]",
    [
      h2(class="display text-[clamp(30px,3.4vw,42px)] leading-[1.08]", title),
      p(class="max-w-[58ch] text-base text-ink-2", blurb),
    ],
  )
}

///|
fn nice_name(file : String) -> String {
  file.replace_all(old=".svg", new="").replace_all(old="_", new=" ")
}

///|
fn numbers_section() -> Html {
  let rows = bench_rows.copy()
  rows.sort_by((x, y) => x.original - y.original)
  let median = median_speedup()
  // log scale so 0.05 ms and 50 ms both stay visible
  let mut lo = 1.0e9
  let mut hi = 0.0
  for r in rows {
    for v in [r.mbt_ms, r.js_ms] {
      if v < lo {
        lo = v
      }
      if v > hi {
        hi = v
      }
    }
  }
  let lo = lo / 1.5
  let hi = hi * 1.15
  let width = fn(ms : Double) -> String {
    let w = @math.ln(ms / lo) / @math.ln(hi / lo) * 78.0
    "width: \{to_fixed(w, 2)}%"
  }
  let bar_rows = rows.mapi((idx, r) => {
    div(class="row", style=["--i: \{idx}"], [
      div(class="name", title=r.file, [
        text(nice_name(r.file)),
        small(fmt_kb(r.original)),
      ]),
      div(class="bars", [
        div(
          class="bar bar-a",
          style=[width(r.mbt_ms)],
          attrs=Attrs::build().data_set("label", "\{fmt_ms(r.mbt_ms)} ms"),
          nothing,
        ),
        div(
          class="bar bar-b",
          style=[width(r.js_ms)],
          attrs=Attrs::build().data_set("label", "\{fmt_ms(r.js_ms)} ms"),
          nothing,
        ),
      ]),
      div(class="ratio", "\{to_fixed(r.js_ms / r.mbt_ms, 1)}×"),
    ])
  })
  let size_rows = rows.map(r => {
    let cls = if r.mbt < r.js {
      "win"
    } else if r.mbt > r.js {
      "lose"
    } else {
      ""
    }
    tr([
      td(nice_name(r.file)),
      td(fmt_int(r.original)),
      td(class=cls, fmt_int(r.mbt)),
      td(fmt_int(r.js)),
    ])
  })
  section(id="numbers", class="py-20", [
    div(class="wrap", [
      section_head(
        t(
          "Same pipeline, a third of the time.", "同一条流水线，三分之一的时间。",
        ),
        [
          text(
            t(
              "svgo \{svgo_js_version} and svgo.mbt optimizing the same files in the same Node process, multipass on, both warmed up. Real editor exports and a few classic large SVGs.",
              "svgo \{svgo_js_version} 与 svgo.mbt 在同一个 Node 进程中处理相同的文件，均开启 multipass 并预热。样本为真实的编辑器导出文件和几张经典大图。",
            ),
          ),
        ],
      ),
      div(class="mb-5 grid grid-cols-3 gap-4 max-sm:grid-cols-1", [
        div(class="kpi reveal", [
          b(
            attrs=Attrs::build().data_set("count", to_fixed(median, 1)),
            "\{to_fixed(median, 1)}×",
          ),
          span(
            t(
              "median speedup over svgo-js in the same process", "同进程下相对 svgo-js 的加速比（中位数）",
            ),
          ),
        ]),
        div(class="kpi reveal", style=["--d: 90ms"], [
          b(
            attrs=Attrs::build().data_set(
              "count",
              (wasm_bytes / 1000).to_string(),
            ),
            "\{wasm_bytes / 1000}",
          ),
          span(
            t(
              "KB wasm-gc, no dependencies, loads in milliseconds", "KB 的 wasm-gc 模块，零依赖，毫秒级加载",
            ),
          ),
        ]),
        div(class="kpi reveal", style=["--d: 180ms"], [
          b("0 px"),
          span(
            t(
              "of rendering difference across every editor export in the corpus (resvg + pixelmatch)",
              "语料库中所有编辑器导出文件的渲染差异（resvg + pixelmatch）",
            ),
          ),
        ]),
      ]),
      div(class="grid gap-5 min-[901px]:grid-cols-[1.3fr_1fr]", [
        div(class="card reveal", [
          h3(t("Time per call", "单次调用耗时")),
          div(
            class="sub",
            t(
              "milliseconds, lower is better · log scale", "毫秒，越低越好 · 对数刻度",
            ),
          ),
          div(class="grid gap-3", bar_rows),
          div(class="legend", [
            span([i(class="bg-grad", nothing), text("svgo.mbt (wasm-gc)")]),
            span([i(class="bg-bar-b", nothing), text("svgo-js")]),
          ]),
          p(
            class="mt-3.5 text-[12.5px] text-muted",
            tm(
              [
                text("Generated by "),
                code("packages/compare/collect.mjs"),
                text(" on \{generated_on}."),
              ],
              [
                text("数据由 "),
                code("packages/compare/collect.mjs"),
                text(" 于 \{generated_on} 生成。"),
              ],
            ),
          ),
        ]),
        div(class="card reveal", style=["--d: 120ms"], [
          h3(t("Output size", "输出大小")),
          div(
            class="sub",
            t("bytes after optimization", "优化后的字节数"),
          ),
          table(class="sizes", [
            thead([
              tr([
                th(t("file", "文件")),
                th(t("original", "原始")),
                th("svgo.mbt"),
                th("svgo-js"),
              ]),
            ]),
            tbody(size_rows),
          ]),
          p(
            class="mt-3.5 text-[12.5px] text-muted",
            tm(
              [
                text(
                  "Where svgo-js is smaller, the difference is a leading zero inside a style attribute and cubic curves that svgo also rewrites as quadratics (",
                ),
                code("q"),
                text("). Neither is implemented yet."),
              ],
              [
                text(
                  "svgo-js 更小的那几个文件，差在 style 属性里数字的前导零，以及 svgo 会把三次曲线改写成二次曲线（",
                ),
                code("q"),
                text("）。两项均尚未实现。"),
              ],
            ),
          ),
        ]),
      ]),
    ]),
  ])
}

///|
fn plugins_section() -> Html {
  let cards = @svgo.list_plugins().mapi((idx, item) => {
    let (name, desc, enabled) = item
    div(
      class=if enabled {
        "plugin reveal stagger"
      } else {
        "plugin plugin-optional reveal stagger"
      },
      style=["--i: \{idx}"],
      [code(name), p(plugin_description(name, desc, lang.val))],
    )
  })
  let count = @svgo.list_plugins().filter(it => it.2).length()
  section(id="plugins", class="border-y border-line bg-bg-2 py-20", [
    div(class="wrap", [
      section_head(
        t("Every plugin is a value.", "每个插件都是一个值。"),
        tm(
          [
            text("A plugin is a value: "),
            code("{ name, description, run }"),
            text(
              ". The default set contains \{count}, in svgo's order; each reports whether it changed the document, which is what drives multipass. The list below is read from the library at page load, optional plugins included.",
            ),
          ],
          [
            text("插件是一个值："),
            code("{ name, description, run }"),
            text(
              "。默认集合包含 \{count} 个，顺序与 svgo 一致；每个插件返回是否修改了文档，multipass 以此判断何时结束。以下列表在页面加载时从库中读取，包含三个可选插件。",
            ),
          ],
        ),
      ),
      div(
        class="grid grid-cols-[repeat(auto-fill,minmax(250px,1fr))] gap-2.5",
        cards,
      ),
    ]),
  ])
}

///|
fn snippet(
  idx : Int,
  title : String,
  sub : String,
  lines : Array[Html],
) -> Html {
  div(class="use reveal", style=["--d: \{idx * 110}ms"], [
    h3(title),
    div(class="sub", sub),
    pre(lines),
  ])
}

///|
fn k(s : String) -> Html {
  span(class="k", s)
}

///|
fn c(s : String) -> Html {
  span(class="c", s)
}

///|
fn use_section() -> Html {
  section(id="use", class="py-20", [
    div(class="wrap", [
      section_head(
        t("Three ways in, one codebase.", "三种用法，一套代码。"),
        [
          text(
            t(
              "The wasm build is the primary artifact. The same source also compiles to a native CLI and a MoonBit library for use in other tools; this page uses it as a MoonBit dependency.",
              "wasm 是主要产物。同一份源码还可编译为原生 CLI 和 MoonBit 库，供其他工具直接引用；本页面即以 MoonBit 依赖的方式使用它。",
            ),
          ),
        ],
      ),
      div(class="grid gap-4 min-[901px]:grid-cols-3", [
        snippet(
          0,
          "JavaScript · npm",
          t(
            "Node 24+, Chrome 130+, Firefox 134+, Safari 18.4+ (JS String Builtins).",
            "Node 24+、Chrome 130+、Firefox 134+、Safari 18.4+（JS String Builtins）。",
          ),
          [
            k("import"),
            text(" { optimize } "),
            k("from"),
            text(" \"@rivus/svgo\";\n\n"),
            k("const"),
            text(" r = "),
            k("await"),
            text(" optimize(svg, { precision: 3 });\nr.data          "),
            c("// optimized SVG"),
            text("\nr.originalSize  "),
            c("// 836"),
            text("\nr.size          "),
            c("// 276"),
            text("\nr.applied       "),
            c("// [\"convertPathData\", ...]"),
          ],
        ),
        snippet(
          1,
          t("Command line · native", "命令行 · 原生"),
          t(
            "A single binary. A complete run on a small icon takes about 10 ms; the svgo CLI takes about 160 ms, most of it Node start-up.",
            "单个二进制文件。处理一个小图标的完整耗时约 10 毫秒，svgo CLI 约 160 毫秒，其中大部分为 Node 启动时间。",
          ),
          [
            text(
              "svgo-mbt icon.svg --stats\nsvgo-mbt icon.svg -o out.svg -p 2 --pretty\nsvgo-mbt icon.svg --json ",
            ),
            c("| jq .size"),
            text(
              "\nsvgo-mbt icon.svg --plugins convertPathData,sortAttrs\nsvgo-mbt --list",
            ),
          ],
        ),
        snippet(
          2,
          t("MoonBit · library", "MoonBit · 库"),
          t(
            "Plain structs, no global state. The xml, path and plugins packages can each be used on their own.",
            "普通结构体，无全局状态。xml、path、plugins 三个包均可单独使用。",
          ),
          highlight_mbt(
            t(
              "let r = @svgo.optimize(svg, config={\n  ..@svgo.Config::default(),\n  precision: 2,\n})\nr.saved_percent()  // 67.0\n\n// or just the path optimizer\n@path.optimize_string(\"M 0,0 L 10,10\")  // \"M0 0l10 10\"",
              "let r = @svgo.optimize(svg, config={\n  ..@svgo.Config::default(),\n  precision: 2,\n})\nr.saved_percent()  // 67.0\n\n// 或者只用路径优化器\n@path.optimize_string(\"M 0,0 L 10,10\")  // \"M0 0l10 10\"",
            ),
          ),
        ),
      ]),
    ]),
  ])
}

///|
fn cli_section() -> Html {
  let flag_rows = cli_flags.map(f => tr([td([code(f.flag)]), td(f.description)]))
  section(id="cli", class="border-y border-line bg-bg-2 py-20", [
    div(class="wrap", [
      section_head(
        t(
          "The command line, in one binary.", "命令行，一个二进制文件。",
        ),
        tm(
          [
            text("One MoonBit source, two builds. "),
            code("npx"),
            text(
              " runs the Node build with nothing to install; the native binary needs no runtime and processes a small icon in about 10 ms, against about 50 ms for the Node build. It reads from stdin and writes to stdout, or walks a directory recursively. The flag table below is parsed from the CLI's own usage text, so it stays in sync.",
            ),
          ],
          [
            text("同一份 MoonBit 源码，两种构建。"),
            code("npx"),
            text(
              " 运行 Node 版，无需安装；原生二进制不依赖运行时，处理一个小图标约 10 毫秒，Node 版约 50 毫秒。支持从 stdin 读入、向 stdout 输出，也可递归处理整个目录。下表由 CLI 的帮助文本解析生成，与实际用法保持一致。",
            ),
          ],
        ),
      ),
      div(class="grid gap-5 min-[901px]:grid-cols-[1fr_1fr]", [
        div(class="card reveal", [
          h3(t("Install and run", "安装并运行")),
          div(
            class="sub",
            t(
              "npx runs the Node build of the CLI; the native binary starts faster.",
              "npx 运行 CLI 的 Node 版；原生二进制启动更快。",
            ),
          ),
          div(class="flex flex-wrap items-center gap-3", [
            copy_pill("npx @rivus/svgo in.svg -o out.svg"),
          ]),
          div(class="mt-4 use", [
            pre([
              text("# read from stdin, write to stdout\n"),
              text("cat in.svg | svgo-mbt > out.svg\n\n"),
              text("# optimize every SVG under a directory into another\n"),
              text("svgo-mbt -r ./icons -o ./icons-opt"),
            ]),
          ]),
        ]),
        div(class="card reveal", style=["--d: 90ms"], [
          h3(t("Flags", "参数")),
          div(
            class="sub",
            t(
              "repeatable means you can pass it more than once.", "repeatable 表示可以传多次。",
            ),
          ),
          div(class="overflow-x-auto", [
            table(class="sizes cli-flags", [
              thead([
                tr([th(t("flag", "参数")), th(t("what it does", "作用"))]),
              ]),
              tbody(flag_rows),
            ]),
          ]),
        ]),
      ]),
    ]),
  ])
}

///|
fn gallery_section() -> Html {
  let shots = samples.mapi((idx, s) => {
    let o = run_optimize(s.svg)
    div(class="shot reveal stagger", style=["--i: \{idx}"], [
      div(class="pair", [
        div(attrs=Attrs::build().inner_html(s.svg), nothing),
        div(attrs=Attrs::build().inner_html(o.data), nothing),
      ]),
      div(class="meta", [
        span(class="flex items-baseline gap-2", [
          b(class="font-semibold text-ink", s.name),
          small(class="text-muted", fmt_kb(o.original_size)),
        ]),
        span([
          text("→ "),
          b(fmt_kb(o.size)),
          text(" · "),
          span(class="pill", "−\{fmt_pct(o.saved_percent(), digits=0)}%"),
        ]),
      ]),
    ])
  })
  section(id="verified", class="border-y border-line bg-bg-2 py-20", [
    div(class="wrap", [
      section_head(
        t("Verified, not just smaller.", "不只变小了，还验证过。"),
        tm(
          [
            text(
              "Every sample is rendered before and after with resvg and compared pixel by pixel. Plugin behavior is pinned by test fixtures in svgo's format, performance changes must reproduce the whole corpus byte for byte, ",
            ),
            code("moon test"),
            text(
              " runs on the JS and native backends, and the wasm build runs the same fixtures under Node. Left: the original. Right: optimized in your browser just now.",
            ),
          ],
          [
            text(
              "每张样图在优化前后各用 resvg 渲染一次，逐像素比对。插件行为由 svgo 格式的测试用例固定；性能改动须在整个语料库上逐字节复现；",
            ),
            code("moon test"),
            text(
              " 覆盖 JS 与原生后端，wasm 构建在 Node 中运行同一套用例。左侧为原图，右侧为刚在浏览器中优化的结果。",
            ),
          ],
        ),
      ),
      div(
        class="grid grid-cols-[repeat(auto-fill,minmax(300px,1fr))] gap-4",
        shots,
      ),
    ]),
  ])
}

///|
/// The landing page. Re-rendered when the preferences change.
pub fn landing_page(chrome : Chrome) -> Val[Html] {
  chrome.prefs.view(p => {
    div(class="pt-[60px]", [
      top_nav(Landing, "0.1", p, chrome.emit),
      hero(p.dark),
      numbers_section(),
      plugins_section(),
      use_section(),
      cli_section(),
      gallery_section(),
      page_footer(),
    ])
  })
}
