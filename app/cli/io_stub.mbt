///|
/// The CLI is a native/js program; these stubs only exist so the package type
/// checks (and `moon doc` runs) on the wasm backends.
fn svgo_read_file(_path : String) -> Bytes {
  b""
}

///|
fn svgo_write_file(_path : String, _data : Bytes) -> Int {
  -1
}

///|
fn svgo_read_stdin() -> Bytes {
  b""
}

///|
fn svgo_stdin_is_tty() -> Bool {
  true
}

///|
fn svgo_exit(_code : Int) -> Unit {

}

///|
fn svgo_eprint(_s : String) -> Unit {

}

///|
fn svgo_eprintln(_s : String) -> Unit {

}

///|
fn svgo_is_dir(_path : String) -> Bool {
  false
}

///|
fn svgo_list_dir(_path : String) -> String {
  ""
}

///|
fn svgo_mkdir_p(_path : String) -> Int {
  -1
}

///|
fn svgo_args() -> Array[String] {
  []
}
