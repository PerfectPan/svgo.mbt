# Upstream fixtures

These files are svgo's own plugin test cases, copied verbatim from
https://github.com/svg/svgo (`test/plugins/*.svg.txt`, commit
e4cb29bebcc9820ac979dfc05106b512cc5de986, 2026-08-27) for the plugins svgo.mbt
implements. svgo is MIT licensed, Copyright (c) Kir Belevich.

Format: an optional description, `===`, then `input @@@ expected [@@@ params]`.
`scripts/gen-fixtures.py` turns them into `fixtures_test.mbt`, following
svgo's own runner: one plugin, run twice, both results must equal `expected`
(whitespace between tags ignored). Cases needing plugin params we do not
support are generated as skipped tests; cases we do not pass yet are listed in
`KNOWN_FAILURES.txt` and generated as expected failures, so a fix must also
remove the line (the list only shrinks).
