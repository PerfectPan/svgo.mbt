---
"@rivus/svgo": patch
---

Support the MoonBit v1.0.0-rc1 toolchain without deprecation warnings by migrating `Set::add` calls to `Set::insert` and `Buffer::write_bytes` to `Buffer::write_bytesview`; optimized SVG output is unchanged.
