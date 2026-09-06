///|
#borrow(path)
extern "C" fn svgo_read_file(path : Bytes) -> Bytes = "svgo_read_file"

///|
#borrow(path, data)
extern "C" fn svgo_write_file(path : Bytes, data : Bytes) -> Int = "svgo_write_file"
