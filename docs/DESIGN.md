# Website design guidelines

The rules the site at https://perfectpan.github.io/svgo.mbt/ is built to. They apply to
every page and every string; a change that needs an exception should change the rule here
first. Source: `app/website/ui/*.mbt` (views), `app/website/src/style.css` (tokens and
component classes, Tailwind v4), `app/website/samples/` (the SVGs the site optimizes).

## Idea

Warm, confident and immediately understood. A visitor gets the point from the first screen in
a few seconds: your SVGs get smaller and faster, and they look the same. Each landing screen
makes one point with one big line and one visual; everything else is one click away.

- One idea per screen: smaller (the hero), faster, same pixels, install. Detail (benchmark
  tables, the plugin list, CLI flags) sits in collapsed disclosures, not on the page.
- Show the product working instead of describing it: the hero is Nib, the mascot, standing
  still while its own file size counts down; the "same pixels" screen shows real logos with
  their before/after sizes. Every number comes from `data.json` or from optimizing the sample
  at runtime; one figure has one value on every page.
- Evidence stays honest: the speed bars and the headline use the same metric, svgo's numbers
  are measured with the same plugin set, and the few files where svgo is smaller are listed.
- No generic AI look: no gradient text, glow blobs, eyebrow chips, card grids of everything,
  emoji, fake window chrome.

## Samples

`app/website/samples/` holds the SVGs the landing page and the playground optimize: Nib (drawn
for the project; its copy carries editor-style metadata so there is something to remove) and
three model logos (DeepSeek, Qwen, Mistral). `SOURCES.md` there records where each came from
and its licence; logos are trademarks of their owners and the page says so under them. Every
sample must render with 0 differing pixels (`node packages/compare/render-diff.mjs
app/website/samples`); a file that does not is not a sample. The benchmark corpus
(`svgo/testdata/`, `packages/compare/corpus/`) is separate and only feeds the numbers.

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

- One column: `.wrap` centred with side gutters of at least 24 px (16 px below 640 px).
- Nav: brand (coral dot + `svgo.mbt` in the display face), Playground, API, GitHub, language and
  theme, and the "Open the playground" pill on the right; nothing may overflow at 390 px.
- The hero fills the first screen: `min-h-[calc(100svh-var(--nav-h))]` (the nav's own height) with its
  content vertically centred, headline left and the Nib counter right. No screen is a centred
  text block: the hero and every later landing screen (speed, pixel-identical output) put a
  title and its one line of text on the left of a 12-column grid inside `.wrap` (columns 1–5)
  and the visual on the right (columns 6–12); the install block spans the full width with a
  left-aligned title instead. Below 961 px everything stacks to one column, still left-aligned.
- Landing screens are generous: about 96 px of vertical space around each, separated by a
  subtle tone step (`paper-2`) or a hairline, never by a strong colour band. The speed screen's
  full-width tinted band spans the viewport via a box-shadow/clip-path trick while its content
  stays inside `.wrap`.
- The footer is one quiet row: project, version, licence, measurement environment (landing),
  links, and the svgo credit.
- Tool pages (playground) start with the tool: a thin toolbar (samples, open, share) and the
  workbench; on narrow screens the result comes first and the options follow.
- Breakpoints: `--breakpoint-lg` 961 px (two-column layouts, the API sidebar), `--breakpoint-sm` 640 px (compact nav, the stats
  bar's single row). Defined once in `style.css` `@theme`; use `sm:`/`md:`/`lg:`/`max-sm:`/
  `max-lg:`, never `min-[…px]:`/`max-[…px]:`.

## Type

- Fraunces (`.display`, 500/600): headlines, screen titles, big numbers.
- Space Grotesk (400/500): prose and UI.
- JetBrains Mono: code, file names and byte captions.
- Chinese falls back to the system faces ("PingFang SC", "Noto Sans CJK SC"; headings "Songti SC",
  "Noto Serif CJK SC"); a coloured phrase in a Chinese headline never breaks inside itself.

Every size is a `--text-*` token in `style.css` `@theme`; no `text-[…]` or `font-size:`/`font:`
literal anywhere else. Line height 1.05–1.15 for display, 1.6 for prose; `--leading-cjk` (1.7) is
the Chinese prose line height next to Tailwind's own `leading-snug`/`leading-relaxed` steps. A unit
next to a big number is its own span at a readable size (never below 11 px, `--text-2xs`).

| token | size | line height | role |
| --- | --- | --- | --- |
| `--text-2xs` | 11 px | 16 px | the smallest labels (plugin row numbers, group headings) |
| `--text-xs` | 12 px | 16 px | captions, small UI labels |
| `--text-code` | 13 px | 20 px | code, byte captions, figure captions, table cells |
| `--text-sm` | 14 px | 20 px | secondary text, nav links, buttons |
| `--text-base` | 16 px | 1.6 | body prose |
| `--text-lg` | 18 px | 28 px | emphasised prose, screen lead-ins (`.screen-line`) |
| `--text-xl` | 20 px | 28 px | small headings (disclosure summaries) |
| `--text-2xl` | 24 px | 32 px | group headings (API `h2`) |
| `--text-page` | clamp(28, 3.6vw, 40) px | 1.15 | the API page's own compact `h1` |
| `--text-section` | clamp(32, 4.4vw, 52) px | 1.15 | landing screen titles |
| `--text-hero` / `--text-hero-zh` | clamp(44, 6vw, 84) / clamp(34, 5.2vw, 68) px | 1.08 / 1.15 | the hero `h1`, Latin / Chinese |
| `--text-number` | clamp(40, 5.6vw, 68) px | 1 | the hero byte counter, the benchmark's big numbers |
| `--text-number-unit` | clamp(18, 2vw, 26) px | — | the unit beside a `--text-number` figure |

## Spacing

Tailwind's `--spacing` scale (4 px steps, including the fractional classes: `gap-5.5` = 22 px).
No `p-[…px]`/`gap-[…px]`/`w-[…px]` etc. in the views; in `style.css` use the `--spacing(n)`
function instead of a literal `px` value (`padding: --spacing(4);`, not `padding: 16px;`).
Text measures (a paragraph's `max-width` in `ch`) are named `--container-*` tokens instead:

| token | value | role |
| --- | --- | --- |
| `--container-tight` | 14ch | the hero `h1` |
| `--container-narrow` | 36ch | a short error message |
| `--container-copy` | 48ch | the hero's lead paragraph |
| `--container-lead` | 50ch | a screen's lead-in line (`.screen-line`) |
| `--container-read` | 62ch | a page's intro paragraph (API, reference pages) |
| `--container-doc` | 72ch | a member's doc prose (API reference) |

A handful of fixed layout dimensions have no home in either scale and are their own tokens
instead of a literal: `--nav-h` (56 px, the fixed nav's height, used in `calc()`), `--pg-sidebar-w`
/ `--api-side-w` / `--api-main-w` (the playground and API two-column grid tracks), and
`--api-side-clearance` (the API sidebar's sticky-scroll cap). `--border-w-bold` (1.5 px) is the
bolder stroke on buttons, pills and the hero's anchor markers, next to Tailwind's own default
(1 px) and `border-2` (2 px) steps.

## Color

Tokens in `style.css` `@theme`, dark palette under `[data-theme="dark"]`; use tokens only.
Light: `paper` cream page, `paper-2` a slightly deeper cream for a screen that needs separation,
`card` the white tile behind logos,
`ink` warm near-black text, `ink-2` secondary, `muted` captions, `line` hairlines, `mark` coral:
the primary CTA, the saved amount and the svgo.mbt bar. Teal appears only
inside Nib. Dark theme is warm (brown-black paper, cream ink), not blue-black; coral stays. Nib
(hero, nav logo, illustrations, favicon) keeps its own colours in both themes: no dark variant;
on the dark paper it gets a thin cream sticker rim (a filter) so the ink outline and antenna show.
The playground's dark preview checker is a mid-dark grey for the same reason.
Every SVG the site ships, inline or in `public/`, is svgo.mbt output (run it through the CLI first).
Checkerboards behind SVG previews stay light enough that dark samples remain visible; the
playground has a Light/Dark checker toggle. A few colours are fixed regardless of theme, also
tokens rather than a bare hex: `--color-white` (selection text, the logo comparison tiles),
`--color-mark-ink` (the warm-dark text on the coral fill) and `--color-race-dim` (the losing
speed-race bar in dark mode, the light theme's own `ink-2` hex).

## Components and interaction

- **Radius**: one scale everywhere, nothing else.

  | class | value | role |
  | --- | --- | --- |
  | `rounded-full` | a pill | buttons, the install line, segmented switches, tabs-as-pills |
  | `rounded-2xl` | 16 px | cards, panels, code blocks, rounded preview frames |
  | `rounded-lg` | 8 px | small controls (inputs, select, copy chips), inline code, one-line signatures |
- **Buttons**: pills. Primary: coral fill, paper text, the one soft shadow on the page; secondary:
  hairline outline. Text actions (copy, download) are plain underlined-on-hover text.
- **Nav**: Nib (the `nib-logo` illustration, redrawn for 28 px) and "svgo.mbt" on the left;
  links, language and theme together on the right, no separate CTA. The current page's link is
  underlined; on hover the same line grows from the left at a constant speed (240 ms, linear).
- **Install line**: mono command in a hairline pill with a "copy" action.
- **Toast**: every copy or share action confirms with one success toast, `@rui.sonner` (RUI, the
  Rabbita component library in shadcn's style) mounted once in `app.mbt`: the install line's hairline
  pill with ink text and a coral check, one line sized to its text, no close button, top centre under the nav, 2 s. Raise it with `toast_success(title)`; never swap a button's
  label or show an inline "copied" instead.
- **Hero counter**: counts down once (about 1.2 s) from the original to the optimized size of
  `nib.svg`; the bar under it shrinks to the kept fraction. Under `prefers-reduced-motion` the
  end state is shown at once. Nothing else moves.
- **Speed race**: two lanes, name and median time above each bar, bar length proportional to
  time (svgo full width); labels never sit on a bar.
- **Logo cards**: a white rounded tile per sample, the caption `name · before → after B −N%`
  under it; three in a row on desktop, one column on phones.
- **Disclosures**: "Benchmarks" (size table, per-file speed chart, their footnotes) and
  "36 plugins" (the pipeline list), collapsed by default.
- **Playground**: sample tabs as pills (current one filled), editors with soft wrap, previews on
  the checkerboard, the stats bar (in, out, saved in coral, ms, passes).
- **API**: package switcher and TOC on the left, one reading column, MoonBit keywords as kickers
  (`struct`, `fn`, `suberror`), hairline code blocks with a copy action on multi-line ones.
- **Sliding selection**: every segmented control and tab row (language, package manager, install
  tabs, sample chips, preview background) carries `data-slide="fill"` or `"line"`, the API table of
  contents `"rail"`; the selection is the group's `::before`, measured by `install_slides`
  (browser.mbt), and slides between items (320 ms, `--ease-out-soft`). A new group only needs the
  attribute.
- **State changes**: every `<details>` opens to its natural height (`::details-content`); the
  mobile menu fades down; a page's content fades in rising 8 px when you move to it (not on the
  first load); the theme switch spreads from the toggle as a circle (a View Transition); a plugin's
  "changed" dot pops in and out rather than appearing.
- **Hover accents**: one vocabulary, hover only, off under `prefers-reduced-motion`: a link's
  `.arrow` nudges right, the coral CTA lifts 1 px, Nib in the nav hops (`--ease-spring`), the theme
  icon turns 20°, nav and footer links (`.grow-line`) grow their underline from the left. Curves
  come from the `--ease-*` tokens, never a literal `cubic-bezier`.
- **Theme and language**: toggles in the nav, persisted in localStorage, applied before first
  paint (`data-theme` on `<html>`). Language is remembered; the default follows
  `navigator.language`.

## Performance rules

- No external stylesheet or script requests: fonts self-hosted, no CDN.
- No video; raster images only for the social card (`og.jpg`), which no page loads.
- Fonts: three families, latin subsets, at most two weights each.
- The JS bundle is the MoonBit js build, minified by warren; no second minifier.

## Checking a change

`moon check` (zero warnings), `moon fmt --check`, `moon info`,
`moon test --target js -p PerfectPan/svgo-website/ui` (copy tables have tests: every plugin
and every CLI flag needs a Chinese string), `pnpm app`, then
`node app/website/shots.mjs <dir> [routes]`: full-page screenshots of the built site at
1440 and 390 px, light and dark, English and Chinese, with motion frozen at its end state.
Look at every screenshot of a touched route before calling a change done.
