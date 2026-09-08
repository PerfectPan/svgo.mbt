// Loader for the wasm-gc build of svgo.mbt. Works in Node >= 22 and in
// browsers with the JS String Builtins proposal (Chrome 130+, Firefox 134+,
// Safari 18.4+).
let instancePromise;

const hostImports = () => ({
  // `println` and friends are never called by the optimizer, but the module
  // declares the imports; provide inert implementations.
  spectest: {
    print_char: () => {},
  },
  __moonbit_fs_unstable: new Proxy({}, { get: () => () => 0 }),
  __moonbit_time_unstable: new Proxy({}, { get: () => () => 0 }),
  __moonbit_rand_unstable: new Proxy({}, { get: () => () => 0 }),
  __moonbit_io_unstable: new Proxy({}, { get: () => () => 0 }),
  __moonbit_sys_unstable: new Proxy({}, { get: () => () => 0 }),
});

async function loadBytes(url) {
  if (typeof fetch === "function" && !url.startsWith("file:")) {
    const res = await fetch(url);
    return new Uint8Array(await res.arrayBuffer());
  }
  const { readFile } = await import("node:fs/promises");
  const { fileURLToPath } = await import("node:url");
  return readFile(fileURLToPath(url));
}

/** Instantiate the module once. `wasmUrl` defaults to svgo.wasm next to this file. */
export async function init(wasmUrl = new URL("./svgo.wasm", import.meta.url)) {
  if (!instancePromise) {
    instancePromise = (async () => {
      const bytes = await loadBytes(wasmUrl.toString());
      const { instance } = await WebAssembly.instantiate(bytes, hostImports(), {
        builtins: ["js-string"],
        importedStringConstants: "_",
      });
      return instance.exports;
    })();
  }
  return instancePromise;
}

/**
 * Optimize an SVG string. Options: { plugins?: (string | {name: string, params?: object})[],
 * params?: Record<string, object>, precision?: number,
 * multipass?: boolean, pretty?: boolean }. Returns { data, originalSize, size, passes, applied }.
 */
export async function optimize(svg, options = {}) {
  const exports = await init();
  const result = JSON.parse(exports.optimize(svg, JSON.stringify(options)));
  if (result.error) throw new Error(result.error);
  return result;
}

/** List available plugins: [{ name, description, enabled }]. */
export async function plugins() {
  const exports = await init();
  return JSON.parse(exports.plugins());
}
