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
/// Share links carry the options and the input in the query string:
/// `?p=3&m=1&f=0&x=name,name&s=<base64url source>`.
fn share_url(m : PgModel) -> String {
  let href = location_href()
  let base = match href.find("?") {
    Some(i) => href[:i].to_owned()
    None =>
      match href.find("#") {
        Some(i) => href[:i].to_owned()
        None => href
      }
  }
  let src = if m.source.length() < 20000 { b64_encode(m.source) } else { "" }
  base +
  "?p=\{m.precision}&m=\{if m.multipass { 1 } else { 0 }}&f=\{if m.pretty { 1 } else { 0 }}&x=\{m.enabled.join(",")}&s=\{src}#/playground"
}

///|
/// Restore a model from the current URL's query string, if any.
fn from_url() -> PgModel? {
  let href = location_href()
  guard href.find("?") is Some(q) else { return None }
  let rest = href[q + 1:]
  let query = match rest.find("#") {
    Some(h) => rest[:h].to_owned()
    None => rest.to_owned()
  }
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
          "m" => multipass = value == "1"
          "f" => pretty = value == "1"
          "x" =>
            enabled = value
              .split(",")
              .filter(s => !s.is_empty())
              .map(s => s.to_owned())
              .to_array()
          "s" => source = b64_decode(value.to_owned())
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
          "Output copied",
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
          "Link copied",
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
  aside(
    class="rise card min-[961px]:sticky min-[961px]:top-20 min-[961px]:max-h-[calc(100vh-96px)] min-[961px]:overflow-auto",
    style=["--d: 120ms"],
    [
      div(class="side-head", [text("Options")]),
      label(class="opt", [
        span([text("precision"), small("decimal places kept in numbers")]),
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
        span([text("multipass"), small("repeat until nothing changes")]),
        input(
          input_type=Checkbox,
          class="switch",
          checked=m.multipass,
          on_change=emit.map(_ => ToggleMultipass),
        ),
      ]),
      label(class="opt", [
        span([text("pretty print"), small("indented output")]),
        input(
          input_type=Checkbox,
          class="switch",
          checked=m.pretty,
          on_change=emit.map(_ => TogglePretty),
        ),
      ]),
      div(class="side-head mt-6", [
        span(class="flex items-center gap-2", [
          text("Plugins"),
          span(
            class="tag normal-case tracking-normal",
            "\{m.enabled.length()}/\{all.length()}",
          ),
        ]),
        button(
          class="chip -my-1 normal-case tracking-normal",
          on_click=emit(Reset),
          "reset",
        ),
      ]),
      div(class="divide-y divide-line", plugin_rows),
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
          text("Open .svg…"),
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
        button(class="btn btn-sm", on_click=emit(Copy), "Copy output"),
        button(class="btn btn-sm", on_click=emit(Download), "Download"),
        button(
          class="btn btn-primary btn-sm",
          title="URL with the current input and options",
          on_click=emit(Share),
          "Share link",
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
        "changed by",
      ),
      if o.applied.is_empty() {
        span(class="text-muted", "nothing yet")
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
fn pg_view(m : PgModel, emit : Emit[PgMsg]) -> Html {
  div([
    top_nav(Playground, "playground"),
    page_head(
      "Playground · runs in your browser",
      [text("Try it on "), span(class="grad", "your own files.")],
      "Paste an SVG, open a file or pick a sample, then tune precision and plugins and watch the output change as you type. Copy it, download it or share a link that carries your input and options. Nothing leaves this tab: the optimizer is MoonBit compiled to JavaScript.",
    ),
    div(
      class="wrap grid items-start gap-5 pb-20 min-[961px]:grid-cols-[280px_minmax(0,1fr)]",
      [
        sidebar(m, emit),
        main_(
          class="rise overflow-hidden rounded-card border border-line bg-surface shadow-card",
          style=["--d: 220ms"],
          [
            toolbar(m, emit),
            div(class="grid grid-cols-2 max-[800px]:grid-cols-1", [
              div(class="pane", [
                span(class="pane-label", "input"),
                textarea(
                  class="!h-[min(48vh,420px)]",
                  value=m.source,
                  placeholder="Paste SVG or pick a sample",
                  on_input=emit.map(s => Edit(s)),
                  attrs=Attrs::build().spellcheck(false).aria_label("SVG input"),
                  nothing,
                ),
                svg_preview(m.source, class="preview !h-[200px]"),
              ]),
              div(
                class="pane border-l border-line max-[800px]:border-l-0 max-[800px]:border-t",
                [
                  span(class="pane-label", "svgo.mbt output"),
                  textarea(
                    class="!h-[min(48vh,420px)]",
                    value=if m.outcome.error != "" {
                      m.outcome.error
                    } else {
                      m.outcome.data
                    },
                    read_only=true,
                    attrs=Attrs::build().aria_label("optimized SVG"),
                    nothing,
                  ),
                  svg_preview(m.outcome.data, class="preview !h-[200px]"),
                ],
              ),
            ]),
            stats_bar(
              m.outcome,
              "\{m.outcome.passes} pass\{if m.outcome.passes == 1 { "" } else { "es" }}",
            ),
            applied_row(m.outcome),
          ],
        ),
      ],
    ),
    page_footer(),
  ])
}

///|
/// The playground page.
pub fn playground_page() -> Val[Html] {
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
  model.view(m => pg_view(m, emit))
}
