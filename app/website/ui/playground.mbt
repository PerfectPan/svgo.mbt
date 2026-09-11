///|
priv struct PgModel {
  source : String
  enabled : Array[String]
  precision : Int
  multipass : Bool
  pretty : Bool
  outcome : Outcome
  notice : String
  notice_at : NoticeAt
} derive(Eq)

///|
/// Where the 1.5 s notice shows: next to the action that produced it.
priv enum NoticeAt {
  Toolbar
  Output
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
  Notice(String, NoticeAt)
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
      notice_at: Toolbar,
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
          t("Copied", "已复制"),
          Output,
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
          Toolbar,
          @rabbita.effect(fn() noraise {
            replace_url(url)
            copy_text(url)
          }),
        ),
      )
    }
    Notice(s, at) => ({ ..m, notice: s, notice_at: at, }, none)
  }
}

///|
fn with_notice(
  emit : Emit[PgMsg],
  s : String,
  at : NoticeAt,
  cmd : @rabbita.Cmd,
) -> @rabbita.Cmd {
  @rabbita.batch([
    cmd,
    emit(Notice(s, at)),
    @rabbita.delay(emit(Notice("", at)), 1500),
  ])
}

///|
fn sidebar(m : PgModel, emit : Emit[PgMsg]) -> Html {
  let all = @svgo.list_plugins()
  let applied = m.outcome.applied
  let plugin_rows = all.map(it => {
    let (name, desc, _) = it
    label(class="pl", [
      input(
        input_type=Checkbox,
        checked=m.enabled.contains(name),
        on_change=emit.map(_ => Toggle(name)),
      ),
      span([
        code(name),
        if applied.contains(name) {
          span(
            class="applied",
            title=t("changed the output", "本次修改了输出"),
            nothing,
          )
        } else {
          nothing
        },
        small(plugin_description(name, desc, lang.val)),
      ]),
    ])
  })
  aside(
    class="rise card flex min-h-0 flex-col overflow-hidden p-5",
    style=["--d: 80ms"],
    [
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
            t(
              "repeat until the output is stable", "重复运行直至输出不再变化",
            ),
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
          span(class="tag", "\{m.enabled.length()}/\{all.length()}"),
          if applied.is_empty() {
            nothing
          } else {
            span(
              class="flex items-center gap-1.5 text-[12px] font-normal text-muted",
              [
                span(class="applied ml-0", nothing),
                text(
                  t(
                    "\{applied.length()} changed the output",
                    "\{applied.length()} 个生效",
                  ),
                ),
              ],
            )
          },
        ]),
        button(class="chip -my-1", on_click=emit(Reset), t("reset", "重置")),
      ]),
      div(
        class="divide-y divide-line flex-1 min-h-0 overflow-auto",
        plugin_rows,
      ),
    ],
  )
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
        span(
          class="text-[12.5px] font-semibold text-mint",
          if m.notice_at == Toolbar {
            m.notice
          } else {
            ""
          },
        ),
        button(
          class="btn btn-primary btn-sm",
          title=t(
            "Copy a link with the current input and options", "复制包含当前输入和选项的链接",
          ),
          on_click=emit(Share),
          t("Share link", "分享链接"),
        ),
      ]),
    ],
  )
}

///|
fn pg_view(m : PgModel, p : Prefs, chrome : Chrome, emit : Emit[PgMsg]) -> Html {
  let passes = t(
    "\{m.outcome.passes} pass\{if m.outcome.passes == 1 { "" } else { "es" }}",
    "\{m.outcome.passes} 轮",
  )
  // The title block scrolls away; the workbench below it is exactly one
  // viewport tall (minus the fixed nav), so one scroll of the header's height
  // leaves the editors filling the screen. Below 961px everything flows.
  div(class="pt-[60px]", [
    top_nav(Playground, t("playground", "在线体验"), p, chrome.emit),
    page_head(
      "svgo.mbt",
      [text(t("Playground", "在线体验"))],
      t(
        "Paste an SVG, open a file or pick a sample; the output updates as you type. Everything runs locally in the browser and nothing is uploaded. Share links carry the input and options in the URL.",
        "粘贴一段 SVG、打开文件或选一个示例，输出随输入实时更新。全部在浏览器本地完成，不上传任何内容。分享链接将输入和选项编码在 URL 中。",
      ),
    ),
    div(
      class="wrap grid gap-4 pt-2 min-[961px]:h-[calc(100vh-60px)] min-[961px]:min-h-[640px] min-[961px]:grid-cols-[280px_minmax(0,1fr)] min-[961px]:pb-4",
      [
        sidebar(m, emit),
        main_(
          class="rise grid min-h-0 grid-rows-[auto_minmax(0,1fr)_auto] overflow-hidden rounded-card border border-line bg-surface shadow-card",
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
                  // copy and download act on this pane, so they live in its
                  // label bar; the toolbar keeps the inputs and the share link
                  div(class="pane-label", [
                    text(t("svgo.mbt output", "svgo.mbt 输出")),
                    div(class="ml-auto flex items-center gap-1", [
                      span(
                        class="mr-1 font-semibold text-mint",
                        if m.notice_at == Output {
                          m.notice
                        } else {
                          ""
                        },
                      ),
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
                  ]),
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
          ],
        ),
      ],
    ),
    page_footer(),
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
        notice_at: Toolbar,
      })
    }
  }
  let (model, emit) = @rabbita.create_state(initial, update=pg_update)
  model.view2(chrome.prefs, (m, p) => pg_view(m, p, chrome, emit))
}
