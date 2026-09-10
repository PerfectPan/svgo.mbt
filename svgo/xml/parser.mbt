///|
/// Malformed input; carries a message and the code unit offset where
/// parsing stopped.
pub suberror ParseError {
  ParseError(String, Int)
} derive(Debug)

///|
pub impl Show for ParseError with fn output(self, logger) {
  match self {
    ParseError(msg, pos) => logger.write_string("\{msg} at offset \{pos}")
  }
}

///|
/// Elements whose text content is significant and must be kept verbatim.
let text_elements : Array[String] = [
  "text", "tspan", "textPath", "tref", "style", "script", "title", "desc", "pre",
]

///|
priv struct Parser {
  text : String
  src : ArrayView[UInt16]
  mut pos : Int
}

///|
fn Parser::peek(self : Parser, offset? : Int = 0) -> Int {
  let i = self.pos + offset
  if i < self.src.length() {
    self.src[i].to_int()
  } else {
    -1
  }
}

///|
fn Parser::eof(self : Parser) -> Bool {
  self.pos >= self.src.length()
}

///|
fn Parser::starts_with(self : Parser, s : String) -> Bool {
  let cu = s.code_units()
  if self.pos + cu.length() > self.src.length() {
    return false
  }
  for i in 0..<cu.length() {
    if self.src[self.pos + i] != cu[i] {
      return false
    }
  }
  true
}

///|
fn Parser::slice(self : Parser, start : Int, end : Int) -> String {
  self.text[start:end].to_owned()
}

///|
fn is_space(c : Int) -> Bool {
  c == 32 || c == 9 || c == 10 || c == 13
}

///|
fn is_name_start(c : Int) -> Bool {
  (c >= 97 && c <= 122) ||
  (c >= 65 && c <= 90) ||
  c == 95 ||
  c == 58 ||
  c >= 128
}

///|
fn is_name_char(c : Int) -> Bool {
  is_name_start(c) || (c >= 48 && c <= 57) || c == 45 || c == 46
}

///|
fn Parser::skip_space(self : Parser) -> Unit {
  while is_space(self.peek()) {
    self.pos += 1
  }
}

///|
fn Parser::error(self : Parser, msg : String) -> ParseError {
  ParseError(msg, self.pos)
}

///|
/// Read until the delimiter `until` and return the text before it, leaving
/// the position after the delimiter.
fn Parser::read_until(self : Parser, until : String) -> String raise ParseError {
  let start = self.pos
  while !self.eof() {
    if self.starts_with(until) {
      let s = self.slice(start, self.pos)
      self.pos += until.length()
      return s
    }
    self.pos += 1
  }
  raise self.error("expected '\{until}'")
}

///|
fn Parser::name(self : Parser) -> String raise ParseError {
  let start = self.pos
  guard is_name_start(self.peek()) else { raise self.error("expected a name") }
  while is_name_char(self.peek()) {
    self.pos += 1
  }
  self.slice(start, self.pos)
}

///|
/// Parse an SVG/XML document.
pub fn parse(source : String) -> Document raise ParseError {
  let p : Parser = { text: source, src: source.code_units(), pos: 0, }
  // skip BOM
  if p.peek() == 0xFEFF {
    p.pos += 1
  }
  let children : Array[Node] = []
  p.parse_children(children, None, keep_space=false)
  guard p.eof() else { raise p.error("unexpected content after root element") }
  let roots = children.iter().filter(c => c is Element(_)).count()
  guard roots == 1 else {
    raise ParseError("document must have exactly one root element", 0)
  }
  { children, }
}

///|
/// Parse a sequence of nodes into `out`, stopping at `</` (when `parent` is
/// given) or at end of input.
fn Parser::parse_children(
  self : Parser,
  out : Array[Node],
  parent : String?,
  keep_space~ : Bool,
) -> Unit raise ParseError {
  while !self.eof() {
    if self.peek() != 60 {
      // text run up to the next markup
      let start = self.pos
      while !self.eof() && self.peek() != 60 {
        self.pos += 1
      }
      let raw = self.slice(start, self.pos)
      if keep_space {
        if parent == Some("style") {
          // In svgo/sax, whitespace-only text tokens adjacent to CDATA or tags in <style> are discarded
          // if they are just indentation/newlines, but meaningful text is preserved.
          // Entity decoding is still applied: CSS may legitimately contain `&gt;` etc.
          // written for XML, which must be decoded before the CSS parser sees them.
          if !raw.is_blank() {
            out.push(Text(decode_entities(raw.trim().to_owned())))
          }
        } else {
          out.push(Text(decode_entities(raw)))
        }
      } else if !raw.is_blank() {
        // collapse surrounding whitespace like svgo does
        out.push(Text(decode_entities(raw.trim().to_owned())))
      }
      continue
    }
    let next = self.peek(offset=1)
    if next == 47 {
      // "</"
      guard parent is Some(_) else {
        raise self.error("unexpected closing tag")
      }
      return
    }
    if next != 33 && next != 63 {
      out.push(Element(self.parse_element()))
      continue
    }
    if self.starts_with("<!--") {
      self.pos += 4
      out.push(Comment(self.read_until("-->")))
    } else if self.starts_with("<![CDATA[") {
      self.pos += 9
      out.push(CData(self.read_until("]]>")))
    } else if self.starts_with("<!DOCTYPE") || self.starts_with("<!doctype") {
      self.pos += 9
      let start = self.pos
      // a doctype may carry an internal subset in brackets
      let mut depth = 0
      while !self.eof() {
        let c = self.peek()
        if c == 91 {
          depth += 1
        } else if c == 93 {
          depth -= 1
        } else if c == 62 && depth <= 0 {
          break
        }
        self.pos += 1
      }
      guard !self.eof() else { raise self.error("unterminated doctype") }
      let body = self.slice(start, self.pos).trim().to_owned()
      self.pos += 1
      out.push(Doctype(body))
    } else if next == 63 {
      self.pos += 2
      let target = self.name()
      self.skip_space()
      let data = self.read_until("?>")
      out.push(ProcInst(target, data.trim_end().to_owned()))
    } else {
      raise self.error("unexpected markup declaration")
    }
  }
  if parent is Some(name) {
    raise self.error("unclosed element <\{name}>")
  }
}

///|
fn Parser::parse_element(self : Parser) -> Element raise ParseError {
  self.pos += 1 // '<'
  let name = self.name()
  let attrs : Map[String, String] = Map([])
  for ;; {
    self.skip_space()
    let c = self.peek()
    if c == 47 {
      // '/>'
      self.pos += 1
      guard self.peek() == 62 else { raise self.error("expected '>'") }
      self.pos += 1
      return { name, attrs, children: [], }
    }
    if c == 62 {
      self.pos += 1
      break
    }
    guard c != -1 else { raise self.error("unterminated start tag <\{name}>") }
    let attr = self.name()
    self.skip_space()
    guard self.peek() == 61 else {
      raise self.error("expected '=' after attribute '\{attr}'")
    }
    self.pos += 1
    self.skip_space()
    let quote = self.peek()
    guard quote == 34 || quote == 39 else {
      raise self.error("expected quoted attribute value")
    }
    self.pos += 1
    let start = self.pos
    while !self.eof() && self.peek() != quote {
      self.pos += 1
    }
    guard !self.eof() else { raise self.error("unterminated attribute value") }
    let value = decode_entities(self.slice(start, self.pos))
    self.pos += 1
    attrs[attr] = value
  }
  let children : Array[Node] = []
  let keep_space = text_elements.contains(name)
  self.parse_children(children, Some(name), keep_space~)
  // closing tag
  self.pos += 2
  let close = self.name()
  guard close == name else {
    raise self.error("mismatched closing tag </\{close}> for <\{name}>")
  }
  self.skip_space()
  guard self.peek() == 62 else { raise self.error("expected '>'") }
  self.pos += 1
  { name, attrs, children, }
}

///|
/// Decode the predefined entities and numeric character references.
/// Unknown entities are kept verbatim.
fn decode_entities(s : String) -> String {
  if !s.contains("&") {
    return s
  }
  let sb = StringBuilder()
  let mut i = 0
  let n = s.length()
  while i < n {
    let c = s.get_char(i).unwrap()
    if c != '&' {
      sb.write_char(c)
      i += 1
      continue
    }
    match s[i:].find(";") {
      Some(rel) if rel <= 10 => {
        let ent = s[i + 1:i + rel].to_owned()
        let decoded : String? = match ent {
          "lt" => Some("<")
          "gt" => Some(">")
          "amp" => Some("&")
          "quot" => Some("\"")
          "apos" => Some("'")
          _ =>
            if ent.has_prefix("#x") || ent.has_prefix("#X") {
              parse_code(ent[2:], 16).map(ch => ch.to_string())
            } else if ent.has_prefix("#") {
              parse_code(ent[1:], 10).map(ch => ch.to_string())
            } else {
              None
            }
        }
        match decoded {
          Some(d) => {
            sb.write_string(d)
            i += rel + 1
          }
          None => {
            sb.write_char('&')
            i += 1
          }
        }
      }
      _ => {
        sb.write_char('&')
        i += 1
      }
    }
  }
  sb.to_string()
}

///|
/// The code point written in a character reference, `base` 10 or 16; None for
/// no digits, a non-digit, or a value outside the Unicode range.
fn parse_code(digits : StringView, base : Int) -> Char? {
  let mut code = 0
  let mut count = 0
  for c in digits {
    let d = if c >= '0' && c <= '9' {
      c.to_int() - 48
    } else if base == 16 && c >= 'a' && c <= 'f' {
      c.to_int() - 87
    } else if base == 16 && c >= 'A' && c <= 'F' {
      c.to_int() - 55
    } else {
      return None
    }
    code = code * base + d
    count += 1
    if code > 0x10FFFF {
      return None
    }
  }
  if count == 0 {
    return None
  }
  code.to_char()
}
