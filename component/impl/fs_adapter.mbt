///| WasmFs - WIT filesystem import adapter for @bit.FileSystem and @bit.RepoFileSystem

///|
pub struct WasmFs {
  priv _dummy : Int
}

///|
pub fn WasmFs::new() -> WasmFs {
  { _dummy: 0 }
}

///|
fn unwrap_result(r : Result[Unit, String]) -> Unit raise @bit.GitError {
  match r {
    Ok(_) => ()
    Err(e) => raise @bit.GitError::IoError(e)
  }
}

///|
pub impl @bit.FileSystem for WasmFs with mkdir_p(_self, path) {
  unwrap_result(@wit_fs.mkdir_p(path))
}

///|
pub impl @bit.FileSystem for WasmFs with write_file(_self, path, content) {
  let arr : Array[Byte] = Array::new(capacity=content.length())
  for i in 0..<content.length() {
    arr.push(content[i])
  }
  unwrap_result(@wit_fs.write_file(path, arr))
}

///|
pub impl @bit.FileSystem for WasmFs with write_string(_self, path, content) {
  unwrap_result(@wit_fs.write_string(path, content))
}

///|
pub impl @bit.FileSystem for WasmFs with remove_file(_self, path) {
  unwrap_result(@wit_fs.remove_file(path))
}

///|
pub impl @bit.FileSystem for WasmFs with remove_dir(_self, path) {
  unwrap_result(@wit_fs.remove_dir(path))
}

///|
pub impl @bit.RepoFileSystem for WasmFs with read_file(_self, path) {
  match @wit_fs.read_file(path) {
    Ok(arr) => Bytes::from_array(arr)
    Err(e) => raise @bit.GitError::IoError(e)
  }
}

///|
pub impl @bit.RepoFileSystem for WasmFs with readdir(_self, path) {
  match @wit_fs.readdir(path) {
    Ok(arr) => arr
    Err(e) => raise @bit.GitError::IoError(e)
  }
}

///|
pub impl @bit.RepoFileSystem for WasmFs with is_dir(_self, path) {
  @wit_fs.is_dir(path)
}

///|
pub impl @bit.RepoFileSystem for WasmFs with is_file(_self, path) {
  @wit_fs.is_file(path)
}
