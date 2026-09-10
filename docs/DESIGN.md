# Website design guidelines

The rules the site at https://perfectpan.github.io/svgo.mbt/ is built to. They apply to
every page and every string; a change that needs an exception should change the rule here
first. Source: `app/website/ui/*.mbt` (views), `app/website/src/style.css` (tokens and
component classes, Tailwind v4).

## Voice

- Written register in both languages. Chinese is 书面语: 中 not 里, 与 not 和, 将…转换为
  not 把…转成, 未使用 not 没用; never 就 / 呗 / 跑一遍 / 喂进去 / 我们. English is plain
  technical prose, no translationese, no exclamation marks.
- Every sentence says something a user cares about: what it does, how fast, where it runs,
  how to install, what is verified. Nothing about how the page or its data was produced,
  except in a footnote and only the minimum (script name, date).
- No slogans that need the implementation to make sense ("every plugin is a value").
- No self-reference ("this page uses it as a dependency").
- Units stay with the number: `200 KB`, `2.9×`, `0 px`, `10 ms`.
- Terminology, one term per concept: 插件 / 预设 (preset-default) / 在线体验 (Playground) /
  原生二进制 (native binary) / 运行时 (runtime) / 输出 (output). Product names as their
  owners write them: svgo, svgo.mbt, MoonBit, WebAssembly, wasm (lowercase in prose),
  wasm-gc, Node.js, Bun, Deno, npm, mooncakes.io.
- Punctuation follows the language: full-width in Chinese（，。：；（）「」）, half-width
  in English. No mixing inside one string.
- Every user-facing string goes through `t(en, zh)` or `tm([...], [...])`; the two halves
  say the same thing.
- svgo is credited where the work is described (hero credit line, footer, README).

## Layout

- One column: `.wrap` = `min(1140px, 100% − 48px)`, centered. Everything aligns to it,
  including the fixed nav's contents.
- Fixed nav, 60 px. Every page starts with `page_head`: eyebrow, display title, one-sentence
  blurb, padding 56 above and 32 below. The landing hero uses the same 56 so the eyebrow sits
  at the same height on every route.
- Landing sections: a display title and the content, no subtitles. Provenance and caveats go
  in a 12.5 px muted footnote under the content.
- Section rhythm on the landing page: 80 px vertical padding, alternating `bg` / `bg-2` with
  hairline borders.
- Cards: `--radius-card` 18 px, 1 px `line` border, `surface` background, 24 px padding
  (20 px for narrow sidebars). Small tiles (plugins) 10 px radius.
- Breakpoints: 961 px separates the desktop two-column layouts (playground workbench, API
  sidebar) from the single-column flow; 800 px stacks the editor panes; 640 px (`max-sm`)
  stacks KPI cards.
- Tool pages (playground) do not lock the whole page to the viewport. The title block scrolls
  away; the workbench below it is exactly `100vh − 60px` tall (min 640 px) so one scroll of
  the header's height leaves it filling the screen; the shared footer follows.
- Sticky sidebars (API) sit 80 px from the top with `max-height: 100vh − 100px` and scroll
  internally; the highlighted item is kept inside the visible area.

## Type

Fonts: Inter (text), Space Grotesk (`.display`: titles, big numbers), JetBrains Mono (code).
All self-hosted with `font-display: swap`.

| px | use |
| --- | --- |
| 11.5 | counts, `.tag` badges, bar labels |
| 12 | hints under options, plugin descriptions, API group labels |
| 12.5 | monospace: editor pane labels, plugin names, API signatures, footnotes |
| 13 | UI labels: sidebar section titles, API sidebar items, chips, small buttons |
| 14 | option labels, API doc prose |
| 15 | card titles, API member names, body text |
| 16 | `page_head` blurb |
| 17 | hero paragraph |
| 18 | numbers in the playground stats bar |
| 22 | API group headings (`.display`) |
| 30–42 | landing section titles (`clamp`) |
| 34–52 | page titles (`clamp`) |
| 42–68 | hero title (`clamp`) |

Line height 1.55 for prose and code, 1.4 for hints, 1.02–1.1 for display sizes. Weights:
400 text, 500 labels, 600 UI emphasis, 700 titles and numbers. Display titles carry
`letter-spacing: -0.03em`.

Labels are never all-caps with letter spacing when they can be Chinese; use 13 px / 600 in
normal case instead. The only uppercase labels are Latin kind tags (`TYPE`, `FN`, `ERROR`)
and the eyebrow.

## Color

Tokens in `style.css` `@theme`, dark palette under `[data-theme="dark"]`. Use tokens only:
`ink` primary text, `ink-2` secondary, `muted` hints and footnotes, `line` / `line-2` borders,
`surface` / `surface-2` cards and inputs, `bg` / `bg-2` page bands, `accent` (emerald) for the
current item, links on hover and "changed" markers, `mint` for wins in tables, `warn` for
losses, `grad` (accent → teal) for the hero highlight and the primary bar. Code cards are
always dark (`code`, `code-fg`).

Never hard-code a color in a view; add a token if one is missing.

## Spacing

4 px grid: 4, 8, 12, 16, 24, 32, 40, 56, 80. Within a card: 24 between blocks, 8 between
rows, 6 between a name and its badge or dot, 10 between a checkbox and its label.

## Components and interaction

- **Buttons**: `.btn` pill, 13–14 px / 600; `.btn-primary` ink on bg (inverts in dark);
  `.btn-sm` inside toolbars. Hover lifts 1 px and tints to accent.
- **Chips** (`.chip`): pill toggles for samples and small actions; the selected one is ink on
  bg (`aria-selected`).
- **Install pills** (`.install`): monospace command with a copy button; copying shows a
  1.5 s notice, no modal.
- **Tags** (`.tag`): 11.5 px mono badges for counts and plugin names.
- **Editors**: highlighted `<pre>` under a transparent `<textarea>` with identical metrics;
  13 px mono; a 36 px label bar above (12.5 px / 600 `ink-2`); a 120 px checkerboard preview
  below.
- **Stats bar**: bytes in, bytes out, saving pill, size bar, ms, passes; numbers in display
  18 / 700, units 13 muted.
- **Playground sidebar**: options (precision, multipass, pretty) fixed at the top, then the
  plugin list as the only scrolling region. A plugin that changed the output in the last run
  shows a 6 px accent dot after its name; the section title shows "N changed the output".
  Toggling a plugin recomputes immediately; the dots follow.
- **API navigation**: one page per package (`#/api/svgo|xml|path|plugins`); the sidebar lists
  all packages with the current one expanded into Types / Functions / Errors, other packages
  show name and count. Member links are `#/api/<pkg>/<Item>`: the URL changes, the page
  scrolls to the member with a 76 px offset, and the item is highlighted (accent text, 2 px
  accent bar on the left). Scrolling the page moves the highlight (one pass per frame) and
  keeps the highlighted item inside the sidebar's visible area.
- **Motion**: entrance `rise` (0.8 s, staggered by `--d`), scroll `reveal` via
  IntersectionObserver, number count-ups, hero blobs drifting. All of it is off under
  `prefers-reduced-motion`. Nothing functional depends on motion.
- **Theme and language**: toggles in the nav, persisted in localStorage, applied before first
  paint (`data-theme` on `<html>`). Language is remembered; the default follows
  `navigator.language`.

## Performance rules

- No external stylesheet or script requests: fonts self-hosted, no CDN.
- Hero videos `preload="none"`, started when visible; only the current theme's video loads.
- The JS bundle is the MoonBit js build, minified by warren; no second minifier.

## Checking a change

`moon check` (zero warnings), `moon fmt --check`, `moon info`,
`moon test --target js -p PerfectPan/svgo-website/ui` (copy tables have tests: every plugin
and every CLI flag needs a Chinese string), `pnpm app`, then screenshots of the touched routes
in both languages and both themes at 1440 px, plus 800 px for layout changes. Background
Chrome tabs do not advance CSS animations or smooth scrolling: inject
`*{animation:none!important;transition:none!important} html{scroll-behavior:auto!important} .motion .reveal{opacity:1!important;translate:none!important}`
before measuring or shooting.
