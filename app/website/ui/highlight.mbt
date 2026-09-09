///|
/// Syntax colouring for the editors: a small lossless lexer over the raw
/// text (unlike the real parser it never normalises anything), producing
/// spans with `hl-*` classes. Comments, prolog/doctype, tag names, attribute
/// names, quoted values and punctuation are distinguished; character data
/// stays plain.
priv enum Tok {
  Text
  Comment
  Prolog
  Tag
  Attr
  Value
  Punct
}

///|
fn Tok::class(self : Tok) -> String {
  match self {
    Text => ""
    Comment => "hl-cmt"
    Prolog => "hl-pro"
    Tag => "hl-tag"
    Attr => "hl-attr"
    Value => "hl-val"
    Punct => "hl-p"
  }
}

///|
/// Above this many code units the editor shows plain text: the win from
/// colour is small on a huge document and the span count is not.
pub let highlight_limit : Int = 120_000

///|
fn is_name_unit(c : Int) -> Bool {
  (c >= 'a' && c <= 'z') ||
  (c >= 'A' && c <= 'Z') ||
  (c >= '0' && c <= '9') ||
  c == '-' ||
  c == '_' ||
  c == ':' ||
  c == '.' ||
  c > 127
}

///|
fn find_from(s : String, sub : String, from : Int) -> Int? {
  if from >= s.length() {
    return None
  }
  match s[from:].find(sub) {
    Some(rel) => Some(from + rel)
    None => None
  }
}

///|
/// Tokenise `src` into Html spans. The text content of the result is
/// exactly `src`, so it can sit behind a transparent textarea.
pub fn highlight(src : String) -> Array[Html] {
  if src.length() > highlight_limit {
    return [text(src)]
  }
  tokenize(src).map(tok => {
    let (cls, s) = tok
    if cls.is_empty() {
      text(s)
    } else {
      span(class=cls, s)
    }
  })
}

///|
/// `(class, text)` pairs; concatenating the texts gives `src` back.
pub fn tokenize(src : String) -> Array[(String, String)] {
  let out : Array[(String, String)] = []
  let cu = src.code_units()
  let mut start = 0
  let mut kind : Tok = Text
  let flush = fn(upto : Int, next : Tok) {
    if upto > start {
      out.push((kind.class(), src.unsafe_substring(start~, end=upto)))
    }
    start = upto
    kind = next
  }
  let n = src.length()
  let mut i = 0
  // outside any tag
  while i < n {
    let c = cu[i].to_int()
    if c != '<' {
      i += 1
      continue
    }
    flush(i, Punct)
    // comment
    if find_from(src, "<!--", i) is Some(p) && p == i {
      kind = Comment
      let end = match find_from(src, "-->", i + 4) {
        Some(e) => e + 3
        None => n
      }
      i = end
      flush(i, Text)
      continue
    }
    // prolog, doctype, cdata
    if i + 1 < n && (cu[i + 1].to_int() == '?' || cu[i + 1].to_int() == '!') {
      kind = Prolog
      let end = match find_from(src, ">", i) {
        Some(e) => e + 1
        None => n
      }
      i = end
      flush(i, Text)
      continue
    }
    // tag: `<` or `</`
    i += 1
    if i < n && cu[i].to_int() == '/' {
      i += 1
    }
    flush(i, Tag)
    while i < n && is_name_unit(cu[i].to_int()) {
      i += 1
    }
    flush(i, Text)
    // attributes until `>`
    while i < n {
      let c = cu[i].to_int()
      if c == '>' {
        flush(i, Punct)
        i += 1
        flush(i, Text)
        break
      } else if c == '/' && i + 1 < n && cu[i + 1].to_int() == '>' {
        flush(i, Punct)
        i += 2
        flush(i, Text)
        break
      } else if c == '"' || c == '\'' {
        flush(i, Value)
        let end = match find_from(src, unit_string(c), i + 1) {
          Some(e) => e + 1
          None => n
        }
        i = end
        flush(i, Text)
      } else if c == '=' {
        flush(i, Punct)
        i += 1
        flush(i, Text)
      } else if is_name_unit(c) {
        flush(i, Attr)
        while i < n && is_name_unit(cu[i].to_int()) {
          i += 1
        }
        flush(i, Text)
      } else {
        i += 1
      }
    }
  }
  flush(n, Text)
  out
}
