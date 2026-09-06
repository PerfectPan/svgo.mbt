// Dev server: warren (MoonBit rebuild + live reload) alongside tailwind --watch.
// Usage: pnpm dev   → http://localhost:4173/
import { spawn } from "node:child_process";
import { join } from "node:path";

const APP = new URL(".", import.meta.url).pathname;
const PORT = process.env.PORT || "4173";
spawn(process.execPath, [join(APP, "gen.mjs")], { stdio: "inherit", cwd: APP }).on("exit", () => {
  const tw = spawn(join(APP, "node_modules/.bin/tailwindcss"), ["-i", "src/style.css", "-o", "public/style.css", "--watch"], { stdio: "inherit", cwd: APP });
  const warren = spawn("warren", ["dev", "--browser-entry", "main", "--direct", "--port", PORT], { stdio: "inherit", cwd: APP });
  const stop = () => { tw.kill(); warren.kill(); process.exit(0); };
  process.on("SIGINT", stop);
  process.on("SIGTERM", stop);
  warren.on("exit", stop);
});
