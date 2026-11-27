# Native binaries

The CLI (`app/cli/`) is a MoonBit executable that imports `PerfectPan/svgo`.
On the `native` target MoonBit compiles it to C and links it with the system C
compiler, producing a single statically-linked binary with no runtime
dependencies. This document describes how that binary is built and distributed.

## Why native binaries

The wasm-gc build (shipped via npm as `@rivus/svgo`) is the primary delivery form
for JavaScript users. The native binary exists for two reasons:

- **Startup speed.** End to end on a small icon the native binary takes about
  10 ms, the Node build about 50 ms and the svgo CLI about 160 ms
  (`scripts/cli-bench.sh`); most of the difference is Node starting up. For a
  CLI invoked many times in a build pipeline this matters.
- **No Node required.** CI images and minimal containers often don't ship
  Node; a single binary is easier to drop in.

## Build

```
moon build --target native --release -q
$(scripts/bin-path.sh) input.svg
```

`scripts/bin-path.sh` prints the path of the `svgo-cli.exe` under
`_build/native/release/build/`. The exact layout has changed between MoonBit
releases, so the script looks it up rather than hard-coding it.

The native backend emits C and compiles it with the system C compiler (`cc`).
Set `CC` to override the compiler, e.g. to use a musl cross-compiler for a
fully static Linux binary:

```
CC=x86_64-linux-musl-gcc moon build --target native --release
```

### Platforms

| OS | arch | notes |
| --- | --- | --- |
| Linux | x86_64 | build with `x86_64-linux-musl-gcc` for a static binary |
| Linux | arm64 | `aarch64-linux-musl-gcc` |
| macOS | x86_64 | native build on an Intel runner |
| macOS | arm64 | native build on an Apple Silicon runner |
| Windows | x86_64 | `x86_64-w64-mingw32-gcc` or native MSVC |

MoonBit does not expose a `--target-arch` flag; the architecture follows the
host toolchain. To produce binaries for all platforms from one CI run, use a
matrix of runners (simplest) or install cross-compilers on a Linux host.

## Distribution

### GitHub releases (primary)

When a release pull request lands, `release.yml` publishes the npm package
(OIDC trusted publishing, provenance attached) and tags the commit
`@rivus/svgo@X.Y.Z`. That tag runs `binaries.yml`: the binary is built on
linux-x86_64, linux-arm64 and macos-arm64 runners and attached to a GitHub
release, and the MoonBit module is published to mooncakes (needs the
`MOONCAKES_TOKEN` secret). Both workflows have a `workflow_dispatch` dry run.
Asset naming:

```
svgo-mbt-X.Y.Z-linux-x86_64.tar.gz
svgo-mbt-X.Y.Z-linux-arm64.tar.gz
svgo-mbt-X.Y.Z-macos-arm64.tar.gz
```

Each archive holds a `svgo-mbt/` directory with the `svgo-mbt` executable,
`LICENSE`, `THIRD_PARTY_NOTICES.md` and the npm package's `README.md`. macOS
x86_64 and Windows are not built (no runner in the matrix); build from source
with `moon build --target native --release` there. The binary is named
`svgo-mbt` to avoid colliding with the original `svgo` CLI; the npm bin entry
uses the same name.

## Versioning

`packages/svgo-mbt/package.json` is the single version source. Running
`pnpm version-packages` (in the release PR opened by `release.yml`) runs
`scripts/sync-version.mjs` to copy that version into `svgo/moon.mod`,
`app/website/moon.mod`, `app/cli/moon.mod`, `app/cli/main.mbt` (`const VERSION`),
and `svgo/wasm/wasm.mbt` (`version()`). `scripts/verify.sh` checks that all
six stay in sync, and `binaries.yml` builds from the published `@rivus/svgo@X.Y.Z`
tag and reads the version from the compiled binary's `--version` output.

## CI

- `.github/workflows/ci.yml` builds and smoke-tests the native binary on
  `ubuntu-latest` and `macos-latest` on every push and pull request.
- `.github/workflows/release.yml` opens the Changesets release PR on pushes to
  `main`, publishes `@rivus/svgo` to npm via OIDC Trusted Publishing when that
  PR merges, and dispatches `binaries.yml` at the published `@rivus/svgo@X.Y.Z` tag.
- `.github/workflows/binaries.yml` builds the Linux x86_64, Linux arm64, and
  macOS arm64 release archives, attaches them to the GitHub release, and
  publishes `PerfectPan/svgo` to mooncakes.

## What is deliberately not here

- **Static linking on macOS.** Apple does not support fully static binaries;
  the macOS build links system libraries dynamically. This is fine because
  the binary only uses libc.
- **Alpine/musl by default.** The default Linux build links against glibc;
  a musl build is available via `CC=x86_64-linux-musl-gcc` for users who need
  it.
- **Installer scripts or OS package managers.** No `install.sh`, Homebrew tap,
  Scoop bucket, or npm `optionalDependencies` native binary wrapper is maintained;
  users download the GitHub release archive or install `@rivus/svgo` from npm.
- **Code signing / notarization.** Not planned; macOS Gatekeeper may show an
  unidentified developer warning that users can bypass.
