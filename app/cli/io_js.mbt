///|
/// Node.js file I/O bindings for the js backend. MoonBit `String` is a JS
/// string and `Bytes` is a `Uint8Array`, so we hand them straight to `fs`.
/// `require` is provided by the `createRequire` shim prepended by build-cli.sh.
extern "js" fn node_read_file(path : String) -> Bytes =
  #|(path) => {
  #|  const fs = require("fs");
  #|  return new Uint8Array(fs.readFileSync(path));
  #|}

///|
extern "js" fn node_write_file(path : String, data : Bytes) -> Int =
  #|(path, data) => {
  #|  const fs = require("fs");
  #|  try { fs.writeFileSync(path, Buffer.from(data)); return 0; } catch (e) { return -1; }
  #|}

///|
extern "js" fn node_read_stdin() -> Bytes =
  #|() => {
  #|  const fs = require("fs");
  #|  return new Uint8Array(fs.readFileSync(0));
  #|}

///|
extern "js" fn node_stdin_is_tty() -> Bool =
  #|() => !!process.stdin.isTTY

///|
extern "js" fn node_exit(code : Int) -> Unit =
  #|(code) => process.exit(code)

///|
extern "js" fn node_eprint(s : String) -> Unit =
  #|(s) => process.stderr.write(s)

///|
extern "js" fn node_is_dir(path : String) -> Bool =
  #|(path) => {
  #|  const fs = require("fs");
  #|  try { return fs.statSync(path).isDirectory(); } catch (e) { return false; }
  #|}

///|
extern "js" fn node_list_dir(path : String) -> String =
  #|(path) => {
  #|  const fs = require("fs");
  #|  try { return fs.readdirSync(path).sort().join("\n"); } catch (e) { return ""; }
  #|}

///|
extern "js" fn node_mkdir_p(path : String) -> Int =
  #|(path) => {
  #|  const fs = require("fs");
  #|  try { fs.mkdirSync(path, { recursive: true }); return 0; } catch (e) { return -1; }
  #|}

///|
/// Read a whole file into a byte buffer. Returns an empty buffer on failure.
fn svgo_read_file(path : String) -> Bytes {
  node_read_file(path)
}

///|
/// Write a byte buffer to a file. Returns 0 on success, non-zero on failure.
fn svgo_write_file(path : String, data : Bytes) -> Int {
  node_write_file(path, data)
}

///|
/// Read the entire standard input into a byte buffer.
fn svgo_read_stdin() -> Bytes {
  node_read_stdin()
}

///|
/// Returns true if standard input is connected to a terminal.
fn svgo_stdin_is_tty() -> Bool {
  node_stdin_is_tty()
}

///|
/// Exit the process with the given status code.
fn svgo_exit(code : Int) -> Unit {
  node_exit(code)
}

///|
/// Print a string to standard error (no trailing newline).
fn svgo_eprint(s : String) -> Unit {
  node_eprint(s)
}

///|
/// Print a string to standard error followed by a newline.
fn svgo_eprintln(s : String) -> Unit {
  svgo_eprint(s + "\n")
}

///|
/// Returns true if the path is a directory.
fn svgo_is_dir(path : String) -> Bool {
  node_is_dir(path)
}

///|
/// List the entries of a directory, one per line. Returns an empty string on
/// failure. Entries are sorted by name.
fn svgo_list_dir(path : String) -> String {
  node_list_dir(path)
}

///|
/// Create a directory and all its parents. Returns 0 on success, non-zero on
/// failure.
fn svgo_mkdir_p(path : String) -> Int {
  node_mkdir_p(path)
}
