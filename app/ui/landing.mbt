///|
// ---------------------------------------------------------------- hero demo

///|
priv struct DemoModel {
  source : String
  selected : String
  outcome : Outcome
} derive(Eq)

///|
priv enum DemoMsg {
  Edit(String)
  Pick(String)
}

///|
fn demo_update(m : DemoModel, msg : DemoMsg) -> DemoModel {
  match msg {
    Edit(src) => { source: src, selected: "", outcome: run_optimize(src), }
    Pick(name) => {
      let svg = samples.iter().find_first(s => s.name == name).map(s => s.svg)
      match svg {
        Some(svg) =>
          { source: svg, selected: name, outcome: run_optimize(svg), }
        None => m
      }
    }
  }
}

///|
fn demo_view(m : DemoModel, emit : Emit[DemoMsg]) -> Html {
  let tabs = samples.map(s => {
    button(
      class="chip",
      attrs=Attrs::build().aria_selected(
        if m.selected == s.name {
          "true"
        } else {
          "false"
        },
      ),
      on_click=emit(Pick(s.name)),
      s.name,
    )
  })
  div(
    class="rise mt-12 overflow-hidden rounded-card border border-line bg-surface shadow-card",
    style=["--d: 360ms"],
    [
      div(
        class="flex flex-wrap items-center justify-between gap-4 border-b border-line bg-surface-2 px-4 py-3",
        [
          div(class="flex gap-1", attrs=Attrs::build().role("tablist"), tabs),
          span(
            class="text-[13px] text-muted",
            "running in your browser · MoonBit compiled to JS · edit the left side",
          ),
        ],
      ),
      div(class="grid grid-cols-2 max-[800px]:grid-cols-1", [
        div(class="pane", [
          span(class="pane-label", "input"),
          textarea(
            value=m.source,
            on_input=emit.map(s => Edit(s)),
            attrs=Attrs::build().spellcheck(false).aria_label("SVG input"),
            nothing,
          ),
          svg_preview(m.source),
        ]),
        div(
          class="pane border-l border-line max-[800px]:border-l-0 max-[800px]:border-t",
          [
            span(class="pane-label", "svgo.mbt output"),
            textarea(
              value=if m.outcome.error != "" {
                m.outcome.error
              } else {
                m.outcome.data
              },
              read_only=true,
              attrs=Attrs::build().aria_label("optimized SVG"),
              nothing,
            ),
            svg_preview(m.outcome.data),
          ],
        ),
      ]),
      stats_bar(
        m.outcome,
        "\{m.outcome.passes} pass\{if m.outcome.passes == 1 { "" } else { "es" }} · \{m.outcome.applied.length()} plugins changed something",
      ),
    ],
  )
}

///|
fn demo() -> Val[Html] {
  let first = samples.iter().find_first(s => s.file == "sketch-icon.svg")
  let first = match first {
    Some(s) => s
    None => samples[0]
  }
  let initial : DemoModel = {
    source: first.svg,
    selected: first.name,
    outcome: run_optimize(first.svg),
  }
  let (model, emit) = @rabbita.create_pure_state(initial, update=demo_update)
  model.view(m => demo_view(m, emit))
}

///|
// ---------------------------------------------------------------- sections

///|
fn copy_pill(cmd : String) -> Html {
  span(class="install", [
    code(cmd),
    button(
      title="copy",
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
fn hero(demo_html : Html) -> Html {
  header(class="relative isolate overflow-hidden pb-10 pt-[72px]", [
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
              [
                text("Smaller SVGs."),
                br(),
                span(class="grad", "No Node required."),
              ],
            ),
            p(
              class="rise mt-[22px] max-w-[54ch] text-[17px] leading-relaxed text-ink-2",
              style=["--d: 160ms"],
              "svgo.mbt is an SVG optimizer written in MoonBit and compiled to one wasm-gc module. Same plugin pipeline as svgo's preset-default, a fraction of the runtime: it runs in the browser, in Node 22+, or as a 1 MB native binary, and every optimisation is checked with pixel diffs before it ships.",
            ),
            div(
              class="rise mt-7 flex flex-wrap items-center gap-3",
              style=["--d: 240ms"],
              [
                a(
                  class="btn btn-primary",
                  href="#/playground",
                  "Open the playground",
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
                poster="hero-poster.jpg",
                src="hero.mp4",
                nothing,
              ),
              img(
                class="hidden size-full object-cover motion-reduce:block",
                src="hero-poster.jpg",
                alt="",
              ),
              span(
                class="absolute bottom-3 left-3.5 rounded-full border border-line bg-bg/80 px-2.5 py-1 text-[11.5px] text-muted backdrop-blur-sm",
                "what one optimize() call does · rendered with Remotion",
              ),
            ],
          ),
        ],
      ),
      demo_html,
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
  // median speedup
  let ratios = rows.map(r => r.js_ms / r.mbt_ms)
  ratios.sort()
  let median = ratios[ratios.length() / 2]
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
      section_head("Same pipeline, one fifth of the time.", [
        text(
          "Measured in one Node process against svgo \{svgo_js_version}, both with multipass, on real editor exports and the classic large test files. The MoonBit side pays for JSON serialisation of the result; the JS side is warm. Numbers regenerate from ",
        ),
        code("packages/compare/collect.mjs"),
        text(" (\{generated_on})."),
      ]),
      div(class="mb-5 grid grid-cols-3 gap-4 max-sm:grid-cols-1", [
        div(class="kpi reveal", [
          b(
            attrs=Attrs::build().data_set("count", to_fixed(median, 1)),
            "\{to_fixed(median, 1)}×",
          ),
          span("median speedup over svgo-js, same process"),
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
            "KB of wasm-gc, no dependencies, streams and instantiates in milliseconds",
          ),
        ]),
        div(class="kpi reveal", style=["--d: 180ms"], [
          b("0 px"),
          span(
            "rendering differences on every editor export in the corpus (resvg + pixelmatch)",
          ),
        ]),
      ]),
      div(class="grid gap-5 min-[901px]:grid-cols-[1.3fr_1fr]", [
        div(class="card reveal", [
          h3("Time per optimisation"),
          div(class="sub", "milliseconds, lower is better · log scale"),
          div(class="grid gap-3", bar_rows),
          div(class="legend", [
            span([i(class="bg-grad", nothing), text("svgo.mbt (wasm-gc)")]),
            span([i(class="bg-bar-b", nothing), text("svgo-js")]),
          ]),
        ]),
        div(class="card reveal", style=["--d: 120ms"], [
          h3("Output size"),
          div(class="sub", "bytes after optimisation"),
          table(class="sizes", [
            thead([
              tr([th("file"), th("original"), th("svgo.mbt"), th("svgo-js")]),
            ]),
            tbody(size_rows),
          ]),
          p(class="mt-3.5 text-[12.5px] text-muted", [
            text("Where svgo-js wins it is through "),
            code("inlineStyles"),
            text("/"),
            code("minifyStyles"),
            text(", which need a CSS parser and are on the roadmap."),
          ]),
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
      section_head("Every optimisation is a value.", [
        text("A plugin is "),
        code("{ name, description, run }"),
        text(
          ". The preset is an array literal in svgo's order, the CLI and the playground list it, and each one reports whether it changed the tree so multipass knows when to stop. \{count} plugins ship today; this list comes straight from the library at runtime.",
        ),
      ]),
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
      section_head("Three ways in, one codebase.", [
        text(
          "The wasm build is the primary artifact. The same source also produces a native CLI and a MoonBit library you can embed in your own tooling. This very page imports it as a MoonBit dependency.",
        ),
      ]),
      div(class="grid gap-4 min-[901px]:grid-cols-3", [
        snippet(
          0,
          "JavaScript · npm",
          "Node 22+, Chrome 130+, Firefox 134+, Safari 18.4+ (JS String Builtins).",
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
          "Command line · native",
          "A single binary; cold start is about 40× faster than the svgo CLI.",
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
          "MoonBit · library",
          "Plain structs, no globals; parse, plugins and path packages are usable on their own.",
          [
            k("let"),
            text(
              " r = @svgo.optimize(svg, config={\n  ..@svgo.Config::default(),\n  precision: 2,\n})\nr.saved_percent()  ",
            ),
            c("// 67.0"),
            text("\n\n"),
            c("// or just the path optimizer"),
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
        code(s.file),
        span([
          text("\{o.original_size} → "),
          b("\{o.size} B"),
          text(" · "),
          span(class="pill", "−\{fmt_pct(o.saved_percent(), digits=0)}%"),
        ]),
      ]),
    ])
  })
  section(id="verified", class="border-y border-line bg-bg-2 py-20", [
    div(class="wrap", [
      section_head("Verified, not just smaller.", [
        text(
          "Every fixture is rasterised before and after with resvg and compared pixel by pixel. Plugin behaviour is locked in svgo-style fixture files, performance changes must reproduce the corpus byte for byte, and ",
        ),
        code("moon test"),
        text(
          " runs on wasm-gc, JS and native. Left: editor export. Right: svgo.mbt output, optimized just now in your browser.",
        ),
      ]),
      div(
        class="grid grid-cols-[repeat(auto-fill,minmax(240px,1fr))] gap-3.5",
        shots,
      ),
    ]),
  ])
}

///|
/// The landing page.
pub fn landing_page() -> Val[Html] {
  demo().map(demo_html => {
    div([
      top_nav(Landing, "0.1"),
      hero(demo_html),
      numbers_section(),
      plugins_section(),
      use_section(),
      gallery_section(),
      page_footer(),
    ])
  })
}
