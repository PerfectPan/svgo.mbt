# Fonts

Self-hosted so the site renders without a request to fonts.googleapis.com,
which blocks first paint and is slow or unreachable from some networks. The
files are the woff2 subsets Google Fonts serves; `../../src/fonts.css` holds
the matching `@font-face` rules with `font-display: swap`.

| family | weights | license |
| --- | --- | --- |
| Inter (Rasmus Andersson) | 400, 500, 600, 700 | SIL Open Font License 1.1, https://github.com/rsms/inter |
| Space Grotesk (Florian Karsten) | 500, 700 | SIL Open Font License 1.1, https://github.com/floriankarsten/space-grotesk |
| JetBrains Mono (JetBrains) | 400, 500 | SIL Open Font License 1.1, https://github.com/JetBrains/JetBrainsMono |

The OFL permits redistribution of the font software as is; the fonts are not
sold and are not modified beyond Google's subsetting.
