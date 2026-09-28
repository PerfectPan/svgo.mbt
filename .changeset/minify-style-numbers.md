---
"@rivus/svgo": patch
---

minifyStyles now packs numbers in `style` attributes and `<style>` rules the way svgo's csso does (`6.000000` → `6`, `0.450000` → `.45`, `0.0px` → `0`), so Inkscape-style exports come out as small as with svgo.
