///|
pub const REPO_URL = "https://github.com/PerfectPan/svgo.mbt"

///|
pub const SVGO_URL = "https://github.com/svg/svgo"

///|
pub const NPM_URL = "https://www.npmjs.com/package/@rivus/svgo"

///|
pub const MOONCAKES_URL = "https://mooncakes.io/docs/PerfectPan/svgo"

///|
fn icon(svg : String) -> Html {
  span(class="inline-flex", attrs=Attrs::build().inner_html(svg), nothing)
}

///|
fn github_icon() -> Html {
  icon(
    (
      #|<svg class="size-4 fill-current" viewBox="0 0 16 16"><path d="M8 0C3.58 0 0 3.58 0 8c0 3.54 2.29 6.53 5.47 7.59.4.07.55-.17.55-.38 0-.19-.01-.82-.01-1.49-2.01.37-2.53-.49-2.69-.94-.09-.23-.48-.94-.82-1.13-.28-.15-.68-.52-.01-.53.63-.01 1.08.58 1.23.82.72 1.21 1.87.87 2.33.66.07-.52.28-.87.51-1.07-1.78-.2-3.64-.89-3.64-3.95 0-.87.31-1.59.82-2.15-.08-.2-.36-1.02.08-2.12 0 0 .67-.21 2.2.82.64-.18 1.32-.27 2-.27s1.36.09 2 .27c1.53-1.04 2.2-.82 2.2-.82.44 1.1.16 1.92.08 2.12.51.56.82 1.27.82 2.15 0 3.07-1.87 3.75-3.65 3.95.29.25.54.73.54 1.48 0 1.07-.01 1.93-.01 2.2 0 .21.15.46.55.38A8.01 8.01 0 0 0 16 8c0-4.42-3.58-8-8-8"/></svg>
    ),
  )
}

///|
fn sun_icon() -> Html {
  icon(
    (
      #|<svg fill="none" stroke="currentColor" stroke-linecap="round" stroke-width="2" class="size-4" viewBox="0 0 24 24"><circle cx="12" cy="12" r="4"/><path d="M12 2v2m0 16v2M4.9 4.9l1.4 1.4m11.4 11.4 1.4 1.4M2 12h2m16 0h2M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4"/></svg>
    ),
  )
}

///|
fn moon_icon() -> Html {
  icon(
    (
      #|<svg fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2" class="size-4" viewBox="0 0 24 24"><path d="M21 12.8A9 9 0 1 1 11.2 3a7 7 0 0 0 9.8 9.8"/></svg>
    ),
  )
}

///|
/// The mobile menu disclosure's own chevron, not the browser's native
/// `<summary>` marker (a plain "▶" reads as a play button, not a
/// disclosure — see `.mobile-nav summary` for the marker suppression and
/// `[open]` rotation).
fn chevron_icon() -> Html {
  icon(
    (
      #|<svg fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2" aria-hidden="true" class="mobile-nav-chevron size-3.5 transition-transform" viewBox="0 0 24 24"><path d="m6 9 6 6 6-6"/></svg>
    ),
  )
}

///|
fn nav_link(href : String, label : String, current : Bool) -> Html {
  let attrs = Attrs::build()
    .class(
      "nav-link grow-line inline-flex items-center gap-1.5 p-2 text-sm text-ink-2",
    )
    .href(href)
  let attrs = if current { attrs.aria_current("page") } else { attrs }
  node("a", attrs, label)
}

///|
/// Shared navigation. Native details keeps the narrow-screen menu keyboard accessible.
pub fn top_nav(route : Route, p : Prefs, emit : Emit[PrefMsg]) -> Html {
  let links = fn() -> Array[Html] {
    [
      nav_link(
        "#/playground",
        t("Playground", "在线体验"),
        route == Playground,
      ),
      nav_link("#/api", "API", route is Api(_)),
      a(
        class="nav-link grow-line inline-flex items-center gap-1.5 p-2 text-sm text-ink-2",
        href=REPO_URL,
        [github_icon(), text("GitHub")],
      ),
      div(
        class="segs mx-2 inline-flex overflow-hidden rounded-full border border-line",
        attrs=Attrs::build().data_set("slide", "fill"),
        [
          button(
            class="seg px-2.75 py-1.75 text-xs text-muted transition-colors aria-pressed:text-paper",
            attrs=Attrs::build().aria_pressed((p.lang == En).to_string()),
            on_click=emit(SetLang(En)),
            "EN",
          ),
          button(
            class="seg px-2.75 py-1.75 text-xs text-muted transition-colors aria-pressed:text-paper",
            attrs=Attrs::build().aria_pressed((p.lang == Zh).to_string()),
            on_click=emit(SetLang(Zh)),
            "中文",
          ),
        ],
      ),
      button(
        class="icon-btn inline-flex size-8.5 items-center justify-center rounded-full border border-line bg-paper-2",
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
    ]
  }
  nav(
    class="nav fixed inset-x-0 top-0 z-20 h-(--nav-h) border-b border-line bg-paper",
    [
      div(
        class="wrap nav-inner flex h-(--nav-h) items-center justify-between gap-4",
        [
          a(
            href="#/",
            class="brand flex items-center gap-2.25 font-display text-xl font-semibold text-ink",
            [
              // nib.svg's figure fills about two-thirds of its viewBox, so the
              // box is larger than the 28px mark and pulled in by margins
              illustration(
                "nib-logo",
                class="nib-mark -mx-1.5 -my-2 size-10 flex-none",
              ),
              text("svgo.mbt"),
            ],
          ),
          // links, language and theme sit together on the right; the brand is
          // the only thing on the left. No separate "Try it" CTA: the
          // Playground link already is one.
          div(class="ml-auto flex flex-none items-center gap-2", [
            div(class="nav-links hidden items-center gap-2 sm:flex", links()),
            node(
              "details",
              Attrs::build().class("mobile-nav block sm:hidden"),
              [
                node(
                  "summary",
                  Attrs::build().class(
                    "flex items-center gap-1.5 py-2 pl-4 font-mono text-sm",
                  ),
                  [text(t("Menu", "菜单")), chevron_icon()],
                ),
                div(
                  class="mobile-panel absolute inset-x-0 top-(--nav-h) flex flex-wrap items-center gap-2 border-b border-line-2 bg-paper p-4",
                  links(),
                ),
              ],
            ),
          ]),
        ],
      ),
    ],
  )
}

///|
/// Compact document metadata; route-specific cells require the caller's route.
pub fn page_footer(route? : Route) -> Html {
  let measurement = match route {
    Some(Landing) =>
      t(
        "measured \{generated_on} · svgo \{svgo_js_version} · Node.js \{node_version}",
        "测量于 \{generated_on} · svgo \{svgo_js_version} · Node.js \{node_version}",
      )
    Some(Playground) => t("runs in this browser", "在本机浏览器运行")
    _ => ""
  }
  footer(class="site-footer border-t border-line py-10", [
    div(class="wrap", [
      div(
        class="footer-row flex flex-wrap items-center gap-x-5 gap-y-2.5 font-mono text-code text-ink-2 max-sm:flex-col max-sm:items-start",
        [
          span(class="footer-brand font-semibold text-ink", "svgo.mbt"),
          span("v\{project_version} · MIT"),
          if measurement == "" {
            nothing
          } else {
            span(measurement)
          },
          div(
            class="footer-links ml-auto flex flex-wrap gap-x-4 gap-y-1 max-sm:ml-0",
            [
              a(
                class="grow-line text-ink-2 hover:text-ink",
                href=REPO_URL,
                "GitHub",
              ),
              a(
                class="grow-line text-ink-2 hover:text-ink",
                href=NPM_URL,
                "npm",
              ),
              a(
                class="grow-line text-ink-2 hover:text-ink",
                href=MOONCAKES_URL,
                "mooncakes.io",
              ),
            ],
          ),
        ],
      ),
      p(
        class="footnote mt-4",
        tm(
          [
            text("Based on "),
            a(href=SVGO_URL, "svgo"),
            text(" by Kir Belevich and contributors (MIT)."),
          ],
          [
            text("基于 "),
            a(href=SVGO_URL, "svgo"),
            text("（Kir Belevich 及贡献者，MIT）。"),
          ],
        ),
      ),
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
      // input only (code_view, the read-only output pane, keeps the default
      // break-anywhere wrap — its content is minified): wrap at word
      // boundaries only, so a long attribute URL overflows and scrolls
      // instead of splitting mid-token, and the raw source's own
      // indentation reads as typed. The pre and the textarea must share the
      // exact same wrap rule or their line breaks drift apart (see the doc
      // comment above).
      pre(
        class="editor-hl editor-wrap-normal",
        attrs=Attrs::build().aria_hidden("true"),
        [..highlight(value), text("\n")],
      ),
      textarea(
        class="editor-ta editor-wrap-normal",
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
/// The byte / percent / time strip under an editor pair. Below 640px it is
/// three fixed rows (in/out, meter, saved/ms/note) so long labels — the
/// Chinese ones especially — never wrap into an orphan line; from 640px the
/// two row wrappers collapse (`display: contents`) and explicit `order`
/// values restore the single-line desktop sequence (in, out, saved, meter,
/// ms, note) regardless of source order.
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
    div(class="stats-row sm:contents", [
      span(class="stat sm:order-1", [
        display_measure(
          fmt_int(o.original_size),
          t("B in", "B 输入"),
          id="pg-stat-in",
        ),
      ]),
      span(class="stat sm:order-2", [
        display_measure(
          fmt_int(o.size),
          t("B out", "B 输出"),
          id="pg-stat-out",
        ),
      ]),
    ]),
    span(class="sizebar sm:order-4", [
      i(style=["width: \{to_fixed(width, 1)}%"], nothing),
    ]),
    div(class="stats-row sm:contents", [
      span(
        class="saved sm:order-3",
        if o.error != "" {
          t("parse error", "解析错误")
        } else {
          "−\{fmt_pct(o.saved_percent())}%"
        },
      ),
      span(class="stat sm:order-5", [display_measure(fmt_ms(o.ms), "ms")]),
      span(class="sm:order-6 text-code text-muted", note),
    ]),
  ])
}
