///| WasmHttpClient - WIT HTTP import adapter for @bit.HttpClient

///|
pub struct WasmHttpClient {
  priv _dummy : Int
}

///|
pub fn WasmHttpClient::new() -> WasmHttpClient {
  { _dummy: 0 }
}

///|
fn map_to_header_pairs(
  headers : Map[String, String],
) -> Array[(String, String)] {
  let pairs : Array[(String, String)] = []
  for item in headers.to_array() {
    let (k, v) = item
    pairs.push((k, v))
  }
  pairs
}

///|
fn header_pairs_to_map(pairs : Array[(String, String)]) -> Map[String, String] {
  let map : Map[String, String] = {}
  for pair in pairs {
    let (k, v) = pair
    map[k] = v
  }
  map
}

///|
pub impl @bit.HttpClient for WasmHttpClient with get(_self, url, headers) {
  let header_pairs = map_to_header_pairs(headers)
  match @wit_http.http_get(url, header_pairs) {
    Ok((resp, body)) => {
      let response = @bit.HttpResponse::with_headers(
        resp.code,
        header_pairs_to_map(resp.headers),
      )
      (response, Bytes::from_array(body))
    }
    Err(e) => raise @bit.GitError::IoError(e)
  }
}

///|
pub impl @bit.HttpClient for WasmHttpClient with post(_self, url, body, headers) {
  let header_pairs = map_to_header_pairs(headers)
  let body_arr : Array[Byte] = Array::new(capacity=body.length())
  for i in 0..<body.length() {
    body_arr.push(body[i])
  }
  match @wit_http.http_post(url, body_arr, header_pairs) {
    Ok((resp, resp_body)) => {
      let response = @bit.HttpResponse::with_headers(
        resp.code,
        header_pairs_to_map(resp.headers),
      )
      (response, Bytes::from_array(resp_body))
    }
    Err(e) => raise @bit.GitError::IoError(e)
  }
}
