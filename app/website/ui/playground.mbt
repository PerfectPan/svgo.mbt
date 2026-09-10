///|
priv struct PgModel {
  source : String
  enabled : Array[String]
  precision : Int
  multipass : Bool
  pretty : Bool
  outcome : Outcome
  notice : String
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
  Notice(String)
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
      notice: "",
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
    Edit(s) => (recompute({ ..m, source: s, notice: "", }), none)
    Toggle(name) => {
      let enabled = if m.enabled.contains(name) {
        m.enabled.filter(p => p != name)
      } else {
        // keep preset order so the pipeline stays meaningful
        @svgo.list_plugins()
        .map(it => it.0)
        .filter(p => p == name || m.enabled.contains(p))
      }
      (recompute({ ..m, enabled, }), none)
    }
    SetPrecision(v) => {
      let p = @string.parse_int(v) catch { _ => m.precision }
      let p = if p < 0 { 0 } else if p > 8 { 8 } else { p }
      (recompute({ ..m, precision: p, }), none)
    }
    ToggleMultipass => (recompute({ ..m, multipass: !m.multipass, }), none)
    TogglePretty => (recompute({ ..m, pretty: !m.pretty, }), none)
    Reset =>
      (
        recompute({
          ..m,
          enabled: default_enabled(),
          precision: 3,
          multipass: true,
          pretty: false,
          notice: "",
        }),
        none,
      )
    LoadSample(name) =>
      match samples.iter().find_first(s => s.name == name) {
        Some(s) => (recompute({ ..m, source: s.svg, notice: "", }), none)
        None => (m, none)
      }
    FilePicked =>
      (
        m,
        @rabbita.attempt(
          res => {
            match res {
              Ok(text) => emit(FileLoaded(text))
              Err(_) => none
            }
          },
          async fn() {
            @js.suspend((resolve, _) => read_first_file("pg-file", resolve))
          },
        ),
      )
    FileLoaded(text) =>
      if text.is_empty() {
        (m, none)
      } else {
        (recompute({ ..m, source: text, notice: "", }), none)
      }
    Copy =>
      (
        m,
        with_notice(
          emit,
          t("Output copied", "输出已复制"),
          @rabbita.effect(fn() noraise { copy_text(m.outcome.data) }),
        ),
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
        with_notice(
          emit,
          t("Link copied", "链接已复制"),
          @rabbita.effect(fn() noraise {
            replace_url(url)
            copy_text(url)
          }),
        ),
      )
    }
    Notice(s) => ({ ..m, notice: s, }, none)
  }
}

///|
fn with_notice(
  emit : Emit[PgMsg],
  s : String,
  cmd : @rabbita.Cmd,
) -> @rabbita.Cmd {
  @rabbita.batch([cmd, emit(Notice(s)), @rabbita.delay(emit(Notice("")), 1500)])
}

///|
fn sidebar(m : PgModel, emit : Emit[PgMsg]) -> Html {
  let all = @svgo.list_plugins()
  let plugin_rows = all.map(it => {
    let (name, desc, _) = it
    label(class="pl", [
      input(
        input_type=Checkbox,
        checked=m.enabled.contains(name),
        on_change=emit.map(_ => Toggle(name)),
      ),
      span([code(name), small(desc)]),
    ])
  })
  aside(class="rise card min-h-0 overflow-auto", style=["--d: 80ms"], [
    div(class="side-head", [text(t("Options", "选项"))]),
    label(class="opt", [
      span([
        text(t("precision", "精度")),
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
        text("multipass"),
        small(
          t("repeat until the output is stable", "跑到输出不变为止"),
        ),
      ]),
      input(
        input_type=Checkbox,
        class="switch",
        checked=m.multipass,
        on_change=emit.map(_ => ToggleMultipass),
      ),
    ]),
    label(class="opt", [
      span([
        text(t("pretty print", "格式化输出")),
        small(t("indented output", "带缩进")),
      ]),
      input(
        input_type=Checkbox,
        class="switch",
        checked=m.pretty,
        on_change=emit.map(_ => TogglePretty),
      ),
    ]),
    div(class="side-head mt-6", [
      span(class="flex items-center gap-2", [
        text(t("Plugins", "插件")),
        span(
          class="tag normal-case tracking-normal",
          "\{m.enabled.length()}/\{all.length()}",
        ),
      ]),
      button(
        class="chip -my-1 normal-case tracking-normal",
        on_click=emit(Reset),
        t("reset", "重置"),
      ),
    ]),
    div(class="divide-y divide-line", plugin_rows),
  ])
}

///|
fn toolbar(m : PgModel, emit : Emit[PgMsg]) -> Html {
  let tabs = samples.map(s => {
    button(
      class="chip",
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
  div(
    class="flex flex-wrap items-center gap-2 border-b border-line bg-surface-2 px-4 py-3",
    [
      div(class="flex flex-wrap items-center gap-1", [
        div(
          class="flex flex-wrap gap-1",
          attrs=Attrs::build().role("tablist"),
          tabs,
        ),
        label(class="chip", for_="pg-file", [
          text(t("Open .svg…", "打开 .svg…")),
          input(
            id="pg-file",
            input_type=File,
            accept=".svg,image/svg+xml",
            hidden=true,
            on_change=emit.map(_ => FilePicked),
          ),
        ]),
      ]),
      div(class="ml-auto flex items-center gap-2", [
        span(class="text-[12.5px] font-semibold text-mint", m.notice),
        button(
          class="btn btn-sm",
          on_click=emit(Copy),
          t("Copy output", "复制输出"),
        ),
        button(
          class="btn btn-sm",
          on_click=emit(Download),
          t("Download", "下载"),
        ),
        button(
          class="btn btn-primary btn-sm",
          title=t(
            "Copy a link with the current input and options", "把当前的输入和选项一起复制成链接",
          ),
          on_click=emit(Share),
          t("Share link", "分享链接"),
        ),
      ]),
    ],
  )
}

///|
fn applied_row(o : Outcome) -> Html {
  div(
    class="flex flex-wrap items-center gap-1.5 border-t border-line bg-surface px-4 py-3 text-[12.5px]",
    [
      span(
        class="mr-1.5 text-[11px] font-bold uppercase tracking-[0.1em] text-muted",
        t("changed by", "生效插件"),
      ),
      if o.applied.is_empty() {
        span(class="text-muted", t("nothing yet", "暂无"))
      } else {
        span(
          class="flex flex-wrap gap-1.5",
          o.applied.map(n => span(class="tag", n)),
        )
      },
    ],
  )
}

///|
fn pg_view(m : PgModel, p : Prefs, chrome : Chrome, emit : Emit[PgMsg]) -> Html {
  let passes = t(
    "\{m.outcome.passes} pass\{if m.outcome.passes == 1 { "" } else { "es" }}",
    "\{m.outcome.passes} 轮",
  )
  div(class="pt-[60px]", [
    top_nav(Playground, t("playground", "在线体验"), p, chrome.emit),
    div(
      class="wrap grid grid-rows-[auto_minmax(0,1fr)] gap-4 pb-4 pt-6 min-[961px]:h-[calc(100dvh-60px)]",
      [
        div(class="px-1", [
          h1(
            class="display rise text-[clamp(28px,3.2vw,38px)] leading-[1.08]",
            style=["--d: 60ms"],
            t("Playground", "在线体验"),
          ),
          @html.p(
            class="rise mt-3 max-w-[62ch] text-[14px] leading-relaxed text-ink-2",
            style=["--d: 120ms"],
            t(
              "Paste an SVG, open a file, or pick a sample — the output updates as you type. Nothing leaves this tab: the optimizer is MoonBit compiled to JavaScript. Share links put the input and options in the URL.",
              "粘一段 SVG、打开一个文件，或者选个示例，输入一变输出就跟着变。所有东西都不出这个标签页：优化器是用 MoonBit 写、编译成 JavaScript 的。分享链接会把输入和选项都放进 URL 里。",
            ),
          ),
        ]),
        div(
          class="grid min-h-0 gap-4 min-[961px]:grid-cols-[280px_minmax(0,1fr)]",
          [
            sidebar(m, emit),
            main_(
              class="rise grid min-h-0 grid-rows-[auto_minmax(0,1fr)_auto_auto] overflow-hidden rounded-card border border-line bg-surface shadow-card",
              style=["--d: 160ms"],
              [
                toolbar(m, emit),
                div(class="grid min-h-0 grid-cols-2 max-[800px]:grid-cols-1", [
                  div(class="pane", [
                    span(class="pane-label", t("input", "输入")),
                    code_editor(
                      m.source,
                      emit.map(s => Edit(s)),
                      placeholder=t(
                        "Paste an SVG or pick a sample", "粘贴 SVG 或选择示例",
                      ),
                      label=t("SVG input", "SVG 输入"),
                    ),
                    svg_preview(m.source),
                  ]),
                  div(
                    class="pane border-l border-line max-[800px]:border-l-0 max-[800px]:border-t",
                    [
                      span(
                        class="pane-label",
                        t("svgo.mbt output", "svgo.mbt 输出"),
                      ),
                      code_view(
                        if m.outcome.error != "" {
                          m.outcome.error
                        } else {
                          m.outcome.data
                        },
                        label=t("optimized SVG", "优化后的 SVG"),
                      ),
                      svg_preview(m.outcome.data),
                    ],
                  ),
                ]),
                stats_bar(m.outcome, passes),
                applied_row(m.outcome),
              ],
            ),
          ],
        ),
      ],
    ),
  ])
}

///|
/// The playground page. Its state outlives language and theme changes.
pub fn playground_page(chrome : Chrome) -> Val[Html] {
  let initial = match from_url() {
    Some(m) => m
    None => {
      let first = match
        samples.iter().find_first(s => s.file == "sketch-icon.svg") {
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
        notice: "",
      })
    }
  }
  let (model, emit) = @rabbita.create_state(initial, update=pg_update)
  model.view2(chrome.prefs, (m, p) => pg_view(m, p, chrome, emit))
}
