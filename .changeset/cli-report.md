---
"@rivus/svgo": minor
---

CLI: writing files with `-o` now prints a size report on stderr by default: aligned rows with human units (`836 B → 276 B  −67%`), a totals line with the elapsed time for several files, and for a single file the plugins that changed it. With the SVG on stdout the report stays opt-in (`--stats`); `-q` silences it and `--json` is unchanged. A failed file gets one line, `svgo-mbt: path: message`, plus a `failed` row and a count in the totals. `--list` groups plugins under `preset-default` and `optional`, `--bench` prints per-run timing with sub-millisecond resolution, and `-h` carries the version, the real command name `svgo-mbt` and one exit status per line. Colour appears only on a terminal: `NO_COLOR` turns it off, `FORCE_COLOR` turns it on for pipes, and stdout is never styled.
