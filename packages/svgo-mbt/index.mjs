// Loader for the wasm-gc build of svgo.mbt. Works in Node >= 22 and in
// browsers with the JS String Builtins proposal (Chrome 130+, Firefox 134+,
// Safari 18.4+).
let instancePromise;

const hostImports = () => ({
  // Transcendentals and the slow path of number parsing come from the host,
  // which keeps their MoonBit implementations out of the wasm.
  Math: {
    sin: Math.sin,
    cos: Math.cos,
    tan: Math.tan,
    asin: Math.asin,
    acos: Math.acos,
    atan: Math.atan,
  },
  Number: { parseFloat: Number.parseFloat },
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

// Strings cross the wasm boundary as length-prefixed tokens, `<length>:<text>`
// with the length in UTF-16 code units; svgo/wasm/wasm.mbt reads and writes
// the same layout. This replaces JSON on both sides of the call.

const token = (s) => `${s.length}:${s}`;

function encodeValue(v) {
  if (v === null || v === undefined) return token("z");
  if (typeof v === "boolean") return token(v ? "b1" : "b0");
  if (typeof v === "number") return Number.isFinite(v) ? token(`n${v}`) : token("z");
  if (typeof v === "string") return token(`s${v}`);
  if (Array.isArray(v)) return token(`a${v.length}`) + v.map(encodeValue).join("");
  const keys = Object.keys(v);
  return token(`o${keys.length}`) + keys.map((k) => token(k) + encodeValue(v[k])).join("");
}

function encodeConfig(options) {
  const params = { ...(options.params ?? {}) };
  let plugins = "";
  if (Array.isArray(options.plugins)) {
    const names = [];
    for (const entry of options.plugins) {
      if (typeof entry === "string") {
        names.push(entry);
      } else if (entry && typeof entry.name === "string") {
        if (entry.params !== undefined) params[entry.name] = entry.params;
        names.push(entry.name);
      }
    }
    plugins = token(String(names.length)) + names.map(token).join("");
  } else {
    plugins = token("");
  }
  const keys = Object.keys(params);
  return (
    token(typeof options.precision === "number" ? String(Math.trunc(options.precision)) : "") +
    token(options.multipass === false ? "0" : "1") +
    token(options.pretty === true ? "1" : "0") +
    plugins +
    token(String(keys.length)) +
    keys.map((k) => token(k) + encodeValue(params[k])).join("")
  );
}

function* tokens(s) {
  let i = 0;
  while (i < s.length) {
    const colon = s.indexOf(":", i);
    const length = Number(s.slice(i, colon));
    yield s.slice(colon + 1, colon + 1 + length);
    i = colon + 1 + length;
  }
}

/**
 * Optimize an SVG string. Options: { plugins?: (string | {name: string, params?: object})[],
 * params?: Record<string, object>, precision?: number,
 * multipass?: boolean, pretty?: boolean }. Returns { data, originalSize, size, passes, applied }.
 */
export async function optimize(svg, options = {}) {
  const exports = await init();
  const it = tokens(exports.optimize(svg, encodeConfig(options)));
  const status = it.next().value;
  if (status !== "ok") throw new Error(it.next().value);
  const originalSize = Number(it.next().value);
  const size = Number(it.next().value);
  const passes = Number(it.next().value);
  const applied = [];
  for (let n = Number(it.next().value); n > 0; n--) applied.push(it.next().value);
  const data = it.next().value;
  return { data, originalSize, size, passes, applied };
}

/** List available plugins: [{ name, description, enabled }]. */
export async function plugins() {
  const exports = await init();
  const it = tokens(exports.plugins());
  const out = [];
  for (let n = Number(it.next().value); n > 0; n--) {
    const name = it.next().value;
    const description = it.next().value;
    const enabled = it.next().value === "1";
    out.push({ name, description, enabled });
  }
  return out;
}
