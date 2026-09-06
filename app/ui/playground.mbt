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
  let plugin_rows = @svgo.list_plugins().map(it => {
    let (name, desc, _) = it
    label(class="pl", [
      input(
        input_type=Checkbox,
        checked=m.enabled.contains(name),
        on_change=emit.map(_ => Toggle(name)),
      ),
      span([text(name), small(desc)]),
    ])
  })
  aside(
    class="overflow-auto border-r border-line bg-bg-2 p-[18px] max-[900px]:border-b max-[900px]:border-r-0",
    [
      h4(
        class="mb-2 text-[11px] font-bold uppercase tracking-[0.1em] text-muted",
        "Options",
      ),
      label(
        class="flex items-center justify-between gap-2.5 py-[5px] text-[13px]",
        [
          text("precision"),
          input(
            input_type=Number,
            class="w-[60px] rounded-lg border border-line-2 bg-surface px-2 py-1",
            value=m.precision.to_string(),
            min=0,
            max=8,
            on_input=emit.map(v => SetPrecision(v)),
          ),
        ],
      ),
      label(
        class="flex items-center justify-between gap-2.5 py-[5px] text-[13px]",
        [
          text("multipass"),
          input(
            input_type=Checkbox,
            class="accent-accent",
            checked=m.multipass,
            on_change=emit.map(_ => ToggleMultipass),
          ),
        ],
      ),
      label(
        class="flex items-center justify-between gap-2.5 py-[5px] text-[13px]",
        [
          text("pretty print"),
          input(
            input_type=Checkbox,
            class="accent-accent",
            checked=m.pretty,
            on_change=emit.map(_ => TogglePretty),
          ),
        ],
      ),
      h4(
        class="mb-2 mt-5 flex items-center justify-between text-[11px] font-bold uppercase tracking-[0.1em] text-muted",
        [
          text("Plugins"),
          button(
            class="chip -my-1 normal-case tracking-normal",
            on_click=emit(Reset),
            "reset",
          ),
        ],
      ),
      div(plugin_rows),
    ],
  )
}

///|
fn toolbar(m : PgModel, emit : Emit[PgMsg]) -> Html {
  let options = [option(value="", "Samples…")]
  for s in samples {
    options.push(option(value=s.name, s.name))
  }
  div(
    class="flex flex-wrap items-center gap-2.5 border-b border-line px-4 py-2.5",
    [
      select(
        class="rounded-full border border-line-2 bg-surface px-2.5 py-[7px]",
        on_change=emit.map(v => LoadSample(v)),
        attrs=Attrs::build().aria_label("sample"),
        options,
      ),
      label(class="btn btn-sm", for_="pg-file", [
        text("Open .svg"),
        input(
          id="pg-file",
          input_type=File,
          accept=".svg,image/svg+xml",
          hidden=true,
          on_change=emit.map(_ => FilePicked),
        ),
      ]),
      span(class="flex-1", nothing),
      span(class="text-[12.5px] text-mint font-semibold", m.notice),
      button(class="btn btn-sm", on_click=emit(Copy), "Copy output"),
      button(class="btn btn-sm", on_click=emit(Download), "Download"),
      button(
        class="btn btn-sm",
        title="URL with the current input and options",
        on_click=emit(Share),
        "Share link",
      ),
    ],
  )
}

///|
fn pg_view(m : PgModel, emit : Emit[PgMsg]) -> Html {
  div([
    top_nav(Playground, "playground"),
    div(
      class="grid h-[calc(100vh-61px)] grid-cols-[272px_1fr] max-[900px]:h-auto max-[900px]:grid-cols-1",
      [
        sidebar(m, emit),
        main_(class="grid min-h-0 min-w-0 grid-rows-[auto_1fr_auto]", [
          toolbar(m, emit),
          div(class="grid min-h-0 grid-cols-2 max-[900px]:grid-cols-1", [
            div(class="pane", [
              span(class="pane-label", "input"),
              textarea(
                class="!h-auto !min-h-[240px] !flex-1",
                value=m.source,
                placeholder="Paste SVG or pick a sample",
                on_input=emit.map(s => Edit(s)),
                attrs=Attrs::build().spellcheck(false).aria_label("SVG input"),
                nothing,
              ),
              svg_preview(m.source, class="preview !h-[220px]"),
            ]),
            div(
              class="pane border-l border-line max-[900px]:border-l-0 max-[900px]:border-t",
              [
                span(class="pane-label", "output"),
                textarea(
                  class="!h-auto !min-h-[240px] !flex-1",
                  value=if m.outcome.error != "" {
                    m.outcome.error
                  } else {
                    m.outcome.data
                  },
                  read_only=true,
                  attrs=Attrs::build().aria_label("optimized SVG"),
                  nothing,
                ),
                svg_preview(m.outcome.data, class="preview !h-[220px]"),
              ],
            ),
          ]),
          div(class="bg-surface", [
            stats_bar(
              m.outcome,
              "\{m.outcome.passes} pass\{if m.outcome.passes == 1 { "" } else { "es" }} · changed by: \{if m.outcome.applied.is_empty() { "nothing" } else { m.outcome.applied.join(", ") }}",
            ),
          ]),
        ]),
      ],
    ),
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
