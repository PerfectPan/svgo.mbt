# Fonts

Self-hosted so the site renders without a request to fonts.googleapis.com,
which blocks first paint and is slow or unreachable from some networks. The
files are the woff2 subsets Google Fonts serves; `../../src/fonts.css` holds
the matching `@font-face` rules with `font-display: swap`.

| family | weights | license |
| --- | --- | --- |
| Space Grotesk (Florian Karsten) | 400, 500 | SIL Open Font License 1.1, https://github.com/floriankarsten/space-grotesk |
| Fraunces (Un-Type) | 500, 600 | SIL Open Font License 1.1, https://github.com/undercase-type/Fraunces |
| JetBrains Mono (JetBrains) | 400, 500 | SIL Open Font License 1.1, https://github.com/JetBrains/JetBrainsMono |

Space Grotesk and Fraunces are subset to latin and latin-ext only (Chinese
falls back to system serif/sans fonts, see `../../src/fonts.css`).

The OFL permits redistribution of the font software as is; the fonts are not
sold and are not modified beyond Google's subsetting.
