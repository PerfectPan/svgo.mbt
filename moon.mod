// Learn more about moon.mod configuration:
// https://docs.moonbitlang.com/en/latest/toolchain/moon/module.html
//
// To add a dependency, run this command in your terminal:
//   moon add moonbitlang/x
//
// Or manually declare it in `import`, for example:
// import {
//   "moonbitlang/x@0.4.6",
// }

name = "perfectpan/svgo"

version = "0.1.0"

readme = "README.mbt.md"

repository = "https://github.com/PerfectPan/svgo.mbt"

license = "MIT"

keywords = [ "svg", "svgo", "optimizer", "minifier", "wasm", "frontend" ]

preferred_target = "wasm-gc"

description = "SVG optimizer in pure MoonBit: svgo-compatible plugin pipeline with path data optimization, colour and number cleanup, and render-diff verification"
