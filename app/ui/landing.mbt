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
  header(class="relative isolate overflow-hidden pb-16 pt-[72px]", [
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
              text(" MoonBit · WebAssembly · \{wasm_bytes / 1024} KB"),
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
                "svgo.mbt is svgo's preset-default pipeline rewritten in MoonBit and compiled to one wasm-gc module. It runs in the browser, in Node, or as a native binary, produces the same output as svgo on the corpus, and every optimisation is checked with pixel diffs before it ships.",
                "svgo.mbt 用 MoonBit 重写了 svgo 的 preset-default 优化流水线，编译成一个 wasm-gc 模块。它可以跑在浏览器、Node 或原生二进制里，在语料库上与 svgo 输出一致，每一项优化在发布前都经过逐像素比对。",
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
                copy_pill("npm i svgo-mbt"),
                copy_pill("moon add perfectpan/svgo"),
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
                  "what one optimize() call does · rendered with Remotion", "一次 optimize() 调用做了什么 · Remotion 渲染",
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
          "Same pipeline, one fifth of the time.", "同一条流水线，五分之一的时间。",
        ),
        tm(
          [
            text(
              "Measured in one Node process against svgo \{svgo_js_version}, both with multipass, on real editor exports and the classic large test files. The MoonBit side pays for JSON serialisation of the result; the JS side is warm. Numbers regenerate from ",
            ),
            code("packages/compare/collect.mjs"),
            text(" (\{generated_on})."),
          ],
          [
            text(
              "在同一个 Node 进程里与 svgo \{svgo_js_version} 对比，双方都开 multipass，样本是真实的编辑器导出文件和经典的大型测试文件。MoonBit 一侧还额外付出了结果 JSON 序列化的开销，JS 一侧则是预热后的。数据由 ",
            ),
            code("packages/compare/collect.mjs"),
            text(" 重新生成（\{generated_on}）。"),
          ],
        ),
      ),
      div(class="mb-5 grid grid-cols-3 gap-4 max-sm:grid-cols-1", [
        div(class="kpi reveal", [
          b(
            attrs=Attrs::build().data_set("count", to_fixed(median, 1)),
            "\{to_fixed(median, 1)}×",
          ),
          span(
            t(
              "median speedup over svgo-js, same process", "相对 svgo-js 的中位加速比，同进程",
            ),
          ),
        ]),
        div(class="kpi reveal", style=["--d: 90ms"], [
          b(
            attrs=Attrs::build().data_set(
              "count",
              (wasm_bytes / 1024).to_string(),
            ),
            "\{wasm_bytes / 1024}",
          ),
          span(
            t(
              "KB of wasm-gc, no dependencies, streams and instantiates in milliseconds",
              "KB 的 wasm-gc，零依赖，毫秒级流式实例化",
            ),
          ),
        ]),
        div(class="kpi reveal", style=["--d: 180ms"], [
          b("0 px"),
          span(
            t(
              "rendering differences on every editor export in the corpus (resvg + pixelmatch)",
              "语料库中所有编辑器导出文件的渲染差异（resvg + pixelmatch）",
            ),
          ),
        ]),
      ]),
      div(class="grid gap-5 min-[901px]:grid-cols-[1.3fr_1fr]", [
        div(class="card reveal", [
          h3(t("Time per optimisation", "单次优化耗时")),
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
        ]),
        div(class="card reveal", style=["--d: 120ms"], [
          h3(t("Output size", "输出大小")),
          div(
            class="sub",
            t("bytes after optimisation", "优化后的字节数"),
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
                text("Where svgo-js wins it is through "),
                code("inlineStyles"),
                text("/"),
                code("minifyStyles"),
                text(", which need a CSS parser and are on the roadmap."),
              ],
              [
                text("svgo-js 领先的地方来自 "),
                code("inlineStyles"),
                text("/"),
                code("minifyStyles"),
                text(
                  "，它们需要一个 CSS 解析器，已在路线图上。",
                ),
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
      [code(name), p(desc)],
    )
  })
  let count = @svgo.list_plugins().filter(it => it.2).length()
  section(id="plugins", class="border-y border-line bg-bg-2 py-20", [
    div(class="wrap", [
      section_head(
        t("Every optimisation is a value.", "每一项优化都是一个值。"),
        tm(
          [
            text("A plugin is "),
            code("{ name, description, run }"),
            text(
              ". The preset is an array literal in svgo's order, the CLI and the playground list it, and each one reports whether it changed the tree so multipass knows when to stop. \{count} plugins ship today; this list comes straight from the library at runtime.",
            ),
          ],
          [
            text("一个插件就是 "),
            code("{ name, description, run }"),
            text(
              "。预设是一个按 svgo 顺序排列的数组字面量，CLI 和在线体验都直接列出它；每个插件都会报告自己是否改动了树，multipass 据此决定何时停止。目前内置 \{count} 个插件，下面这份列表是运行时直接从库里读出来的。",
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
              "The wasm build is the primary artifact. The same source also produces a native CLI and a MoonBit library you can embed in your own tooling. This very page imports it as a MoonBit dependency.",
              "wasm 构建是主要产物。同一份源码还产出一个原生 CLI 和一个可以嵌进你自己工具链的 MoonBit 库。你正在看的这个页面就是把它当作 MoonBit 依赖引入的。",
            ),
          ),
        ],
      ),
      div(class="grid gap-4 min-[901px]:grid-cols-3", [
        snippet(
          0,
          "JavaScript · npm",
          t(
            "Node 22+, Chrome 130+, Firefox 134+, Safari 18.4+ (JS String Builtins).",
            "Node 22+、Chrome 130+、Firefox 134+、Safari 18.4+（JS String Builtins）。",
          ),
          [
            k("import"),
            text(" { optimize } "),
            k("from"),
            text(" \"svgo-mbt\";\n\n"),
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
            "A single binary; cold start is about 40× faster than the svgo CLI.",
            "单个二进制文件，冷启动比 svgo CLI 快约 40 倍。",
          ),
          [
            text(
              "svgo icon.svg --stats\nsvgo icon.svg -o out.svg -p 2 --pretty\nsvgo icon.svg --json ",
            ),
            c("| jq .size"),
            text(
              "\nsvgo icon.svg --plugins convertPathData,sortAttrs\nsvgo --list",
            ),
          ],
        ),
        snippet(
          2,
          t("MoonBit · library", "MoonBit · 库"),
          t(
            "Plain structs, no globals; parse, plugins and path packages are usable on their own.",
            "纯结构体，没有全局状态；解析、插件和路径包都可以单独使用。",
          ),
          [
            k("let"),
            text(
              " r = @svgo.optimize(svg, config={\n  ..@svgo.Config::default(),\n  precision: 2,\n})\nr.saved_percent()  ",
            ),
            c("// 67.0"),
            text("\n\n"),
            c(
              t(
                "// or just the path optimizer", "// 或者只用路径优化器",
              ),
            ),
            text("\n@path.optimize_string(\"M 0,0 L 10,10\")  "),
            c("// \"M0 0l10 10\""),
          ],
        ),
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
        t(
          "Verified, not just smaller.", "不只是更小，而且经过验证。",
        ),
        tm(
          [
            text(
              "Every fixture is rasterised before and after with resvg and compared pixel by pixel. Plugin behaviour is locked in svgo-style fixture files, performance changes must reproduce the corpus byte for byte, and ",
            ),
            code("moon test"),
            text(
              " runs on wasm-gc, JS and native. Left: the original. Right: svgo.mbt output, optimized just now in your browser.",
            ),
          ],
          [
            text(
              "每个样例都用 resvg 在优化前后各栅格化一次，逐像素比对。插件行为锁在 svgo 风格的 fixture 文件里，性能改动必须逐字节复现整个语料库，",
            ),
            code("moon test"),
            text(
              " 在 wasm-gc、JS 和原生三个后端上运行。左边是原图，右边是刚刚在你浏览器里由 svgo.mbt 优化后的输出。",
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
      gallery_section(),
      page_footer(),
    ])
  })
}
