///|
/// The CLI is a native program; these stubs only exist so the package type
/// checks (and `moon doc` runs) on the other backends.
fn svgo_read_file(_path : Bytes) -> Bytes {
  b""
}

///|
fn svgo_write_file(_path : Bytes, _data : Bytes) -> Int {
  -1
}
