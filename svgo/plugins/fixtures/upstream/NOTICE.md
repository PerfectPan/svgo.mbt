# Upstream fixtures

These files are svgo's own plugin test cases, copied verbatim from
https://github.com/svg/svgo (`test/plugins/*.svg.txt`, commit
e4cb29bebcc9820ac979dfc05106b512cc5de986, 2026-08-27) for every plugin in
svgo's preset-default. svgo is MIT licensed, Copyright (c) Kir Belevich;
the license text is in [`THIRD_PARTY_NOTICES.md`](../../../THIRD_PARTY_NOTICES.md).

Format: an optional description, `===`, then `input @@@ expected [@@@ params]`.
`scripts/gen-fixtures.py` turns them into `fixtures_test.mbt`, following
svgo's own runner: one plugin, run twice, both results must equal `expected`
(whitespace between tags ignored). Any plugin listed in the generator's
`NOT_IMPLEMENTED` table (currently empty) would be generated as skipped tests,
and any case listed in `KNOWN_FAILURES.txt` (currently empty) as an expected
failure so a fix must also remove the line.

Only preset-default plugins are imported. svgo's 17 opt-in plugins (88 further
cases) are left out: svgo does not run them by default and svgo.mbt has no
plans for most of them.
