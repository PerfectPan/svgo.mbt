///|
/// A reference's exact source span excludes '#' and timing suffixes.
priv struct IdReference {
  start : Int
  end : Int
  id : String
}

///|
fn id_references(name : String, value : String) -> Array[IdReference] {
  let refs : Array[IdReference] = []
  fn add(start : Int, end : Int) {
    if end > start {
      refs.push({ start, end, id: decode_id(value[start:end].to_owned()), })
    }
  }
  if name == "href" || name.has_suffix(":href") {
    if value.has_prefix("#") {
      add(1, value.length())
    }
  } else if name == "begin" || name == "end" {
    let mut offset = 0
    for part in value.split(";") {
      let trimmed = part.trim_start()
      let start = offset + part.length() - trimmed.length()
      if trimmed.find(".") is Some(dot) &&
        dot > 0 &&
        !trimmed.get_char(0).unwrap().is_ascii_digit() {
        add(start, start + dot)
      }
      offset += part.length() + 1
    }
  } else if reference_attrs.contains(name) {
    let mut cursor = 0
    while value[cursor:].find("url(") is Some(rel) {
      let mut start = cursor + rel + 4
      while value.get_char(start) is Some(' ' | '\t' | '\n' | '\r') {
        start += 1
      }
      let quote = value.get_char(start)
      if quote is Some('\'' | '"') {
        start += 1
      }
      cursor = start
      if value.get_char(start) != Some('#') {
        continue
      }
      start += 1
      let mut end = start
      while end < value.length() &&
            !(value.get_char(end)
            is Some(')' | '\'' | '"' | ' ' | '\t' | '\n' | '\r')) {
        end += 1
      }
      add(start, end)
      cursor = end
    }
  }
  refs
}

///|
/// Percent-decode an id (`%C3%A9` → `é`). Runs of `%XX` escapes are decoded as
/// UTF-8; other characters pass through. Anything malformed returns `value`
/// unchanged, as the previous general decoder did.
fn decode_id(value : String) -> String {
  if !value.contains("%") {
    return value
  }
  let sb = StringBuilder()
  let bytes : Array[Int] = []
  let cu = value.code_units()
  let mut i = 0
  while i < cu.length() {
    if cu[i] == 37 && i + 2 < cu.length() {
      guard hex_pair(cu[i + 1].to_int(), cu[i + 2].to_int()) is Some(b) else {
        return value
      }
      bytes.push(b)
      i += 3
      continue
    }
    guard flush_utf8(bytes, sb) else { return value }
    let u = cu[i].to_int()
    if u >= 0xD800 && u <= 0xDBFF && i + 1 < cu.length() {
      let lo = cu[i + 1].to_int()
      if lo >= 0xDC00 && lo <= 0xDFFF {
        sb.write_char(
          (0x10000 + ((u - 0xD800) << 10) + (lo - 0xDC00)).unsafe_to_char(),
        )
        i += 2
        continue
      }
    }
    sb.write_char(u.unsafe_to_char())
    i += 1
  }
  guard flush_utf8(bytes, sb) else { return value }
  sb.to_string()
}

///|
fn hex_pair(hi : Int, lo : Int) -> Int? {
  guard hex_digit(hi) is Some(h) && hex_digit(lo) is Some(l) else {
    return None
  }
  Some(h * 16 + l)
}

///|
fn hex_digit(c : Int) -> Int? {
  if c >= 48 && c <= 57 {
    Some(c - 48)
  } else if c >= 97 && c <= 102 {
    Some(c - 87)
  } else if c >= 65 && c <= 70 {
    Some(c - 55)
  } else {
    None
  }
}

///|
/// Decode `bytes` as UTF-8 into `sb` and empty it; false on malformed input.
fn flush_utf8(bytes : Array[Int], sb : StringBuilder) -> Bool {
  let mut i = 0
  while i < bytes.length() {
    let b = bytes[i]
    let (len, init) = if b < 0x80 {
      (1, b)
    } else if b >= 0xC2 && b <= 0xDF {
      (2, b & 0x1F)
    } else if b >= 0xE0 && b <= 0xEF {
      (3, b & 0x0F)
    } else if b >= 0xF0 && b <= 0xF4 {
      (4, b & 0x07)
    } else {
      return false
    }
    guard i + len <= bytes.length() else { return false }
    let mut cp = init
    for k in 1..<len {
      let c = bytes[i + k]
      guard c >= 0x80 && c <= 0xBF else { return false }
      cp = (cp << 6) | (c & 0x3F)
    }
    let min = if len == 2 {
      0x80
    } else if len == 3 {
      0x800
    } else if len == 4 {
      0x10000
    } else {
      0
    }
    guard cp >= min && cp <= 0x10FFFF && !(cp >= 0xD800 && cp <= 0xDFFF) else {
      return false
    }
    sb.write_char(cp.unsafe_to_char())
    i += len
  }
  bytes.clear()
  true
}
