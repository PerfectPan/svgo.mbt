///|
/// A small floating switcher to compare accent palettes live. The choice is
/// a `data-palette` attribute on <html> (see src/style.css) and survives
/// reloads via localStorage.
priv enum PaletteMsg {
  Choose(String)
}

///|
let palettes : Array[(String, String, String)] = [
  ("emerald", "Emerald", "linear-gradient(135deg,#059669,#14b8a6)"),
  ("ocean", "Ocean", "linear-gradient(135deg,#2563eb,#06b6d4)"),
  ("warm", "Warm", "linear-gradient(135deg,#f97316,#e11d48)"),
  ("violet", "Violet", "linear-gradient(135deg,#6d5dfc,#16c79a)"),
]

///|
pub fn palette_switcher() -> Val[Html] {
  let (current, emit) = @rabbita.create_state(get_palette(), update=(_, msg, _) => {
    match msg {
      Choose(name) =>
        (name, @rabbita.effect(fn() noraise { set_palette(name) }))
    }
  })
  current.view(current => {
    div(
      class="fixed bottom-4 right-4 z-20 flex items-center gap-1.5 rounded-full border border-line bg-surface/90 px-2.5 py-1.5 shadow-card backdrop-blur-md",
      [
        span(
          class="pl-1 pr-1 text-[11px] font-bold uppercase tracking-[0.1em] text-muted",
          "palette",
        ),
        ..palettes.map(entry => {
          let (name, label, grad) = entry
          button(
            class=if name == current {
              "flex items-center gap-1.5 rounded-full bg-ink py-1 pl-1 pr-2.5 text-[12px] font-semibold text-bg"
            } else {
              "flex items-center gap-1.5 rounded-full py-1 pl-1 pr-2.5 text-[12px] font-medium text-ink-2 hover:bg-surface-2"
            },
            title=label,
            on_click=emit(Choose(name)),
            [
              span(
                class="size-4 rounded-full ring-2 ring-white",
                style=["background: \{grad}"],
                nothing,
              ),
              text(label),
            ],
          )
        }),
      ],
    )
  })
}
