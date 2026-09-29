///|
/// Inline Nib illustrations, optimized with the project's own CLI
/// (`svgo-mbt`) so they match the rest of the site's output. `stroke:
/// currentColor` on the outline, antenna and handle dots; `.illustration`
/// sets that colour to Nib's fixed ink, since Nib keeps its colours in both
/// themes. `nib-logo` is public/nib.svg itself (`nib_svg`, generated). Callers size and place each one with their own wrapper
/// class; `name` not matching a known illustration renders nothing, which
/// is also the state before an illustration exists (see CONTRIBUTING).
fn illustration(name : String, class? : String = "") -> Html {
  let svg = match name {
    "nib-logo" => nib_svg
    "nib-dash" => nib_dash_svg
    "nib-arms-up" => nib_arms_up_svg
    "nib-puzzled" => nib_puzzled_svg
    _ => ""
  }
  if svg == "" {
    nothing
  } else {
    span(
      class="illustration \{class}",
      attrs=Attrs::build().inner_html(svg).aria_hidden("true"),
      nothing,
    )
  }
}

///|
/// Small dashing Nib head, riding just ahead of the tip of the svgo.mbt bar
/// in the speed race (40px, see the landing page).
let nib_dash_svg : String =
  #|<svg xmlns="http://www.w3.org/2000/svg" fill="none" stroke="currentColor" stroke-linecap="round" stroke-width="6" viewBox="0 0 256 256"><path stroke-width="7" d="M14 108h36M8 134h34m-22 26h24"/><g transform="rotate(12 186.572 239.658)"><rect width="24" height="24" x="54" y="192" fill="#0b6e63" rx="3" transform="rotate(40 66 204)"/><rect width="24" height="24" x="140" y="206" fill="#0b6e63" rx="3" transform="rotate(-6 152 218)"/><path fill="#ff6b4a" d="M128 70c50 0 84 36 84 80 0 40-36 60-84 60s-84-20-84-60c0-44 34-80 84-80Z"/><path d="m70 62 116 16"/><circle cx="70" cy="62" r="12" fill="currentColor" stroke="none"/><circle cx="186" cy="78" r="12" fill="currentColor" stroke="none"/><rect width="24" height="24" x="116" y="58" fill="#fff7ec" rx="3"/><g stroke="none"><ellipse cx="112" cy="136" fill="#2a1f1a" rx="10" ry="14"/><ellipse cx="166" cy="136" fill="#2a1f1a" rx="10" ry="14"/><circle cx="115" cy="131" r="3.5" fill="#fff7ec"/><circle cx="169" cy="131" r="3.5" fill="#fff7ec"/><ellipse cx="88" cy="160" fill="#fff7ec" opacity=".45" rx="10" ry="6"/><ellipse cx="190" cy="160" fill="#fff7ec" opacity=".45" rx="9" ry="6"/></g><path stroke="#2a1f1a" d="M130 162q10 10 20 0"/></g></svg>

///|
/// Nib with its arms up, shown while a file is dragged over the
/// playground's drop zone (96px) and at half that size for the empty
/// custom-input state.
let nib_arms_up_svg : String =
  #|<svg xmlns="http://www.w3.org/2000/svg" fill="none" stroke="currentColor" stroke-linecap="round" stroke-width="6" viewBox="0 0 256 256"><g transform="translate(0 -10)"><rect width="24" height="24" x="80" y="198" fill="#0b6e63" rx="3"/><rect width="24" height="24" x="152" y="198" fill="#0b6e63" rx="3"/><path fill="#ff6b4a" d="M128 70c50 0 84 36 84 80 0 40-36 60-84 60s-84-20-84-60c0-44 34-80 84-80Z"/><path d="m70 62 116 16"/><circle cx="70" cy="62" r="12" fill="currentColor" stroke="none"/><circle cx="186" cy="78" r="12" fill="currentColor" stroke="none"/><rect width="24" height="24" x="116" y="58" fill="#fff7ec" rx="3"/><g stroke="none"><ellipse cx="100" cy="118" fill="#2a1f1a" rx="10" ry="14"/><ellipse cx="156" cy="118" fill="#2a1f1a" rx="10" ry="14"/><circle cx="103" cy="113" r="3.5" fill="#fff7ec"/><circle cx="159" cy="113" r="3.5" fill="#fff7ec"/><ellipse cx="76" cy="140" fill="#fff7ec" opacity=".45" rx="10" ry="6"/><ellipse cx="180" cy="140" fill="#fff7ec" opacity=".45" rx="10" ry="6"/></g><path stroke="#2a1f1a" d="M118 136q10 10 20 0"/><rect width="72" height="54" x="92" y="156" fill="#d9ae78" rx="3"/><path stroke="#fff7ec" stroke-linecap="butt" d="M128 159v48m-33-33h66"/><path stroke-width="4" d="M92 169h72"/><path fill="#ff6b4a" d="M62 170c14-2 32 4 40 14 6 10-4 20-14 16-12-4-22-12-26-20m132-10c-14-2-32 4-40 14-6 10 4 20 14 16 12-4 22-12 26-20"/></g></svg>

///|
/// Puzzled Nib — one anchor popped off, a flat mouth — shown on a parse
/// error (72px, above the message) and on the 404 page (200px).
let nib_puzzled_svg : String =
  #|<svg xmlns="http://www.w3.org/2000/svg" fill="none" stroke="currentColor" stroke-linecap="round" stroke-width="6" viewBox="0 0 256 256"><path d="M226 132v90"/><path fill="#fff7ec" stroke-linejoin="round" d="M202 140h36l10 10-10 10h-36Zm42 30h-36l-10 10 10 10h36Z"/><g transform="rotate(-6 59.757 346.893)"><rect width="24" height="24" x="72" y="196" fill="#0b6e63" rx="3" transform="rotate(14 84 208)"/><rect width="24" height="24" x="152" y="198" fill="#0b6e63" rx="3" transform="rotate(8 164 210)"/><path fill="#ff6b4a" d="M128 70c50 0 84 36 84 80 0 40-36 60-84 60s-84-20-84-60c0-44 34-80 84-80Z"/><path d="m70 62 116 16"/><circle cx="70" cy="62" r="12" fill="currentColor" stroke="none"/><circle cx="186" cy="78" r="12" fill="currentColor" stroke="none"/><rect width="24" height="24" x="116" y="58" fill="#fff7ec" rx="3"/><g stroke="none"><ellipse cx="100" cy="140" fill="#2a1f1a" rx="10" ry="14"/><ellipse cx="156" cy="144" fill="#2a1f1a" rx="9" ry="12"/><circle cx="103" cy="135" r="3.5" fill="#fff7ec"/><circle cx="159" cy="140" r="3" fill="#fff7ec"/><ellipse cx="78" cy="164" fill="#fff7ec" opacity=".45" rx="10" ry="6"/><ellipse cx="178" cy="166" fill="#fff7ec" opacity=".45" rx="10" ry="6"/></g><path stroke="#2a1f1a" stroke-width="5" d="M146 120q10-8 20 2m-48 50q5-6 10-2t10-2"/></g></svg>
