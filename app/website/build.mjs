// Build the site into _build/app:
//   1. Tailwind: src/style.css -> public/style.css
//   2. gen.mjs: data / samples / API docs -> ui/*.mbt
//   3. warren build: MoonBit (js backend) -> dist, with public/ copied along
// Usage: scripts/build-wasm.sh && pnpm run docs && node app/website/build.mjs   (pnpm install once)
import { spawnSync } from "node:child_process";
import { cpSync, rmSync, writeFileSync } from "node:fs";
import { delimiter, join } from "node:path";

const ROOT = new URL("../..", import.meta.url).pathname;
const APP = join(ROOT, "app/website");
const OUT = join(ROOT, "_build/app");
const run = (cmd, args, opts = {}) => {
  const r = spawnSync(cmd, args, { stdio: "inherit", cwd: APP, ...opts });
  if (r.status !== 0) { console.error(`${cmd} ${args.join(" ")} failed`); process.exit(r.status ?? 1); }
};

run(join(APP, "node_modules/.bin/tailwindcss"), ["-i", "src/style.css", "-o", "public/style.css", "--minify"]);
run(process.execPath, [join(APP, "gen.mjs")]);
// warren minifies with `terser` from PATH and otherwise tries `npm exec terser`.
// Put the app's own terser first: the Node.js that CI installs through pnpm
// ships without npm, and warren would then skip minification silently.
const PATH = [join(APP, "node_modules/.bin"), process.env.PATH].join(delimiter);
run("warren", ["build", "--browser-entry", "main", "--server-entry", "", "--dist", "dist"], {
  env: { ...process.env, PATH },
});
rmSync(OUT, { recursive: true, force: true });
cpSync(join(APP, "dist"), OUT, { recursive: true });
// The bundle compiles in third-party code; ship its notices with the site.
for (const f of ["LICENSE", "THIRD_PARTY_NOTICES.md"]) cpSync(join(ROOT, f), join(OUT, f));
writeFileSync(join(OUT, ".nojekyll"), "");
console.log(`site: ${OUT}`);
