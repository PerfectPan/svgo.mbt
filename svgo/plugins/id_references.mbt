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
fn decode_id(value : String) -> String {
  if !value.contains("%") {
    return value
  }
  let bytes = Buffer()
  let mut cursor = 0
  while cursor < value.length() {
    if value.get_char(cursor) == Some('%') && cursor + 2 < value.length() {
      let n = @string.parse_int(
        value[cursor + 1:cursor + 3].to_owned(),
        base=16,
      ) catch {
        _ => return value
      }
      bytes.write_byte(n.to_byte())
      cursor += 3
    } else {
      let c = value.get_char(cursor).unwrap()
      bytes.write_bytes(@utf8.encode(c.to_string()))
      cursor += c.to_string().length()
    }
  }
  @utf8.decode(bytes.contents()) catch {
    _ => value
  }
}
