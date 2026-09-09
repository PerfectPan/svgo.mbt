///|
#borrow(path)
extern "C" fn c_svgo_read_file(path : Bytes) -> Bytes = "svgo_read_file"

///|
#borrow(path, data)
extern "C" fn c_svgo_write_file(path : Bytes, data : Bytes) -> Int = "svgo_write_file"

///|
extern "C" fn c_svgo_read_stdin() -> Bytes = "svgo_read_stdin"

///|
extern "C" fn c_svgo_stdin_is_tty() -> Int = "svgo_stdin_is_tty"

///|
extern "C" fn c_svgo_exit(code : Int) -> Unit = "svgo_exit"

///|
#borrow(s)
extern "C" fn c_svgo_eprint(s : Bytes) -> Unit = "svgo_eprint"

///|
#borrow(path)
extern "C" fn c_svgo_is_dir(path : Bytes) -> Int = "svgo_is_dir"

///|
#borrow(path)
extern "C" fn c_svgo_list_dir(path : Bytes) -> Bytes = "svgo_list_dir"

///|
#borrow(path)
extern "C" fn c_svgo_mkdir_p(path : Bytes) -> Int = "svgo_mkdir_p"

///|
fn cstr(s : String) -> Bytes {
  let buf = Buffer()
  buf.write_bytes(@utf8.encode(s))
  buf.write_byte(b'\x00')
  buf.contents()
}

///|
/// Read a whole file into a byte buffer. Returns an empty buffer on failure.
fn svgo_read_file(path : String) -> Bytes {
  c_svgo_read_file(cstr(path))
}

///|
/// Write a byte buffer to a file. Returns 0 on success, non-zero on failure.
fn svgo_write_file(path : String, data : Bytes) -> Int {
  c_svgo_write_file(cstr(path), data)
}

///|
/// Read the entire standard input into a byte buffer.
fn svgo_read_stdin() -> Bytes {
  c_svgo_read_stdin()
}

///|
/// Returns true if standard input is connected to a terminal.
fn svgo_stdin_is_tty() -> Bool {
  c_svgo_stdin_is_tty() != 0
}

///|
/// Exit the process with the given status code.
fn svgo_exit(code : Int) -> Unit {
  c_svgo_exit(code)
}

///|
/// Print a string to standard error (no trailing newline).
fn svgo_eprint(s : String) -> Unit {
  c_svgo_eprint(@utf8.encode(s))
}

///|
/// Print a string to standard error followed by a newline.
fn svgo_eprintln(s : String) -> Unit {
  svgo_eprint(s + "\n")
}

///|
/// Returns true if the path is a directory.
fn svgo_is_dir(path : String) -> Bool {
  c_svgo_is_dir(cstr(path)) != 0
}

///|
/// List the entries of a directory, one per line. Returns an empty string on
/// failure. Entries are sorted by name.
fn svgo_list_dir(path : String) -> String {
  @utf8.decode_lossy(c_svgo_list_dir(cstr(path))[:])
}

///|
/// Create a directory and all its parents. Returns 0 on success, non-zero on
/// failure.
fn svgo_mkdir_p(path : String) -> Int {
  c_svgo_mkdir_p(cstr(path))
}
