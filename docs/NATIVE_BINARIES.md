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
svgo-mbt-X.Y.Z-macos-x86_64.tar.gz
svgo-mbt-X.Y.Z-macos-arm64.tar.gz
svgo-mbt-X.Y.Z-windows-x86_64.zip
```

Each archive contains a single `svgo-mbt` executable (or `svgo-mbt.exe` on
Windows). The binary is named `svgo-mbt` to avoid colliding with the original
`svgo` CLI; the npm bin entry uses the same name.

### Installer script

A `scripts/install.sh` (published to the release and served from the repo)
detects the OS and arch, downloads the matching archive, and installs the
binary to `/usr/local/bin` (or `$HOME/.local/bin`):

```
curl -fsSL https://raw.githubusercontent.com/PerfectPan/svgo.mbt/main/scripts/install.sh | sh
```

### Package managers (future)

- **Homebrew** (macOS/Linux): a tap formula that downloads the release tarball.
- **Scoop** (Windows): a manifest in a scoop bucket.
- **npm**: the `@rivus/svgo` package already ships a JS CLI (`cli.mjs`); the
  native binary could be an optional dependency via `optionalDependencies`
  keyed on `os`/`cpu`, but that adds complexity and is not planned.

## Versioning

The CLI's `VERSION` constant (`app/cli/main.mbt`) and the npm package version
both track the git tag. The release workflow reads the tag and passes it to
the build so the binary reports the right version with `--version`.

## CI

The existing `ci.yml` workflow builds the native binary on `ubuntu-latest` and
`macos-latest` as part of `scripts/verify.sh`. A separate `release.yml`
workflow (to be added) runs only on tags and produces the multi-platform
release assets.

## What is deliberately not here

- **Static linking on macOS.** Apple does not support fully static binaries;
  the macOS build links system libraries dynamically. This is fine because
  the binary only uses libc.
- **Alpine/musl by default.** The default Linux build links against glibc;
  a musl build is available via `CC=x86_64-linux-musl-gcc` for users who need
  it.
- **Code signing / notarization.** Not planned for the initial release; macOS
  will show a "unidentified developer" warning that users can bypass.
