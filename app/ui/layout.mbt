///|
pub const REPO_URL = "https://github.com/PerfectPan/svgo.mbt"

///|
pub const NPM_URL = "https://www.npmjs.com/package/svgo-mbt"

///|
pub const MOONCAKES_URL = "https://mooncakes.io/docs/perfectpan/svgo"

///|
/// The logo mark, as an inline SVG.
pub fn logo(size? : String = "size-[26px]") -> Html {
  span(
    class="inline-flex",
    attrs=Attrs::build().inner_html(
      "<svg class=\"\{size}\" viewBox=\"0 0 24 24\" aria-hidden=\"true\"><rect width=\"24\" height=\"24\" rx=\"6\" fill=\"#0b0d12\"/><path d=\"M7 15.5c1 1.2 2.4 1.8 4 1.8 2.3 0 3.8-1.1 3.8-2.9 0-3.6-7.2-1.6-7.2-5.6C7.6 7.2 9 6 11.2 6c1.5 0 2.8.5 3.7 1.4\" fill=\"none\" stroke=\"#fff\" stroke-width=\"1.9\" stroke-linecap=\"round\"/></svg>",
    ),
    nothing,
  )
}

///|
fn github_icon() -> Html {
  span(
    class="inline-flex",
    attrs=Attrs::build().inner_html(
      (
        #|<svg class="size-4 fill-current" viewBox="0 0 16 16"><path d="M8 0C3.58 0 0 3.58 0 8c0 3.54 2.29 6.53 5.47 7.59.4.07.55-.17.55-.38 0-.19-.01-.82-.01-1.49-2.01.37-2.53-.49-2.69-.94-.09-.23-.48-.94-.82-1.13-.28-.15-.68-.52-.01-.53.63-.01 1.08.58 1.23.82.72 1.21 1.87.87 2.33.66.07-.52.28-.87.51-1.07-1.78-.2-3.64-.89-3.64-3.95 0-.87.31-1.59.82-2.15-.08-.2-.36-1.02.08-2.12 0 0 .67-.21 2.2.82.64-.18 1.32-.27 2-.27.68 0 1.36.09 2 .27 1.53-1.04 2.2-.82 2.2-.82.44 1.1.16 1.92.08 2.12.51.56.82 1.27.82 2.15 0 3.07-1.87 3.75-3.65 3.95.29.25.54.73.54 1.48 0 1.07-.01 1.93-.01 2.2 0 .21.15.46.55.38A8.01 8.01 0 0 0 16 8c0-4.42-3.58-8-8-8z"/></svg>
      ),
    ),
    nothing,
  )
}

///|
fn nav_link(href : String, label : String, current : Bool) -> Html {
  let attrs = Attrs::build().class("nav-link").href(href)
  let attrs = if current { attrs.aria_current("page") } else { attrs }
  node("a", attrs, label)
}

///|
/// Top navigation. `route` marks the current page; `subtitle` sits next to
/// the brand (version on the landing page, page name elsewhere).
pub fn top_nav(route : Route, subtitle : String) -> Html {
  nav(class="nav", [
    div(class="wrap flex h-[60px] items-center justify-between", [
      a(
        href="#/",
        class="flex items-center gap-2.5 font-display text-[17px] font-bold tracking-[-0.02em]",
        [
          logo(),
          text(" svgo.mbt "),
          small(class="font-sans text-[13px] font-medium text-muted", subtitle),
        ],
      ),
      div(class="flex gap-1.5", [
        nav_link("#/", "Home", route == Landing),
        nav_link("#/playground", "Playground", route == Playground),
        nav_link("#/api", "API", route == Api),
        a(href=REPO_URL, class="nav-link inline-flex items-center gap-1.5", [
          github_icon(),
          text("GitHub"),
        ]),
      ]),
    ]),
  ])
}

///|
pub fn page_footer() -> Html {
  footer(class="pb-14 pt-9 text-[13px] text-muted", [
    div(class="wrap flex flex-wrap justify-between gap-5", [
      div([
        text("svgo.mbt · MIT · plugin semantics follow "),
        a(class="text-ink-2", href="https://github.com/svg/svgo", "svgo"),
        text(" (MIT) · this site is MoonBit too, built with "),
        a(
          class="text-ink-2",
          href="https://github.com/moonbit-community/rabbita",
          "Rabbita",
        ),
      ]),
      div(class="flex gap-[18px] text-ink-2", [
        a(href=REPO_URL, "GitHub"),
        a(href=MOONCAKES_URL, "mooncakes.io"),
        a(href=NPM_URL, "npm"),
        a(href="#/api", "API reference"),
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
    span(class="stat", [b(fmt_int(o.original_size)), span("B in")]),
    span(class="stat", [b(fmt_int(o.size)), span("B out")]),
    span(
      class="saved",
      if o.error != "" {
        "parse error"
      } else {
        "−\{fmt_pct(o.saved_percent())}%"
      },
    ),
    span(class="sizebar", [i(style=["width: \{to_fixed(width, 1)}%"], nothing)]),
    span(class="stat", [b(fmt_ms(o.ms)), span("ms")]),
    span(class="text-[13px] text-muted", note),
  ])
}
