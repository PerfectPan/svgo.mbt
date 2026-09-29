///|
priv struct LandingState {
  tab : Int
  /// index into `package_managers` for the npm tab's install command
  pm : Int
} derive(Eq)

///|
priv enum LandingMsg {
  SelectTab(Int)
  SelectPm(Int)
  Copy(String)
}

///|
fn copy_pill(cmd : String, emit : Emit[LandingMsg]) -> Html {
  div(
    class="install flex items-center justify-between gap-3 rounded-full border border-line-2 bg-card px-4.5 py-3",
    [
      code(t(cmd, cmd)),
      button(
        class="min-w-12 font-mono text-xs underline underline-offset-[--spacing(0.75)]",
        attrs=Attrs::build().aria_label(t("Copy \{cmd}", "复制 \{cmd}")),
        on_click=emit(Copy(cmd)),
        t("copy", "复制"),
      ),
    ],
  )
}

///|
/// A code block in the install tabs with a "copy" in its corner, the same
/// mono underlined action as the install line above it (`copy_pill`), set
/// on the same right edge. `render` turns the source into the block's
/// content (a highlighter, or plain text for commands); copy takes the
/// source as written.
fn code_card(
  source : String,
  render : (String) -> Array[Html],
  emit : Emit[LandingMsg],
) -> Html {
  div(class="code-card", [
    pre(render(source)),
    button(
      class="code-card-copy",
      attrs=Attrs::build().aria_label(t("Copy code", "复制代码")),
      on_click=emit(Copy(source)),
      t("copy", "复制"),
    ),
  ])
}

///|
/// The middle value of a non-empty array (the mean of the two middle values
/// when its length is even).
fn median(values : Array[Double]) -> Double {
  let sorted = values.copy()
  sorted.sort()
  let middle = sorted.length() / 2
  if sorted.length() % 2 == 0 {
    (sorted[middle - 1] + sorted[middle]) / 2.0
  } else {
    sorted[middle]
  }
}

///|
/// The median of one timing across every benchmarked file.
fn median_bench_ms(pick : (BenchRow) -> Double) -> Double {
  median(bench_rows.map(pick))
}

///|
fn median_speedup() -> Double {
  let ratios = bench_rows.map(r => r.js_ms / r.mbt_ms)
  median(ratios)
}

///|
/// Package managers offered in the npm tab: name and install command.
let package_managers : Array[(String, String)] = [
  ("npm", "npm i @rivus/svgo"),
  ("pnpm", "pnpm add @rivus/svgo"),
  ("yarn", "yarn add @rivus/svgo"),
  ("bun", "bun add @rivus/svgo"),
]

///|
/// A collapsed-by-default landing section: `<details>` with a styled
/// summary, closed until the reader opens it.
fn landing_details(summary : String, children : Array[Html]) -> Html {
  node("details", Attrs::build().class("landing-details reveal"), [
    node("summary", Attrs::build().class("landing-details-summary"), summary),
    div(class="landing-details-body", children),
  ])
}

///|
/// A number and its unit, styled as the site's shared "hero evidence"
/// figure: the number is set at the ancestor's font size, the unit rides at
/// 0.45em beside it. `id` is set on the number span alone, so a caller can
/// animate just the digits in place (see the hero byte counter).
fn display_measure(value : String, unit : String, id? : String = "") -> Html {
  let number = if id == "" {
    span(class="display-number", value)
  } else {
    span(id~, class="display-number", value)
  }
  span(class="display-measure", [number, span(class="display-unit", unit)])
}

///|
fn file_label(file : String) -> String {
  match file {
    "Ghostscript_Tiger.svg" => t("Tiger", "老虎")
    "SVG_logo.svg" => t("SVG logo", "SVG 标志")
    "Python_logo_and_wordmark.svg" => t("Python logo", "Python 标志")
    "World_map_-_low_resolution.svg" => t("World map", "世界地图")
    "sketch-icon.svg" => t("Sketch icon", "Sketch 图标")
    "figma-export.svg" => t("Figma export", "Figma 导出")
    "illustrator-logo.svg" => t("Illustrator", "Illustrator")
    "inkscape-drawing.svg" => t("Inkscape", "Inkscape")
    "React-icon.svg" => t("React icon", "React 图标")
    "Tux.svg" => "Tux"
    _ => file
  }
}

///|
/// A logo rendered as an `<img>` from a data URI, so its own fill colours
/// stay intact regardless of stray ids in the optimized markup.
fn sample_preview(svg : String, class : String) -> Html {
  let source = svg
    .replace_all(old="%", new="%25")
    .replace_all(old="#", new="%23")
    .replace_all(old="<", new="%3C")
    .replace_all(old=">", new="%3E")
    .replace_all(old="\"", new="%22")
    .replace_all(old="\n", new="%0A")
    .replace_all(old="\r", new="%0D")
  div(class~, [@html.img(src="data:image/svg+xml," + source, alt="")])
}

///|
/// The hero: Nib, optimized live, with a counter that runs from the
/// original byte size down to the optimized one and a bar that shrinks to
/// match. `start_count` no-ops under `prefers-reduced-motion`, so the
/// server-rendered end state (the optimized size) is what a reduced-motion
/// reader sees throughout.
fn hero(emit : Emit[LandingMsg]) -> Html {
  let mascot = samples[0]
  let output = run_optimize(mascot.svg)
  let kept = output.size.to_double() * 100.0 / output.original_size.to_double()
  div(
    class="wrap grid min-h-[calc(100svh-var(--nav-h))] grid-cols-1 content-center gap-12 py-16 max-sm:gap-6 max-sm:py-8 lg:grid-cols-[1.2fr_0.8fr] lg:items-center lg:gap-12",
    [
      div(class="hero-copy", [
        h1(class="display hero-title max-w-tight", [
          span(
            class="hero-line hero-line-1",
            t("Smaller SVGs,", "更小的 SVG，"),
          ),
          span(
            class="hero-line hero-line-2 accent",
            t(
              "\{to_fixed(median_speedup(), 1)}× faster",
              "快 \{to_fixed(median_speedup(), 1)} 倍",
            ),
          ),
        ]),
        p(
          class="lead hero-sub mb-8 max-w-copy text-lg text-ink-2 text-pretty",
          t(
            "svgo's preset-default, written in MoonBit, with the same rendering to the pixel. An npm package, a native CLI and a MoonBit library.",
            "svgo 的 preset-default，用 MoonBit 编写，渲染结果逐像素一致。提供 npm 包、原生 CLI 与 MoonBit 库。",
          ),
        ),
        div(class="cta-row flex flex-wrap items-center gap-5", [
          a(class="btn btn-coral", href="#/playground", [
            text(t("Open the playground", "打开在线体验")),
            span(class="arrow", "→"),
          ]),
          copy_pill("npm i @rivus/svgo", emit),
        ]),
      ]),
      div(class="hero-visual flex flex-col items-center gap-5.5 max-sm:gap-3", [
        // nib.svg's own drawn figure fills only about two-thirds of its
        // square viewBox (antenna to feet, arm to arm), so the frame is
        // sized well past the 240/300px the figure should read as, to land
        // the *visible character* at that size rather than its box.
        div(
          class="nib-frame relative w-full max-w-80 max-sm:max-w-62 lg:max-w-90",
          [
            div(
              attrs=Attrs::build().inner_html(output.data).aria_hidden("true"),
              nothing,
            ),
          ],
        ),
        div(class="byte-panel flex flex-col items-center gap-3.5 text-center", [
          node("strong", Attrs::build().class("hero-counter block"), [
            display_measure(fmt_int(output.size), "B", id="hero-byte-count"),
          ]),
          div(
            class="bar-track relative h-1.5 w-60 lg:w-64 overflow-hidden rounded-full bg-line",
            [
              div(
                class="bar-fill",
                style=[
                  "--kept: \{to_fixed(kept, 1)}%",
                  "--kept-frac: \{to_fixed(kept / 100.0, 4)}",
                ],
                nothing,
              ),
            ],
          ),
          p(
            class="byte-caption",
            t(
              "\{mascot.file} · −\{fmt_pct(output.saved_percent(), digits=0)}% · 0 px difference",
              "\{mascot.file} · −\{fmt_pct(output.saved_percent(), digits=0)}% · 0 px 差异",
            ),
          ),
        ]),
      ]),
    ],
  )
}

///|
/// One lane of the speed race: name above the bar, its length and animation
/// duration both driven by `share` (svgo.mbt's time as a fraction of
/// svgo's — 1.0 for svgo itself). Both lanes start together on reveal and
/// run at the same real-world speed (linear, `anim_ms` long), so the race
/// itself, not just the final bar length, shows the ratio. `arrival` is the
/// measured time this lane's bar is standing for (e.g. "1.2 ms"), shown
/// beside the bar's end once it arrives — `anim_ms` is the race's staged
/// wall-clock duration, not the value being illustrated, so the two are
/// threaded through separately. The svgo.mbt lane also carries a small
/// runner riding just ahead of its bar's tip to the same target (see
/// `.race-runner` in style.css), hopping once on arrival.
fn race_lane(
  name : String,
  share : Double,
  anim_ms : Double,
  arrival : String,
  mbt~ : Bool,
) -> Html {
  let width = to_fixed(share * 100.0, 2)
  div(class="race-lane", [
    span(class="race-label", name),
    div(class="race-track", [
      div(
        class=if mbt { "race-fill race-fill-mbt" } else { "race-fill" },
        style=["width: \{width}%", "--race-dur: \{to_fixed(anim_ms, 0)}ms"],
        nothing,
      ),
      span(
        class=if mbt { "race-arrival race-arrival-mbt" } else { "race-arrival" },
        style=["left: \{width}%", "--race-dur: \{to_fixed(anim_ms, 0)}ms"],
        arrival,
      ),
      if mbt {
        div(
          class="race-runner",
          style=[
            "--race-target: \{width}%",
            "--race-dur: \{to_fixed(anim_ms, 0)}ms",
          ],
          [illustration("nib-dash")],
        )
      } else {
        nothing
      },
    ]),
  ])
}

///|
/// "Time per file": two bars for the same metric as the hero's ratio (median
/// time per file, warmed up, same process): svgo at full width, svgo.mbt at
/// its share of that width, both driven from the same ratio the headline
/// states so the picture and the number never disagree. It is a real race:
/// both bars start together and run at the same real-world speed (svgo
/// takes 1200 ms, svgo.mbt 1200 ms / ratio), so the faster bar visibly
/// finishes first.
fn faster_screen() -> Html {
  let median_js = median_bench_ms(r => r.js_ms)
  let median_mbt = median_bench_ms(r => r.mbt_ms)
  let ratio = median_speedup()
  div(class="wrap screen screen-band py-14 lg:py-24", id="faster", [
    div(
      class="reveal grid grid-cols-1 gap-8 lg:grid-cols-12 lg:items-center lg:gap-10",
      [
        div(class="reveal-text lg:col-span-5", [
          h2(
            class="display screen-heading mb-8 text-balance text-section lg:mb-0",
            t("Time per file", "单个文件的耗时"),
          ),
          p(
            class="screen-line mt-8 max-w-lead text-ink-2",
            t(
              "Same Node.js process, \{bench_rows.length()} files, multipass. From a cold start the native CLI takes about 10 ms, the svgo CLI about 160 ms.",
              "同一 Node.js 进程，\{bench_rows.length()} 个文件，启用 multipass。从冷启动开始，原生 CLI 约需 10 ms，svgo CLI 约需 160 ms。",
            ),
          ),
        ]),
        div(class="reveal-graphics lg:col-span-7", [
          div(class="race", [
            race_lane("svgo", 1.0, 1200.0, "\{fmt_ms(median_js)} ms", mbt=false),
            race_lane(
              "svgo.mbt",
              1.0 / ratio,
              1200.0 / ratio,
              "\{fmt_ms(median_mbt)} ms",
              mbt=true,
            ),
          ]),
          p(
            class="race-note",
            t(
              "\{to_fixed(ratio, 1)}× is the median of per-file speedups over \{bench_rows.length()} files.",
              "\{to_fixed(ratio, 1)} 倍是 \{bench_rows.length()} 个文件中逐文件加速比的中位数。",
            ),
          ),
        ]),
      ],
    ),
  ])
}

///|
/// "Pixel-identical output": the three logos, optimized live, each a real render
/// sample (see app/website/samples/SOURCES.md); the trademark note keeps the
/// claim honest about what the samples are for.
fn same_pixels_screen() -> Html {
  let cards = [1, 2, 3].map(idx => {
    let s = samples[idx]
    let o = run_optimize(s.svg)
    // Mistral's logo is a squarish mark; DeepSeek's and Qwen's are wide
    // wordmarks. object-fit:contain alone leaves the mark visually much
    // larger in the same tile, so each kind gets its own share of the
    // tile's width (see .logo-wordmark/.logo-mark in style.css).
    let kind = if idx == 3 { "logo-mark" } else { "logo-wordmark" }
    node("figure", Attrs::build().class("logo-card"), [
      sample_preview(o.data, "logo-panel \{kind}"),
      node("figcaption", Attrs::build(), [
        span(class="logo-name", s.name),
        span(class="logo-metrics", [
          text("\{fmt_int(o.original_size)} → \{fmt_int(o.size)} B "),
          span(class="removed", "−\{fmt_pct(o.saved_percent(), digits=0)}%"),
        ]),
      ]),
    ])
  })
  div(class="wrap screen screen-same py-14 lg:py-24", id="same-pixels", [
    div(
      class="reveal grid grid-cols-1 gap-8 lg:grid-cols-12 lg:items-center lg:gap-10",
      [
        div(class="reveal-text lg:col-span-5", [
          h2(
            class="display screen-heading mb-8 text-balance text-section lg:mb-0",
            t("Pixel-identical output", "像素级一致的输出"),
          ),
          p(
            class="screen-line mt-8 max-w-lead text-ink-2",
            t(
              "Rendered before and after with resvg and compared pixel by pixel: 0 px difference.",
              "使用 resvg 渲染前后效果并逐像素比较：0 px 差异。",
            ),
          ),
          p(
            class="footnote",
            t(
              "Logos are trademarks of their owners, shown as optimization samples.",
              "标志为其各自所有者的商标，仅作为优化示例展示。",
            ),
          ),
        ]),
        // A third grid item, not nested in the text column: on phones
        // (grid-cols-1) it stacks after the tiles in source order, so the
        // call to action reads after the proof; on desktop the explicit
        // placement below puts it back under the text column, with the
        // tiles spanning both rows beside it.
        div(
          class="reveal-graphics lg:col-span-7 lg:col-start-6 lg:row-span-2",
          [div(class="logos-row", cards)],
        ),
        div(class="install-row mt-6 lg:col-span-5 lg:mt-11", [
          a(
            class="cta-secondary inline-flex items-center gap-1.5",
            href="#/playground",
            [
              text(t("Open the playground", "打开在线体验")),
              span(class="arrow", "→"),
            ],
          ),
        ]),
      ],
    ),
  ])
}

///|
fn speed_axis_limit(maximum : Double) -> Double {
  maximum.ceil()
}

///|
fn speed_row(row : BenchRow, axis_limit : Double) -> Html {
  let ratio = row.js_ms / row.mbt_ms
  div(class="speed-row", [
    div(
      class="speed-name",
      attrs=Attrs::build().title(row.file),
      file_label(row.file),
    ),
    div(class="speed-track", [
      div(
        class="speed-bar",
        style=["width: \{to_fixed(ratio / axis_limit * 100.0, 3)}%"],
        [span("\{to_fixed(ratio, 1)}×")],
      ),
    ]),
    span(class="speed-time", fmt_ms(row.js_ms)),
    span(class="speed-time", fmt_ms(row.mbt_ms)),
    small(
      class="speed-times-mobile",
      "\{file_label(row.file)} · svgo \{fmt_ms(row.js_ms)} ms · svgo.mbt \{fmt_ms(row.mbt_ms)} ms",
    ),
  ])
}

///|
/// The collapsed "Benchmarks" detail: the full output-size table and the
/// per-file speed chart that used to be their own landing sections, now
/// reference material a reader opens on purpose.
fn benchmarks_details() -> Html {
  let sorted = bench_rows.copy()
  sorted.sort_by((a, b) => a.original.compare(b.original))
  let rows = sorted.map(r => {
    tr([
      td(attrs=Attrs::build().title(r.file), [
        text(file_label(r.file)),
        small(
          class="mobile-original",
          t(
            "\{fmt_int(r.original)} B original",
            "原始 \{fmt_int(r.original)} B",
          ),
        ),
      ]),
      td(fmt_int(r.original)),
      td(class=if r.mbt <= r.js { "win" } else { "" }, fmt_int(r.mbt)),
      td(class=if r.js < r.mbt { "win" } else { "" }, fmt_int(r.js)),
      td(
        if r.mbt == r.js {
          "0 B"
        } else if r.mbt < r.js {
          "−\{fmt_int(r.js - r.mbt)} B"
        } else {
          "+\{fmt_int(r.mbt - r.js)} B"
        },
      ),
    ])
  })
  let defaults = sorted
    .filter(r => r.js_default != r.js)
    .map(r => {
      t(
        "With svgo's own default, the \{file_label(r.file)} is \{fmt_int(r.js_default)} B.",
        "使用 svgo 自身的默认配置时，\{file_label(r.file)}的输出为 \{fmt_int(r.js_default)} B。",
      )
    })
    .join(" ")
  let differences = sorted
    .filter(r => r.mbt > r.js)
    .map(r => "\{file_label(r.file)} +\{fmt_int(r.mbt - r.js)} B")
    .join(t(", ", "、"))
  let mut maximum = 0.0
  for row in sorted {
    let ratio = row.js_ms / row.mbt_ms
    if ratio > maximum {
      maximum = ratio
    }
  }
  let axis_limit = speed_axis_limit(maximum)
  let ticks : Array[Html] = []
  for i = 0; i.to_double() < axis_limit; i = i + 1 {
    ticks.push(
      span(
        style=["left: \{to_fixed(i.to_double() / axis_limit * 100.0, 3)}%"],
        if i == 0 {
          "0"
        } else {
          "\{i}×"
        },
      ),
    )
  }
  ticks.push(span(style=["left: 100%"], "\{axis_limit.to_int()}×"))
  let speed_rows = sorted.map(row => speed_row(row, axis_limit))
  landing_details(t("Benchmarks", "基准测试"), [
    div(class="speed-summary", [
      node("strong", Attrs::build(), [display_measure("0", "px")]),
      span(
        t(
          "render difference across \{bench_rows.length()} tested samples",
          "\{bench_rows.length()} 个测试样例的渲染差异",
        ),
      ),
    ]),
    p(
      class="method-note",
      t(
        "Rendered with resvg and compared pixel by pixel with pixelmatch.", "使用 resvg 渲染，并通过 pixelmatch 逐像素比较。",
      ),
    ),
    div(class="size-table", [
      h3(t("Output size · B", "输出大小 · B")),
      table(class="sizes", [
        thead([
          tr([
            th(t("Sample", "样例")),
            th(t("Original", "原始")),
            th(t("svgo.mbt", "svgo.mbt")),
            th(t("svgo", "svgo")),
            th(
              attrs=Attrs::build().title("svgo.mbt − svgo"),
              t("Δ vs svgo", "与 svgo 相差"),
            ),
          ]),
        ]),
        tbody(rows),
      ]),
      p(
        class="method-note table-note",
        t(
          "svgo runs with moveGroupAttrsToElems off, the plugin set svgo.mbt runs by default. \{defaults} svgo.mbt is larger on: \{differences}.",
          "svgo 关闭 moveGroupAttrsToElems，与 svgo.mbt 默认运行的插件集一致。\{defaults}以下文件的 svgo.mbt 输出更大：\{differences}。",
        ),
      ),
    ]),
    div(class="speed-summary", [
      node("strong", Attrs::build(), [
        display_measure(to_fixed(median_speedup(), 1), "×"),
      ]),
      span(
        t(
          "median speedup over svgo, \{bench_rows.length()} samples",
          "\{bench_rows.length()} 个样例，相对 svgo 的中位加速比",
        ),
      ),
    ]),
    p(
      class="method-note",
      t(
        "Same Node.js process, warmed up, multipass enabled. packages/compare/collect.mjs · \{generated_on} · Node.js \{node_version} · svgo \{svgo_js_version}.",
        "同一 Node.js 进程，预热后测量，启用 multipass。packages/compare/collect.mjs · \{generated_on} · Node.js \{node_version} · svgo \{svgo_js_version}。",
      ),
    ),
    p(
      class="method-note mb-4",
      t(
        "Speedup · sorted by original file size · timings in ms", "加速比 · 按原始文件大小排序 · 耗时单位 ms",
      ),
    ),
    div(
      class="speed-chart",
      style=["--speed-reference: \{to_fixed(100.0 / axis_limit, 3)}%"],
      [
        div(class="speed-axis", [
          span(t("File", "文件")),
          div(class="speed-ticks", ticks),
          span("svgo"),
          span("svgo.mbt"),
        ]),
        ..speed_rows,
      ],
    ),
    div(class="cli-speed", [
      h3(t("CLI cold start", "CLI 冷启动")),
      p(
        class="mt-3 text-ink-2",
        t(
          "About 10 ms for the native binary and 160 ms for the svgo CLI on a small icon, including process startup.",
          "包含进程启动时间，处理小图标时，原生二进制约需 10 ms，svgo CLI 约需 160 ms。",
        ),
      ),
      div(class="cli-bars", [
        div(class="cli-bar-row", [
          span("svgo.mbt native"),
          div(class="bars", [
            div(class="bar", style=["width: 6.25%"], [span("10 ms")]),
          ]),
        ]),
        div(class="cli-bar-row", [
          span("svgo CLI"),
          div(class="bars", [
            div(class="bar bar-b", style=["width: 100%"], [span("160 ms")]),
          ]),
        ]),
      ]),
      p(
        class="footnote",
        t(
          "scripts/cli-bench.sh · approximate end-to-end times; separate from the warmed-up measurements above.",
          "scripts/cli-bench.sh · 端到端近似耗时，与上方预热后的测量分开比较。",
        ),
      ),
    ]),
  ])
}

///|
/// What `svgo-mbt <file> -o out.svg` prints for one file: the size row in
/// the CLI's units (1000-based, one decimal from 1 KB), then the plugins that
/// changed it, wrapped at 76 columns like an 80-column terminal. The CLI's
/// two-space left margin is dropped: the code block has its own padding.
fn cli_report(file : String, r : Outcome) -> String {
  let size = (bytes : Int) => {
    if bytes < 1000 {
      "\{bytes} B"
    } else {
      "\{to_fixed(bytes.to_double() / 1000.0, 1)} KB"
    }
  }
  let row = "\{file}  \{size(r.original_size)} → \{size(r.size)}  −\{fmt_pct(r.saved_percent(), digits=0)}%"
  let lines = [row]
  let mut line = ""
  for name in r.applied {
    if line != "" && 2 + line.length() + 1 + name.length() > 76 {
      lines.push(line)
      line = ""
    }
    line = if line == "" { name } else { line + " " + name }
  }
  if line != "" {
    lines.push(line)
  }
  lines.join("\n")
}

///|
fn install_screen(state : LandingState, emit : Emit[LandingMsg]) -> Html {
  let tabs = [
    t("JavaScript", "JavaScript"),
    t("CLI", "CLI"),
    t("MoonBit", "MoonBit"),
  ].mapi((idx, label) => {
    button(
      class="border-b-2 border-transparent px-3.5 py-2.5 font-mono text-sm text-ink-2 aria-pressed:border-mark aria-pressed:text-ink sm:px-5",
      attrs=Attrs::build().aria_pressed(
        if state.tab == idx {
          "true"
        } else {
          "false"
        },
      ),
      on_click=emit(SelectTab(idx)),
      label,
    )
  })
  let content = match state.tab {
    1 => {
      let sample = run_optimize(samples[0].svg)
      let report = cli_report(samples[0].file, sample)
      div(class="use", [
        p(
          t(
            "npx runs the Node.js CLI. Native binaries are available on GitHub Releases.",
            "npx 运行 Node.js CLI。原生二进制可从 GitHub Releases 下载。",
          ),
        ),
        a(
          class="mt-3 inline-block underline",
          href=REPO_URL + "/releases",
          t("Download a native binary", "下载原生二进制"),
        ),
        code_card(
          "npx @rivus/svgo in.svg -o out.svg\n\nsvgo-mbt nib.svg -o out.svg\nsvgo-mbt icon.svg -o out.svg -p 2 --pretty\ncat in.svg | svgo-mbt > out.svg\nsvgo-mbt -r ./icons -o ./icons-opt",
          s => [text(s)],
          emit,
        ),
        p(class="mt-6 text-sm", t("Sample report", "示例报告")),
        pre(class="whitespace-pre-wrap break-words", t(report, report)),
        node("details", Attrs::build().class("flags"), [
          node(
            "summary",
            Attrs::build(),
            t("All CLI flags", "全部 CLI 参数"),
          ),
          table(class="sizes cli-flags", [
            thead([
              tr([th(t("Flag", "参数")), th(t("Description", "说明"))]),
            ]),
            tbody(
              cli_flags.map(f => {
                tr([
                  td([code(t(f.flag, f.flag))]),
                  td(flag_description(f.flag, f.description, lang.val)),
                ])
              }),
            ),
          ]),
        ]),
      ])
    }
    2 =>
      div(class="use", [
        copy_pill("moon add PerfectPan/svgo", emit),
        code_card(
          t(
            "let r = @svgo.optimize(svg, config={\n  ..@svgo.Config::default(),\n  precision: 2,\n})\nr.data\nr.saved_percent()\n\n// Optimize path data independently\n@path.optimize_string(\"M 0,0 L 10,10\")",
            "let r = @svgo.optimize(svg, config={\n  ..@svgo.Config::default(),\n  precision: 2,\n})\nr.data\nr.saved_percent()\n\n// 单独优化路径数据\n@path.optimize_string(\"M 0,0 L 10,10\")",
          ),
          highlight_mbt,
          emit,
        ),
      ])
    _ =>
      div(class="use", [
        div(
          class="pm-switch",
          attrs=Attrs::build()
            .data_set("slide", "fill")
            .aria_label(t("Package manager", "包管理器")),
          package_managers.mapi((idx, pm) => {
            button(
              attrs=Attrs::build().aria_pressed(
                if state.pm == idx {
                  "true"
                } else {
                  "false"
                },
              ),
              on_click=emit(SelectPm(idx)),
              pm.0,
            )
          }),
        ),
        copy_pill(package_managers[state.pm].1, emit),
        code_card(
          t(
            "import { optimize } from \"@rivus/svgo\";\n\nconst result = await optimize(svg, {\n  precision: 3,\n});\n\nresult.data;          // optimized SVG\nresult.originalSize;  // input bytes\nresult.size;          // output bytes\nresult.applied;       // applied plugins",
            "import { optimize } from \"@rivus/svgo\";\n\nconst result = await optimize(svg, {\n  precision: 3,\n});\n\nresult.data;          // 优化后的 SVG\nresult.originalSize;  // 输入字节数\nresult.size;          // 输出字节数\nresult.applied;       // 已应用的插件",
          ),
          highlight_js,
          emit,
        ),
      ])
  }
  let wasm_kb = to_fixed(wasm_bytes.to_double() / 1000.0, 0)
  section(
    id="install",
    class="wrap screen screen-install screen-band py-14 lg:py-24",
    [
      div(
        class="reveal grid grid-cols-1 gap-8 lg:grid-cols-12 lg:items-start lg:gap-10",
        [
          div(class="lg:col-span-5", [
            h2(
              class="display screen-heading mb-8 text-balance text-section lg:mb-0",
              t("Install", "安装"),
            ),
            p(
              class="screen-line mt-8 max-w-lead text-ink-2",
              t(
                "One \{wasm_kb} KB wasm file, no dependencies.",
                "一个 \{wasm_kb} KB 的 wasm 文件，无依赖。",
              ),
            ),
            p(
              class="footnote",
              t(
                "Node.js 24+, Bun 1.4+, Deno 2, Chrome 130+, Firefox 134+, Safari 18.4+ (JS String Builtins).",
                "Node.js 24+、Bun 1.4+、Deno 2、Chrome 130+、Firefox 134+、Safari 18.4+（JS String Builtins）。",
              ),
            ),
          ]),
          div(class="lg:col-span-7", [
            div(
              class="install-tabs mb-6 flex gap-2 border-b border-line-2",
              attrs=Attrs::build()
                .data_set("slide", "line")
                .aria_label(t("Installation method", "安装方式")),
              tabs,
            ),
            content,
          ]),
        ],
      ),
    ],
  )
}

///|
fn plugins_details() -> Html {
  let all = @svgo.list_plugins()
  let defaults = all.filter(item => item.2)
  let plugin = fn(number : String, item : (String, String, Bool)) -> Html {
    let (name, desc, _) = item
    let description = plugin_description(name, desc, lang.val)
    div(class=if number == "" { "plugin plugin-opt-in" } else { "plugin" }, [
      span(class="sheet-no", number),
      code(attrs=Attrs::build().title(name), name),
      span(
        class="plugin-description",
        attrs=Attrs::build().title(description),
        description,
      ),
    ])
  }
  let plugins = defaults.mapi((idx, item) => {
    plugin(if idx < 9 { "0\{idx + 1}" } else { "\{idx + 1}" }, item)
  })
  let optional = ["moveGroupAttrsToElems", "removeDimensions", "removeTitle"].map(name => {
      let item = all.filter(item => item.0 == name)[0]
      plugin("", item)
    },
  )
  landing_details(t("\{all.length()} plugins", "\{all.length()} 个插件"), [
    p(
      class="section-intro pipeline-intro",
      t(
        "\{defaults.length()} run by default, in svgo's preset-default order. \{all.length() - defaults.length()} are opt-in: moveGroupAttrsToElems (on by default in svgo), removeDimensions, removeTitle.",
        "默认运行 \{defaults.length()} 个，顺序与 svgo preset-default 一致。\{all.length() - defaults.length()} 个可选：moveGroupAttrsToElems（svgo 默认开启）、removeDimensions、removeTitle。",
      ),
    ),
    div(class="pipeline-group", [
      div(class="pipeline", plugins[:8].to_owned()),
      input(
        attrs=Attrs::build().type_("checkbox"),
        id="pipeline-expanded",
        class="pipeline-toggle",
      ),
      label(
        class="pipeline-disclosure",
        attrs=Attrs::build().for_("pipeline-expanded"),
        [
          span(
            class="pipeline-chevron",
            attrs=Attrs::build().aria_hidden("true"),
            "+",
          ),
          text(
            t(
              "Show all \{all.length()} plugins",
              "显示全部 \{all.length()} 个插件",
            ),
          ),
        ],
      ),
      div(class="pipeline-rest", [
        div(class="pipeline", plugins[8:].to_owned()),
        h3(class="opt-in-heading", t("Opt-in", "可选")),
        div(class="pipeline", optional),
      ]),
    ]),
  ])
}

///|
/// Landing page with local installation selection and copy feedback.
pub fn landing_page(chrome : Chrome) -> Val[Html] {
  let initial : LandingState = { tab: 0, pm: 0, }
  let mascot_output = run_optimize(samples[0].svg)
  let (state, emit) = @rabbita.create_state_with_init(
    init=fn(_) {
      (
        initial,
        @rabbita.effect(fn() noraise {
          start_count(
            "hero-byte-count",
            mascot_output.original_size,
            mascot_output.size,
          )
        }),
      )
    },
    update=(m, msg, _) => {
      match msg {
        SelectTab(tab) => ({ ..m, tab, }, none)
        SelectPm(pm) => ({ ..m, pm, }, none)
        Copy(cmd) =>
          (
            m,
            @rabbita.batch([
              @rabbita.effect(fn() noraise { copy_text(cmd) }),
              toast_success(t("Copied", "已复制")),
            ]),
          )
      }
    },
  )
  state.view2(chrome.prefs, (m, p) => {
    div(class="page pt-14", [
      top_nav(Landing, "", p, chrome.emit),
      node("main", Attrs::build(), [
        hero(emit),
        faster_screen(),
        same_pixels_screen(),
        install_screen(m, emit),
        div(class="wrap details-section", [
          benchmarks_details(),
          plugins_details(),
        ]),
      ]),
      page_footer(route=Landing),
    ])
  })
}
