---
"@rivus/svgo": minor
---

MoonBit library: `Config::custom` runs your own `@plugins.Plugin` values next to the built-in ones. A name in `Config::plugins` resolves to a custom plugin first, so a custom plugin can run at any position or replace a built-in; custom plugins no name refers to run last. Parameters, multipass and `applied` treat them like built-ins, and `Context::param_bool`, `param_int`, `param_string`, `param_strings` and `has_param` are now public for reading parameters. Code that builds a `Config` with a full record literal needs the new field (`..Config::default()` covers it). The npm package runs only the built-in plugins.
