# Security Policy

## Reporting a Vulnerability

Do not report vulnerabilities by opening a public issue if the report includes secrets, exploit details, private infrastructure, or user-specific data.

For private reports, contact the repository owner directly through GitHub or use the repository security advisory flow if it is enabled.

svgo.mbt parses untrusted SVG input. Reports of inputs that make the optimizer hang, exhaust memory, crash the native CLI, or produce output that renders content the input did not contain are in scope.

Please include:

- affected version (`@rivus/svgo` or `PerfectPan/svgo` version, `svgo-mbt --version`, or commit)
- how it runs: MoonBit library backend (native, js, wasm-gc), the npm package under Node, Bun, or Deno, or the native CLI, plus the operating system
- reproduction steps and a minimal SVG input
- expected behavior
- actual behavior
- impact assessment

## Sensitive Data

Do not include tokens, private keys, local credentials, internal hostnames, or personal filesystem paths in issues, pull requests, commits, logs, screenshots, or test fixtures.
