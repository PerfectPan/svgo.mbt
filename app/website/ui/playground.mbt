///|
priv struct PgModel {
  source : String
  enabled : Array[String]
  precision : Int
  multipass : Bool
  pretty : Bool
  outcome : Outcome
  preview_bg : PreviewBg
} derive(Eq)

///|
/// The preview checkerboard, set by the "Preview background" segmented
/// control on the preview label bar. Defaults to `Light` regardless of the
/// site theme, so a dark sample stays visible on first load. Not persisted,
/// and not part of the share link — it's a local inspection aid, not an
/// input.
priv enum PreviewBg {
  Light
  Dark
} derive(Eq)

///|
priv enum PgMsg {
  Edit(String)
  Toggle(String)
  SetPrecision(String)
  ToggleMultipass
  TogglePretty
  Reset
  LoadSample(String)
  FilePicked
  FileLoaded(String)
  Copy
  Download
  Share
  SetPreviewBg(PreviewBg)
}

///|
fn default_enabled() -> Array[String] {
  @svgo.Config::default().plugins
}

///|
fn recompute(m : PgModel) -> PgModel {
  let outcome = if m.source.trim().is_empty() {
    Outcome::empty()
  } else {
    run_optimize(
      m.source,
      plugins=m.enabled,
      precision=m.precision,
      multipass=m.multipass,
      pretty=m.pretty,
    )
  }
  { ..m, outcome, }
}

///|
/// Share links live entirely in the hash, like the TypeScript playground:
/// `#/playground?p=3&m=1&f=0&x=name,name&s=<lz-string>`. Options are only
/// written when they differ from the defaults; the source is lz-compressed
/// (see lz.mbt), roughly half the length base64 of the text would be.
fn share_url(m : PgModel) -> String {
  let href = location_href()
  let base = match href.find("#") {
    Some(i) => href[:i].to_owned()
    None => href
  }
  let q : Array[String] = []
  if m.precision != 3 {
    q.push("p=\{m.precision}")
  }
  if !m.multipass {
    q.push("m=0")
  }
  if m.pretty {
    q.push("f=1")
  }
  if m.enabled != default_enabled() {
    q.push("x=\{m.enabled.join(",")}")
  }
  q.push("s=\{lz_compress(m.source)}")
  base + "#/playground?" + q.join("&")
}

///|
/// Restore a model from the current URL, if it carries a share payload.
fn from_url() -> PgModel? {
  let href = location_href()
  guard href.find("#/playground?") is Some(h) else { return None }
  let query = href[h + "#/playground?".length():].to_owned()
  let mut precision = 3
  let mut multipass = true
  let mut pretty = false
  let mut enabled = default_enabled()
  let mut source = ""
  for part in query.split("&") {
    match part.split_once("=") {
      Some((key, value)) =>
        match key.to_owned() {
          "p" =>
            precision = @string.parse_int(value.to_owned()) catch { _ => 3 }
          "m" => multipass = value != "0"
          "f" => pretty = value == "1"
          "x" =>
            enabled = value
              .split(",")
              .filter(s => !s.is_empty())
              .map(s => s.to_owned())
              .to_array()
          "s" => source = lz_decompress(value.to_owned()).unwrap_or("")
          _ => ()
        }
      None => ()
    }
  }
  guard !source.is_empty() else { return None }
  Some(
    recompute({
      source,
      enabled,
      precision,
      multipass,
      pretty,
      outcome: Outcome::empty(),
      preview_bg: Light,
    }),
  )
}

///|
fn pg_update(
  m : PgModel,
  msg : PgMsg,
  emit : Emit[PgMsg],
) -> (PgModel, @rabbita.Cmd) {
  match msg {
    Edit(s) => (recompute({ ..m, source: s, }), none)
    Toggle(name) => {
      let enabled = if m.enabled.contains(name) {
        m.enabled.filter(p => p != name)
      } else {
        // keep preset order so the pipeline stays meaningful
        @svgo.list_plugins()
        .map(it => it.0)
        .filter(p => p == name || m.enabled.contains(p))
      }
      let next = recompute({ ..m, enabled, })
      (next, tween_stats(m.outcome, next.outcome))
    }
    SetPrecision(v) => {
      let p = @string.parse_int(v) catch { _ => m.precision }
      let p = if p < 0 { 0 } else if p > 8 { 8 } else { p }
      let next = recompute({ ..m, precision: p, })
      (next, tween_stats(m.outcome, next.outcome))
    }
    ToggleMultipass => {
      let next = recompute({ ..m, multipass: !m.multipass, })
      (next, tween_stats(m.outcome, next.outcome))
    }
    TogglePretty => {
      let next = recompute({ ..m, pretty: !m.pretty, })
      (next, tween_stats(m.outcome, next.outcome))
    }
    Reset => {
      let next = recompute({
        ..m,
        enabled: default_enabled(),
        precision: 3,
        multipass: true,
        pretty: false,
      })
      (next, tween_stats(m.outcome, next.outcome))
    }
    LoadSample(name) =>
      match samples.iter().find_first(s => s.name == name) {
        Some(s) => (recompute({ ..m, source: s.svg, }), none)
        None => (m, none)
      }
    FilePicked =>
      (
        m,
        @cmd.custom_cmd(scheduler => {
          read_first_file("pg-file", text => {
            scheduler.add(emit(FileLoaded(text)))
          })
        }),
      )
    FileLoaded(text) =>
      if text.is_empty() {
        (m, none)
      } else {
        (recompute({ ..m, source: text, }), none)
      }
    Copy =>
      (
        m,
        @rabbita.batch([
          @rabbita.effect(fn() noraise { copy_text(m.outcome.data) }),
          toast_success(t("Copied", "已复制")),
        ]),
      )
    Download =>
      (
        m,
        @rabbita.effect(fn() noraise {
          download_text("optimized.svg", m.outcome.data)
        }),
      )
    Share => {
      let url = share_url(m)
      (
        m,
        @rabbita.batch([
          @rabbita.effect(fn() noraise {
            replace_url(url)
            copy_text(url)
          }),
          toast_success(t("Link copied", "链接已复制")),
        ]),
      )
    }
    SetPreviewBg(bg) => ({ ..m, preview_bg: bg, }, none)
  }
}

///|
/// Tweens the stats bar's "B in"/"B out" figures from their old values to
/// the recomputed ones (see `tween_int`, browser.mbt) — only for an actual
/// option change (Toggle, SetPrecision, ToggleMultipass, TogglePretty,
/// Reset). Typing (Edit) and loading a new sample or file snap instead: they
/// replace the input, not how it's optimized, and tweening every keystroke
/// would fight the editor's own responsiveness.
fn tween_stats(old : Outcome, next : Outcome) -> @rabbita.Cmd {
  @rabbita.effect(fn() noraise {
    tween_int("pg-stat-in", old.original_size, next.original_size)
    tween_int("pg-stat-out", old.size, next.size)
  })
}

///|
/// Zero-padded execution order, matching the landing page's pipeline sheet.
fn pipeline_number(idx : Int) -> String {
  if idx < 9 {
    "0\{idx + 1}"
  } else {
    "\{idx + 1}"
  }
}

///|
/// Options + the numbered plugin pipeline. Collapses below the editors on
/// narrow screens behind a checkbox-driven disclosure (no JS): the label
/// acts as the summary and is hidden, the body forced visible again above
/// 961 px (see style.css).
/// One plugin's checkbox row; `number` is empty for the opt-in group, which
/// isn't part of the numbered preset-default order (see `options_and_plugins`).
fn plugin_row(
  number : String,
  it : (String, String, Bool),
  m : PgModel,
  emit : Emit[PgMsg],
) -> Html {
  let (name, desc, _) = it
  let applied = m.outcome.applied
  label(class="pl", [
    span(class="pl-no", if number == "" { "—" } else { number }),
    input(
      input_type=Checkbox,
      checked=m.enabled.contains(name),
      on_change=emit.map(_ => Toggle(name)),
    ),
    span(class="min-w-0 flex-1", [
      code(camel_breaks(name)),
      small(plugin_description(name, desc, lang.val)),
    ]),
    // a fixed-width column, not inline after the name: a dot that shifts
    // the name around depending on whether it's there reads as punctuation,
    // not a status marker (see the "●" legend in options_and_plugins)
    span(
      class="pl-dot-col",
      if applied.contains(name) {
        span(
          class="applied",
          title=t("changed the output", "本次修改了输出"),
          nothing,
        )
      } else {
        nothing
      },
    ),
  ])
}

///|
/// `name` with a `<wbr>` before each capital: the longest plugin names
/// (removeNonInheritableGroupAttrs) are wider than the side column, and
/// breaking at a word boundary reads better than at an arbitrary letter.
fn camel_breaks(name : String) -> Array[Html] {
  let parts : Array[Html] = []
  let mut start = 0
  for i, c in name {
    if i > 0 && c >= 'A' && c <= 'Z' {
      parts.push(text(name[start:i].to_owned()))
      parts.push(@html.wbr())
      start = i
    }
  }
  parts.push(text(name[start:].to_owned()))
  parts
}

///|
/// Plugin names not in svgo's preset-default order (see the landing page's
/// pipeline sheet, which uses this same split): the model everywhere on the
/// site is 36 = 33 default + 3 opt-in.
let opt_in_names : Array[String] = [
  "moveGroupAttrsToElems", "removeDimensions", "removeTitle",
]

///|
fn options_and_plugins(m : PgModel, emit : Emit[PgMsg]) -> Html {
  let all = @svgo.list_plugins()
  let defaults = all.filter(it => it.2)
  let optional = opt_in_names.map(name => all.filter(it => it.0 == name)[0])
  let applied = m.outcome.applied
  let plugin_rows = [
    ..defaults.mapi((idx, it) => plugin_row(pipeline_number(idx), it, m, emit)),
    h4(class="pl-group", t("Opt-in", "可选")),
    ..optional.map(it => plugin_row("", it, m, emit)),
  ]
  div(class="pg-side", [
    input(input_type=Checkbox, id="pg-toggle", class="pg-toggle", hidden=true),
    label(
      for_="pg-toggle",
      class="pg-side-summary lg:hidden",
      t(
        "Options and plugins · \{m.enabled.length()}/\{all.length()}",
        "选项与插件 · \{m.enabled.length()}/\{all.length()}",
      ),
    ),
    div(class="pg-side-body", [
      div(class="side-head", [text(t("Options", "选项"))]),
      label(class="opt", [
        span([
          text(t("precision", "小数位数")),
          small(t("decimal places kept", "保留的小数位数")),
        ]),
        input(
          input_type=Number,
          class="num",
          value=m.precision.to_string(),
          min=0,
          max=8,
          on_input=emit.map(v => SetPrecision(v)),
        ),
      ]),
      label(class="opt", [
        span([
          text(t("multipass", "多轮优化")),
          small(
            t(
              "repeat until the output is stable", "重复运行直至输出不再变化",
            ),
          ),
        ]),
        input(
          input_type=Checkbox,
          class="opt-check",
          checked=m.multipass,
          on_change=emit.map(_ => ToggleMultipass),
        ),
      ]),
      label(class="opt", [
        span([
          text(t("pretty print", "缩进输出")),
          small(t("indented output", "带缩进")),
        ]),
        input(
          input_type=Checkbox,
          class="opt-check",
          checked=m.pretty,
          on_change=emit.map(_ => TogglePretty),
        ),
      ]),
      div(class="mt-6", [
        div(
          class="flex items-start justify-between gap-2 text-code font-semibold text-ink",
          [
            span(
              class="min-w-0",
              t(
                "\{m.enabled.length()}/\{all.length()} on · \{applied.length()} changed",
                "已启用 \{m.enabled.length()}/\{all.length()} · \{applied.length()} 个有改动",
              ),
            ),
            button(
              class="text-action flex-none text-code font-normal",
              on_click=emit(Reset),
              t("reset", "重置"),
            ),
          ],
        ),
        if applied.is_empty() {
          nothing
        } else {
          // the legend for the trailing dot column in the plugin list below:
          // an actual `.applied` dot, the same size as the ones in the rows
          // — a "●" glyph here would render at font-size (13px), visibly
          // bigger than the 6px row dot it's meant to explain
          p(class="mt-1 flex items-center gap-1.5 text-code text-ink-2", [
            span(class="applied", nothing),
            text(t("Changed this SVG", "已修改此 SVG")),
          ])
        },
      ]),
      div(class="pl-list-wrap", [div(class="pl-list", plugin_rows)]),
    ]),
  ])
}

///|
/// Thin toolbar row directly under the nav: sample chips, the file picker
/// and the share action. No marketing header here; the workbench below it
/// fills the rest of the viewport.
fn toolbar(m : PgModel, emit : Emit[PgMsg]) -> Html {
  let tabs = samples.map(s => {
    button(
      class="chip flex-none",
      attrs=Attrs::build().aria_selected(
        if m.source == s.svg {
          "true"
        } else {
          "false"
        },
      ),
      on_click=emit(LoadSample(s.name)),
      s.name,
    )
  })
  div(class="border-b border-line bg-surface-2", [
    div(
      // one wrapping row at every width: below 961px "Share link" is a
      // plain text action at the end of this same row (never its own
      // indented row); from 961px it becomes the outlined button on the
      // far right, as before.
      class="wrap flex flex-wrap items-center gap-2 py-2 lg:flex-nowrap lg:py-2.5",
      [
        // desktop: a chip per sample. Below 961px a chip row this wide
        // either wraps or clips, so it becomes a single full-width select.
        div(
          class="hidden min-w-0 items-center gap-1 overflow-x-auto lg:flex",
          attrs=Attrs::build().role("tablist"),
          tabs,
        ),
        label(class="pg-sample min-w-0 flex-1 lg:hidden", [
          span(class="label flex-none", t("Sample", "示例")),
          select(
            class="pg-sample-select",
            on_change=emit.map(v => LoadSample(v)),
            samples.map(s => {
              option(value=s.name, selected=m.source == s.svg, s.name)
            }),
          ),
        ]),
        // a 1px hairline + 16px gap on each side sets "Open file" apart from
        // the sample tabs, as its own action rather than another tab
        span(
          class="hidden h-5 w-px flex-none bg-line lg:mx-2 lg:block",
          nothing,
        ),
        // outlined, the same style as "Share link" on both sides of 961px —
        // two labels share the one hidden input below so it reaches
        // whichever one is visible at the current width.
        label(
          class="btn btn-sm hidden flex-none lg:inline-flex",
          for_="pg-file",
          [
            text(t("Open file", "打开文件")),
            input(
              id="pg-file",
              input_type=File,
              accept=".svg,image/svg+xml",
              hidden=true,
              on_change=emit.map(_ => FilePicked),
            ),
          ],
        ),
        // mobile: short enough to reuse the desktop copy as-is; the pill
        // buttons plus the sample <select> share one 390px row (see the
        // hidden input above, reused here via the same `for_`)
        label(
          class="btn btn-sm flex-none lg:hidden",
          for_="pg-file",
          t("Open file", "打开文件"),
        ),
        // mobile: Share, the same outlined small-button style as Open file
        button(
          class="btn btn-sm flex-none lg:hidden",
          title=t(
            "Copy a link with the current input and options", "复制包含当前输入和选项的链接",
          ),
          on_click=emit(Share),
          t("Share", "分享"),
        ),
        // desktop: the Share button, pushed to the right
        div(class="hidden items-center gap-2 lg:ml-auto lg:flex", [
          button(
            class="btn btn-sm flex-none",
            title=t(
              "Copy a link with the current input and options", "复制包含当前输入和选项的链接",
            ),
            on_click=emit(Share),
            t("Share link", "分享链接"),
          ),
        ]),
      ],
    ),
  ])
}

///|
/// A code pane capped at ~200px below 961px, with a checkbox-driven
/// `▸ expand` / `▾ collapse` control (no JS); always full height from
/// 961px, where the control is hidden (see style.css). `view_class` places
/// it in the desktop grid and tags it for the input/output code toggle.
fn collapsible_code(id : String, view_class : String, body : Html) -> Html {
  div(class="code-collapse \{view_class}", [
    input(input_type=Checkbox, id~, class="code-expand-toggle", hidden=true),
    div(class="code-collapse-body", [body]),
    label(for_=id, class="code-expand-label lg:hidden", nothing),
  ])
}

///|
/// The output code pane's body: the optimized source normally, or — on a
/// parse error — the puzzled Nib above the message instead of the code
/// view (there is no optimized SVG to show).
fn output_code_body(m : PgModel) -> Html {
  if m.outcome.error == "" {
    code_view(m.outcome.data, label=t("optimized SVG", "优化后的 SVG"))
  } else {
    div(class="pg-error", [
      illustration("nib-puzzled", class="size-18"),
      p(class="max-w-narrow font-mono text-code text-ink-2", m.outcome.error),
    ])
  }
}

///|
/// "Input · 68,630 B" / "Optimized · 52,690 B": the byte-labelled pane
/// header, desktop only (mobile has its own, unlabelled Before/After
/// toggle directly over the preview — see `workbench`).
fn io_label(title_en : String, title_zh : String, bytes : Int) -> Html {
  // running text, not a display numeral: a real space before the unit (the
  // tight display-unit gap is for the hero-sized stats strip figures only)
  span([
    text(t("\{title_en} · ", "\{title_zh} · ")),
    span(class="font-mono tabular-nums", fmt_int(bytes)),
    text(" B"),
  ])
}

///|
/// The `Light`/`Dark` segmented control for the preview checkerboard. No
/// "Background" label — on mobile it sits next to Copy/Download, on
/// desktop inside the small overlay at the preview's corner, and in both
/// places the two options (which read "Light"/"Dark" or "浅"/"深") already
/// say what they do.
fn preview_bg_toggle(dark : Bool, emit : Emit[PgMsg]) -> Html {
  div(
    class="segs inline-flex h-8 flex-none overflow-hidden rounded-full border border-line bg-paper",
    attrs=Attrs::build()
      .role("group")
      .aria_label(t("Preview background", "预览背景")),
    [
      button(
        class="seg flex h-full items-center px-3 text-xs font-medium text-ink-2 transition-colors aria-pressed:bg-ink aria-pressed:text-paper",
        attrs=Attrs::build().aria_pressed(if dark { "false" } else { "true" }),
        title=t("Light preview background", "浅色预览背景"),
        on_click=emit(SetPreviewBg(Light)),
        t("Light", "浅色"),
      ),
      button(
        class="seg flex h-full items-center px-3 text-xs font-medium text-ink-2 transition-colors aria-pressed:bg-ink aria-pressed:text-paper",
        attrs=Attrs::build().aria_pressed(if dark { "true" } else { "false" }),
        title=t("Dark preview background", "深色预览背景"),
        on_click=emit(SetPreviewBg(Dark)),
        t("Dark", "深色"),
      ),
    ],
  )
}

///|
/// Input and output side by side from 961px: one row of pane labels, one
/// row of previews, one row of code — three CSS grid rows, two columns,
/// with the code row stretched to fill the rest of the fixed-height
/// workbench. Below 961px the grid collapses to one column and two
/// independent, checkbox-driven toggles take over: `Before`/`After` picks
/// which preview shows (byte counts inline, same frame and scale for
/// both), `Input SVG`/`Optimized SVG` picks which code pane shows — kept
/// apart because comparing the image and reading the code are different
/// tasks. The stats line leads on mobile (`order` on `.stats`, see
/// style.css) and closes the workbench as a status bar from 961px.
fn workbench(m : PgModel, emit : Emit[PgMsg], passes : String) -> Html {
  let preview_dark = m.preview_bg == Dark
  div(
    id="pg-workbench",
    class="pg-body relative flex min-h-0 flex-col overflow-clip rounded-2xl border border-line bg-surface lg:h-full \{if preview_dark { "pg-preview-dark" } else { "" }}",
    [
      // shown by install_dropzone (browser.mbt) toggling `hidden` while a
      // file is dragged over #pg-workbench; reading the dropped file and
      // hiding it again on drop happen there too, so this is pure markup
      div(
        id="pg-dropzone-overlay",
        class="pg-dropzone-overlay drop absolute inset-0 z-20 bg-paper/90",
        hidden=true,
        [
          illustration("nib-arms-up", class="size-24"),
          p(
            class="font-mono text-code text-ink-2",
            t("Drop an .svg", "拖入 .svg 文件"),
          ),
        ],
      ),
      stats_bar(m.outcome, passes),
      div(
        class="grid min-h-0 flex-1 grid-cols-1 lg:grid-cols-2 lg:grid-rows-[auto_auto_minmax(0,1fr)]",
        [
          span(
            class="pane-label whitespace-nowrap lg:col-start-1 lg:row-start-1 max-lg:hidden",
            [io_label("Input", "输入", m.outcome.original_size)],
          ),
          div(
            class="pane-label whitespace-nowrap max-lg:hidden lg:col-start-2 lg:row-start-1 lg:border-l lg:border-line",
            [
              io_label("Optimized", "优化后", m.outcome.size),
              // copy and download act on the code pane; the background
              // toggle overlays the preview instead (see below) so this bar
              // holds only the label and the two actions, same height as
              // the input header. The toolbar keeps the file input and the
              // share link. Mobile has its own copies of Copy/Download,
              // placed by what they act on (see below), so this cluster is
              // desktop only.
              div(class="ml-auto hidden items-center gap-2.5 lg:flex", [
                button(
                  class="pane-act",
                  on_click=emit(Copy),
                  t("Copy", "复制"),
                ),
                button(
                  class="pane-act",
                  on_click=emit(Download),
                  t("Download", "下载"),
                ),
              ]),
            ],
          ),
          // mobile only: one selector for both the image and the code below
          // it — a full-width row of its own, the background toggle moved
          // to the code label row instead (it isn't tied to Before/After)
          div(class="pg-view-tabs lg:hidden", [
            input(
              input_type=Radio,
              id="pg-view-before",
              name="pg-view",
              hidden=true,
              checked=false,
            ),
            label(for_="pg-view-before", class="pg-view-tab", [
              io_label("Before", "优化前", m.outcome.original_size),
            ]),
            input(
              input_type=Radio,
              id="pg-view-after",
              name="pg-view",
              hidden=true,
              checked=true,
            ),
            label(for_="pg-view-after", class="pg-view-tab", [
              io_label("After", "优化后", m.outcome.size),
            ]),
          ]),
          div(class="preview-input relative lg:col-start-1 lg:row-start-2", [
            svg_preview(m.source, class="preview"),
            // mobile only: this is the single preview visible when
            // "Before" is picked, so the toggle overlays its own corner,
            // same spot as the desktop shared row below
            div(class="pg-bg-overlay flex lg:hidden", [
              preview_bg_toggle(preview_dark, emit),
            ]),
          ]),
          div(
            class="preview-output relative lg:col-start-2 lg:row-start-2 lg:border-l lg:border-line",
            [
              svg_preview(m.outcome.data),
              div(class="pg-bg-overlay flex lg:hidden", [
                preview_bg_toggle(preview_dark, emit),
              ]),
            ],
          ),
          // desktop only: the background toggle overlaid on the top-right
          // corner of the preview PAIR, spanning both grid columns — it
          // controls both panes at once, so it no longer lives nested
          // inside just the output preview (see .pg-preview-bg-row)
          div(class="pg-preview-bg-row", [
            div(class="pg-bg-overlay", [preview_bg_toggle(preview_dark, emit)]),
          ]),
          // mobile only: a quiet label over the code pane, matching whichever
          // side the selector above picked; Copy/Download sit here too,
          // beside the optimized source they act on (the background toggle
          // moved onto the preview itself — see above)
          div(class="pane-label pg-src-label-input lg:hidden", [
            span(t("Original SVG source", "原始 SVG 源码")),
          ]),
          div(class="pane-label pg-src-label-output lg:hidden", [
            span(
              class="flex-none whitespace-nowrap",
              t("Optimized SVG source", "优化后 SVG 源码"),
            ),
            div(class="ml-auto flex items-center gap-1", [
              button(class="pane-act", on_click=emit(Copy), t("Copy", "复制")),
              button(
                class="pane-act",
                on_click=emit(Download),
                t("Download", "下载"),
              ),
            ]),
          ]),
          collapsible_code(
            "code-expand-input",
            "code-input lg:col-start-1 lg:row-start-3",
            code_editor(
              m.source,
              emit.map(s => Edit(s)),
              placeholder=t(
                "Paste an SVG or pick a sample", "粘贴 SVG 或选择示例",
              ),
              label=t("SVG input", "SVG 输入"),
            ),
          ),
          collapsible_code(
            "code-expand-output",
            "code-output lg:col-start-2 lg:row-start-3 lg:border-l lg:border-line",
            output_code_body(m),
          ),
        ],
      ),
    ],
  )
}

///|
fn pg_view(m : PgModel, p : Prefs, chrome : Chrome, emit : Emit[PgMsg]) -> Html {
  let passes = t(
    "\{m.outcome.passes} pass\{if m.outcome.passes == 1 { "" } else { "es" }}",
    "\{m.outcome.passes} 轮",
  )
  // Tool first: no page title block. The workbench fills the viewport below
  // the nav and the thin toolbar row. Below 961px the options/plugins
  // disclosure comes first (collapsed), then the workbench (sticky stats,
  // preview, capped code); from 961px the same source order already puts
  // the disclosure in the left column, so no `order` override is needed here.
  div(class="pt-14", [
    top_nav(Playground, t("playground", "在线体验"), p, chrome.emit),
    toolbar(m, emit),
    div(
      class="wrap flex flex-col gap-4 py-4 lg:grid lg:h-[calc(100vh-var(--nav-h))] lg:min-h-160 lg:grid-cols-[var(--pg-sidebar-w)_minmax(0,1fr)]",
      [options_and_plugins(m, emit), workbench(m, emit, passes)],
    ),
    page_footer(route=Playground),
  ])
}

///|
/// The playground page. Its state outlives language and theme changes.
pub fn playground_page(chrome : Chrome) -> Val[Html] {
  let initial = match from_url() {
    Some(m) => m
    None => {
      let first = match samples.iter().find_first(s => s.name == "Nib") {
        Some(s) => s
        None => samples[0]
      }
      recompute({
        source: first.svg,
        enabled: default_enabled(),
        precision: 3,
        multipass: true,
        pretty: false,
        outcome: Outcome::empty(),
        preview_bg: Light,
      })
    }
  }
  let (model, emit) = @rabbita.create_state(initial, update=pg_update, subscriptions=(
    _,
    emit,
  ) => {
    dropzone_sub(
      "pg-workbench",
      "pg-dropzone-overlay",
      emit.map(text => FileLoaded(text)),
    )
  })
  model.view2(chrome.prefs, (m, p) => pg_view(m, p, chrome, emit))
}
