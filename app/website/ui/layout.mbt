///|
pub const REPO_URL = "https://github.com/PerfectPan/svgo.mbt"

///|
pub const NPM_URL = "https://www.npmjs.com/package/@rivus/svgo"

///|
pub const MOONCAKES_URL = "https://mooncakes.io/docs/PerfectPan/svgo"

///|
/// The logo mark, as an inline SVG. Uses the theme's ink so it inverts in
/// dark mode.
pub fn logo(size? : String = "size-[26px]") -> Html {
  span(
    class="inline-flex",
    attrs=Attrs::build().inner_html(
      "<svg class=\"\{size}\" viewBox=\"0 0 24 24\" aria-hidden=\"true\"><rect width=\"24\" height=\"24\" rx=\"6\" fill=\"var(--color-ink)\"/><path d=\"M7 15.5c1 1.2 2.4 1.8 4 1.8 2.3 0 3.8-1.1 3.8-2.9 0-3.6-7.2-1.6-7.2-5.6C7.6 7.2 9 6 11.2 6c1.5 0 2.8.5 3.7 1.4\" fill=\"none\" stroke=\"var(--color-bg)\" stroke-width=\"1.9\" stroke-linecap=\"round\"/></svg>",
    ),
    nothing,
  )
}

///|
fn icon(svg : String) -> Html {
  span(class="inline-flex", attrs=Attrs::build().inner_html(svg), nothing)
}

///|
fn github_icon() -> Html {
  icon(
    (
      #|<svg class="size-4 fill-current" viewBox="0 0 16 16"><path d="M8 0C3.58 0 0 3.58 0 8c0 3.54 2.29 6.53 5.47 7.59.4.07.55-.17.55-.38 0-.19-.01-.82-.01-1.49-2.01.37-2.53-.49-2.69-.94-.09-.23-.48-.94-.82-1.13-.28-.15-.68-.52-.01-.53.63-.01 1.08.58 1.23.82.72 1.21 1.87.87 2.33.66.07-.52.28-.87.51-1.07-1.78-.2-3.64-.89-3.64-3.95 0-.87.31-1.59.82-2.15-.08-.2-.36-1.02.08-2.12 0 0 .67-.21 2.2.82.64-.18 1.32-.27 2-.27.68 0 1.36.09 2 .27 1.53-1.04 2.2-.82 2.2-.82.44 1.1.16 1.92.08 2.12.51.56.82 1.27.82 2.15 0 3.07-1.87 3.75-3.65 3.95.29.25.54.73.54 1.48 0 1.07-.01 1.93-.01 2.2 0 .21.15.46.55.38A8.01 8.01 0 0 0 16 8c0-4.42-3.58-8-8-8z"/></svg>
    ),
  )
}

///|
fn sun_icon() -> Html {
  icon(
    (
      #|<svg class="size-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><circle cx="12" cy="12" r="4"/><path d="M12 2v2M12 20v2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M2 12h2M20 12h2M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4"/></svg>
    ),
  )
}

///|
fn moon_icon() -> Html {
  icon(
    (
      #|<svg class="size-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 12.8A9 9 0 1 1 11.2 3a7 7 0 0 0 9.8 9.8z"/></svg>
    ),
  )
}

///|
fn nav_link(href : String, label : String, current : Bool) -> Html {
  let attrs = Attrs::build().class("nav-link").href(href)
  let attrs = if current { attrs.aria_current("page") } else { attrs }
  node("a", attrs, label)
}

///|
/// Top bar, fixed to the viewport. `route` marks the current page;
/// `subtitle` sits next to the brand. The language and theme toggles emit
/// to the root through `emit`.
pub fn top_nav(
  route : Route,
  subtitle : String,
  p : Prefs,
  emit : Emit[PrefMsg],
) -> Html {
  let lang_btn = fn(l : Lang, label : String) -> Html {
    button(
      class="seg",
      attrs=Attrs::build().aria_pressed(
        if p.lang == l {
          "true"
        } else {
          "false"
        },
      ),
      on_click=emit(SetLang(l)),
      label,
    )
  }
  nav(class="nav", [
    div(class="wrap flex h-[60px] items-center justify-between gap-4", [
      a(
        href="#/",
        class="flex items-center gap-2.5 font-display text-[17px] font-bold tracking-[-0.02em]",
        [
          logo(),
          text(" svgo.mbt "),
          small(class="font-sans text-[13px] font-medium text-muted", subtitle),
        ],
      ),
      div(class="flex items-center gap-1.5", [
        nav_link("#/", t("Home", "首页"), route == Landing),
        nav_link(
          "#/playground",
          t("Playground", "在线体验"),
          route == Playground,
        ),
        nav_link("#/api", "API", route == Api),
        a(
          href=REPO_URL,
          class="nav-link inline-flex items-center gap-1.5 max-sm:hidden",
          [github_icon(), text("GitHub")],
        ),
        span(class="mx-1 h-5 w-px bg-line-2 max-sm:hidden", nothing),
        div(class="segs", [lang_btn(En, "EN"), lang_btn(Zh, "中")]),
        button(
          class="icon-btn",
          title=t("Toggle dark mode", "切换深色模式"),
          attrs=Attrs::build().aria_label(
            t("Toggle dark mode", "切换深色模式"),
          ),
          on_click=emit(ToggleDark),
          if p.dark {
            sun_icon()
          } else {
            moon_icon()
          },
        ),
      ]),
    ]),
  ])
}

///|
/// Page header used by the API page: eyebrow, display title and a
/// one-paragraph blurb, entering with the same stagger as the hero.
pub fn page_head(eyebrow : String, title : Array[Html], blurb : String) -> Html {
  header(class="wrap pb-8 pt-14", [
    div(class="eyebrow rise", [span(class="dot", nothing), text(" " + eyebrow)]),
    h1(
      class="display rise mt-3 text-[clamp(34px,4.4vw,52px)] leading-[1.05]",
      style=["--d: 70ms"],
      title,
    ),
    p(
      class="rise mt-4 max-w-[62ch] text-base text-ink-2",
      style=["--d: 140ms"],
      blurb,
    ),
  ])
}

///|
pub fn page_footer() -> Html {
  footer(class="pb-14 pt-9 text-[13px] text-muted", [
    div(class="wrap flex flex-wrap justify-between gap-5", [
      div(
        tm(
          [
            text("svgo.mbt · MIT · plugin behavior follows "),
            a(class="text-ink-2", href="https://github.com/svg/svgo", "svgo"),
            text(" (MIT) · this site is also MoonBit, built with "),
            a(
              class="text-ink-2",
              href="https://github.com/moonbit-community/rabbita",
              "Rabbita",
            ),
          ],
          [
            text("svgo.mbt · MIT · 插件行为和 "),
            a(class="text-ink-2", href="https://github.com/svg/svgo", "svgo"),
            text(" 一致（MIT）· 这个站也是 MoonBit 写的，用的 "),
            a(
              class="text-ink-2",
              href="https://github.com/moonbit-community/rabbita",
              "Rabbita",
            ),
          ],
        ),
      ),
      div(class="flex gap-[18px] text-ink-2", [
        a(href=REPO_URL, "GitHub"),
        a(href=MOONCAKES_URL, "mooncakes.io"),
        a(href=NPM_URL, "npm"),
        a(href="#/api", t("API reference", "API 文档")),
      ]),
    ]),
  ])
}

///|
/// Checkerboard preview box that renders an SVG string as live DOM.
pub fn svg_preview(svg : String, class? : String = "preview") -> Html {
  div(attrs=Attrs::build().class(class).inner_html(svg), nothing)
}

///|
/// A code editor with syntax colouring: a highlighted `<pre>` under a
/// transparent `<textarea>` with identical metrics. Both live in one
/// scrolling box and the textarea is sized by the pre, so they never drift.
pub fn code_editor(
  value : String,
  on_input : Emit[String],
  placeholder~ : String,
  label~ : String,
) -> Html {
  div(class="editor", [
    div(class="editor-in", [
      pre(
        class="editor-hl",
        attrs=Attrs::build().aria_hidden("true"),
        [..highlight(value), text("\n")],
      ),
      textarea(
        class="editor-ta",
        value~,
        placeholder~,
        on_input~,
        attrs=Attrs::build().spellcheck(false).aria_label(label),
        nothing,
      ),
    ]),
  ])
}

///|
/// Read-only twin of `code_editor`.
pub fn code_view(value : String, label~ : String) -> Html {
  div(class="editor", [
    pre(
      class="editor-hl editor-out",
      attrs=Attrs::build().aria_label(label),
      highlight(value),
    ),
  ])
}

///|
/// The byte / percent / time strip under an editor pair.
pub fn stats_bar(o : Outcome, note : String) -> Html {
  let ratio = if o.original_size == 0 {
    100.0
  } else {
    o.size.to_double() * 100.0 / o.original_size.to_double()
  }
  let width = if ratio < 2.0 {
    2.0
  } else if ratio > 100.0 {
    100.0
  } else {
    ratio
  }
  div(class="stats", [
    span(class="stat", [
      b(fmt_int(o.original_size)),
      span(t("B in", "B 输入")),
    ]),
    span(class="stat", [b(fmt_int(o.size)), span(t("B out", "B 输出"))]),
    span(
      class="saved",
      if o.error != "" {
        t("parse error", "解析错误")
      } else {
        "−\{fmt_pct(o.saved_percent())}%"
      },
    ),
    span(class="sizebar", [i(style=["width: \{to_fixed(width, 1)}%"], nothing)]),
    span(class="stat", [b(fmt_ms(o.ms)), span("ms")]),
    span(class="text-[13px] text-muted", note),
  ])
}
