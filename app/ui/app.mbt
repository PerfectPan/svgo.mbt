///|
/// Hash routes, so the site works from any static host (GitHub Pages
/// included) without a rewrite rule: `#/`, `#/playground`, `#/api`.
pub(all) enum Route {
  Landing
  Playground
  Api
} derive(Eq)

///|
impl @rabbita.Enumerate for Route with fn tag(self) {
  match self {
    Landing => "landing"
    Playground => "playground"
    Api => "api"
  }
}

///|
priv enum NavMsg {
  UrlChanged(@url.Url)
  UrlRequest(@url.UrlRequest)
}

///|
fn route_of(url : @url.Url) -> Route {
  match url.fragment {
    Some(f) =>
      if f.has_prefix("/playground") {
        Playground
      } else if f.has_prefix("/api") {
        Api
      } else {
        Landing
      }
    None => Landing
  }
}

///|
/// Root component: owns the route, dispatches to the pages.
pub fn app() -> Val[Html] {
  let (route, _) = @rabbita.create_state(
    Landing,
    subscriptions=(_, emit) => {
      @sub.batch([
        @sub.on_url_changed(url => emit(UrlChanged(url))),
        @sub.on_url_request(req => emit(UrlRequest(req))),
      ])
    },
    update=(current, msg, _) => {
      match msg {
        UrlRequest(Internal(url)) => (current, @nav.push_url(url.to_string()))
        UrlRequest(External(url)) => (current, @nav.load(url))
        UrlChanged(url) => (route_of(url), @nav.scroll_to_top())
      }
    },
  )
  route.switch(r => {
    match r {
      Landing => landing_page()
      Playground => playground_page()
      Api => api_page()
    }
  })
}
