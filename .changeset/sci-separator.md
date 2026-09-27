---
"@rivus/svgo": patch
---

Path data: a number written in scientific notation (`1e-5`, chosen when it is shorter, typically at precision 5 and above) is now separated from a preceding fractional number. It used to be glued on (`.03127e-5` for `.0312 7e-5`), which changed the geometry or, when it broke parsing, dropped the rest of the path.
