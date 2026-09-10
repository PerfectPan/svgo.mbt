///|
/// Hash routes, so the site works from any static host (GitHub Pages
/// included) without a rewrite rule: `#/`, `#/playground`, `#/api/<pkg>`
/// (one page per package: svgo, xml, path, plugins) and
/// `#/api/<pkg>/<Item>` for a member anchor.
pub(all) enum Route {
  Landing
  Playground
  Api(String)
} derive(Eq)

///|
impl @rabbita.Enumerate for Route with fn tag(self) {
  match self {
    Landing => "landing"
    Playground => "playground"
    Api(pkg) => "api-" + pkg
  }
}

///|
/// Package short names that have an API page, in display order.
pub let api_package_names : Array[String] = [
  "svgo", "xml", "path", "plugins", "wasm",
]

///|
/// `/api`, `/api/xml`, `/api/xml/Element` → (package, member). Unknown
/// packages fall back to `svgo`.
pub fn parse_api_path(fragment : String) -> (String, String?) {
  let rest = fragment["/api".length():]
  let parts = rest
    .split("/")
    .map(s => s.to_owned())
    .filter(s => !s.is_empty())
    .to_array()
  let pkg = match parts.get(0) {
    Some(p) if api_package_names.contains(p) => p
    _ => "svgo"
  }
  (pkg, parts.get(1))
}

///|
/// Interface preferences, kept by the root and mirrored into `<html>`
/// attributes and localStorage.
pub(all) struct Prefs {
  lang : Lang
  dark : Bool
} derive(Eq)

///|
pub(all) enum PrefMsg {
  SetLang(Lang)
  ToggleDark
}

///|
/// What every page gets from the root: the live preferences and a way to
/// change them (the toggles live in the top bar).
pub(all) struct Chrome {
  prefs : Val[Prefs]
  emit : Emit[PrefMsg]
}

///|
priv struct AppModel {
  route : Route
  prefs : Prefs
} derive(Eq)

///|
priv enum AppMsg {
  UrlChanged(@url.Url)
  UrlRequest(@url.UrlRequest)
  Pref(PrefMsg)
}

///|
fn route_of(url : @url.Url) -> Route {
  match url.fragment {
    Some(f) =>
      if f.has_prefix("/playground") {
        Playground
      } else if f.has_prefix("/api") {
        Api(parse_api_path(f).0)
      } else {
        Landing
      }
    None => Landing
  }
}

///|
fn initial_prefs() -> Prefs {
  let lang = match Lang::parse(load_pref("svgo-lang")) {
    Some(l) => l
    None => if browser_lang().has_prefix("zh") { Zh } else { En }
  }
  { lang, dark: load_pref("svgo-theme") == "dark", }
}

///|
/// Root component: owns the route and the preferences, dispatches to the
/// pages. Pages are created once per route change; preference changes
/// re-render them in place (the playground keeps its editor state).
pub fn app() -> Val[Html] {
  let prefs0 = initial_prefs()
  lang.val = prefs0.lang
  set_theme(prefs0.dark)
  let (model, emit) = @rabbita.create_state(
    { route: Landing, prefs: prefs0, },
    subscriptions=(_, emit) => {
      @sub.batch([
        @sub.on_url_changed(url => emit(UrlChanged(url))),
        @sub.on_url_request(req => emit(UrlRequest(req))),
      ])
    },
    update=(m, msg, _) => {
      match msg {
        UrlRequest(Internal(url)) => (m, @nav.push_url(url.to_string()))
        UrlRequest(External(url)) => (m, @nav.load(url))
        UrlChanged(url) => {
          let route = route_of(url)
          // an API member anchor scrolls to the member once it is rendered;
          // otherwise a route change starts at the top and a query-only
          // change (share links) keeps the scroll position
          let target = match (route, url.fragment) {
            (Api(pkg), Some(f)) =>
              parse_api_path(f).1.map(item => "\{pkg}-\{item}")
            _ => None
          }
          match target {
            Some(id) =>
              (
                { ..m, route, },
                @rabbita.effect(fn() noraise { scroll_to_id(id) }),
              )
            None =>
              if route == m.route {
                (m, none)
              } else {
                ({ ..m, route, }, @nav.scroll_to_top())
              }
          }
        }
        Pref(SetLang(l)) => {
          lang.val = l
          (
            { ..m, prefs: { ..m.prefs, lang: l, }, },
            @rabbita.effect(fn() noraise { save_pref("svgo-lang", l.code()) }),
          )
        }
        Pref(ToggleDark) => {
          let dark = !m.prefs.dark
          (
            { ..m, prefs: { ..m.prefs, dark, }, },
            @rabbita.effect(fn() noraise {
              set_theme(dark)
              save_pref("svgo-theme", if dark { "dark" } else { "light" })
            }),
          )
        }
      }
    },
  )
  let chrome : Chrome = {
    prefs: model.map(m => m.prefs),
    emit: emit.map(p => Pref(p)),
  }
  model
  .map(m => m.route)
  .switch(r => {
    match r {
      Landing => landing_page(chrome)
      Playground => playground_page(chrome)
      Api(pkg) => api_page(chrome, pkg)
    }
  })
}
