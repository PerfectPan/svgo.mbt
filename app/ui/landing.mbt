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
                "svgo.mbt is svgo's default optimizations, rewritten in MoonBit. It ships as one \{wasm_bytes / 1024} KB wasm file that runs in the browser, in Node, or as a command-line tool. Every optimization is checked against the original pixel by pixel, so your SVGs get smaller and still look the same.",
                "svgo.mbt 把 svgo 默认那套优化用 MoonBit 重写了一遍，打包成一个 \{wasm_bytes / 1024} KB 的 wasm 文件。浏览器里能跑，Node 里能跑，也有命令行版本。每一项优化都和原图逐像素比过：文件变小，图不会变样。",
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
          "Same pipeline, one fifth of the time.", "同一条流水线，五分之一的时间。",
        ),
        tm(
          [
            text(
              "How we measured: one Node process, the same files through svgo \{svgo_js_version} and svgo.mbt, both with multipass, both warmed up first. The files are real editor exports plus the classic big test SVGs. The MoonBit side even includes turning its result into JSON. Rerun it yourself with ",
            ),
            code("packages/compare/collect.mjs"),
            text(" (last run \{generated_on})."),
          ],
          [
            text(
              "怎么测的：同一个 Node 进程里，同样的文件分别过一遍 svgo \{svgo_js_version} 和 svgo.mbt，都开 multipass，都先热身。文件是真实的编辑器导出图，加上几张经典的大 SVG。MoonBit 这边连把结果转成 JSON 的时间都算进去了。想自己跑一遍用 ",
            ),
            code("packages/compare/collect.mjs"),
            text("（上次跑是 \{generated_on}）。"),
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
              "median speedup over svgo-js in the same process", "同进程下比 svgo-js 快多少，取中位数",
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
              "KB wasm-gc, no dependencies, loads in milliseconds", "KB 的 wasm-gc，零依赖，几毫秒加载完",
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
                text("When svgo-js is smaller, it's because of "),
                code("inlineStyles"),
                text("/"),
                code("minifyStyles"),
                text(". Those need a CSS parser, and we haven't built one yet."),
              ],
              [
                text("svgo-js 更小的那些文件，差在 "),
                code("inlineStyles"),
                text("/"),
                code("minifyStyles"),
                text("。这两个需要 CSS 解析器，我们还没做。"),
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
        t("Every plugin is a value.", "每个插件都是一个值。"),
        tm(
          [
            text("A plugin is just a value: "),
            code("{ name, description, run }"),
            text(
              ". The default set has \{count} of them, in the same order svgo uses. Each one says whether it changed anything, which is how multipass knows when to stop. The list below is read from the library while the page loads, optional plugins included.",
            ),
          ],
          [
            text("一个插件就是一个值："),
            code("{ name, description, run }"),
            text(
              "。默认 \{count} 个，顺序和 svgo 一样。每个插件会说自己改没改东西，multipass 靠这个知道什么时候停。下面这份列表是页面加载时直接从库里读出来的，包括两个可选插件。",
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
              "The wasm build is the main one. The same source also gives you a native CLI and a MoonBit library you can drop into your own tools. This very page uses it as a MoonBit dependency.",
              "主要产物是 wasm 版本。同一份代码还能编出原生 CLI，以及一个可以嵌进你自己工具里的 MoonBit 库。你现在看的这个页面，就是把它当 MoonBit 依赖来用的。",
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
            "One binary. Cold start is about 40× faster than the svgo CLI.", "就一个二进制文件。冷启动比 svgo 的 CLI 快大概 40 倍。",
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
            "Plain structs, no globals. The xml, path and plugins packages each work on their own.",
            "都是普通结构体，没有全局变量。xml、path、plugins 这几个包都能单独用。",
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
        t("Verified, not just smaller.", "不只变小了，还验证过。"),
        tm(
          [
            text(
              "Smaller is easy to claim, so we check. Every sample is rendered before and after with resvg and compared pixel by pixel. Plugin behavior is pinned by test fixtures in svgo's format, speed work has to reproduce the whole corpus byte for byte, and ",
            ),
            code("moon test"),
            text(
              " runs on wasm-gc, JS and native. Left is the original; right was optimized in your browser just now.",
            ),
          ],
          [
            text(
              "说\"变小了\"很容易，所以我们会验证。每张样图优化前后都用 resvg 渲染一次，逐像素比对。插件行为用 svgo 格式的测试用例钉死，性能改动必须把整个语料库逐字节复现，",
            ),
            code("moon test"),
            text(
              " 在 wasm-gc、JS、原生三个后端上跑。左边是原图，右边是刚刚在你浏览器里优化出来的。",
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
