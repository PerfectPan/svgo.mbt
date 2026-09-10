///|
/// Lossless lexer for MoonBit source, producing `(class, text)` pairs.
/// Concatenating the texts yields the input exactly, so it can sit behind
/// a transparent textarea. Reuses the SVG highlighter's `hl-*` colour
/// classes where the meaning matches (comment, string, punctuation) and
/// adds `hl-kw` (keywords) and `hl-type` (types / `@pkg` paths).
priv enum MbtTok {
  Comment
  String
  Char
  Number
  Keyword
  Type
  Attr
  Punct
  Name
}

///|
fn MbtTok::class(self : MbtTok) -> String {
  match self {
    Comment => "hl-cmt"
    String => "hl-val"
    Char => "hl-val"
    Number => "hl-val"
    Keyword => "hl-kw"
    Type => "hl-type"
    Attr => "hl-attr"
    Punct => "hl-p"
    Name => ""
  }
}

///|
let mbt_keywords : Set[String] = Set::from_array([
  "fn", "let", "mut", "pub", "priv", "struct", "enum", "type", "trait", "impl", "with",
  "match", "if", "else", "for", "while", "in", "return", "raise", "try", "catch",
  "guard", "test", "derive", "import", "true", "false", "self",
])

///|
fn is_mbt_ident_start(c : Int) -> Bool {
  (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || c == '_'
}

///|
fn is_mbt_ident_cont(c : Int) -> Bool {
  is_mbt_ident_start(c) || (c >= '0' && c <= '9') || c == '\''
}

///|
fn is_digit(c : Int) -> Bool {
  c >= '0' && c <= '9'
}

///|
fn is_upper(c : Int) -> Bool {
  c >= 'A' && c <= 'Z'
}

///|
/// `(class, text)` pairs; concatenating the texts gives `src` back.
pub fn tokenize_mbt(src : String) -> Array[(String, String)] {
  let out : Array[(String, String)] = []
  let cu = src.code_units()
  let n = src.length()
  let mut start = 0
  let mut kind : MbtTok = Name
  let flush = fn(upto : Int, next : MbtTok) {
    if upto > start {
      out.push((kind.class(), src.unsafe_substring(start~, end=upto)))
    }
    start = upto
    kind = next
  }
  let mut i = 0
  while i < n {
    let c = cu[i].to_int()
    // whitespace
    if c == ' ' || c == '\t' || c == '\n' || c == '\r' {
      flush(i, Name)
      i += 1
      flush(i, Name)
      continue
    }
    // line comment: // ... (includes ///| doc comments)
    if c == '/' && i + 1 < n && cu[i + 1].to_int() == '/' {
      flush(i, Comment)
      let mut j = i + 2
      while j < n && cu[j].to_int() != '\n' {
        j += 1
      }
      i = j
      flush(i, Name)
      continue
    }
    // string "..." with \{ } interpolation kept inside the string
    if c == '"' {
      flush(i, String)
      let mut j = i + 1
      while j < n {
        let cj = cu[j].to_int()
        if cj == '\\' {
          j += 2
          continue
        }
        if cj == '"' {
          j += 1
          break
        }
        j += 1
      }
      i = j
      flush(i, Name)
      continue
    }
    // char 'c'
    if c == '\'' {
      flush(i, Char)
      let mut j = i + 1
      while j < n {
        let cj = cu[j].to_int()
        if cj == '\\' {
          j += 2
          continue
        }
        if cj == '\'' {
          j += 1
          break
        }
        j += 1
      }
      i = j
      flush(i, Name)
      continue
    }
    // number: decimal (with optional exponent e/E and sign) or hex (0x..)
    if is_digit(c) || (c == '.' && i + 1 < n && is_digit(cu[i + 1].to_int())) {
      flush(i, Number)
      let mut j = i
      // hex literal: 0x / 0X
      let is_hex = c == '0' &&
        i + 1 < n &&
        (cu[i + 1].to_int() == 'x' || cu[i + 1].to_int() == 'X')
      if is_hex {
        j += 2
        while j < n {
          let cj = cu[j].to_int()
          if is_digit(cj) ||
            cj == '_' ||
            (cj >= 'a' && cj <= 'f') ||
            (cj >= 'A' && cj <= 'F') {
            j += 1
          } else {
            break
          }
        }
      } else {
        let mut saw_exp = false
        while j < n {
          let cj = cu[j].to_int()
          if is_digit(cj) || cj == '.' || cj == '_' {
            j += 1
          } else if !saw_exp && (cj == 'e' || cj == 'E') {
            saw_exp = true
            j += 1
            // optional sign directly after e/E
            if j < n && (cu[j].to_int() == '+' || cu[j].to_int() == '-') {
              j += 1
            }
          } else {
            break
          }
        }
      }
      i = j
      flush(i, Name)
      continue
    }
    // attribute: #name
    if c == '#' && i + 1 < n && is_mbt_ident_start(cu[i + 1].to_int()) {
      flush(i, Attr)
      let mut j = i + 1
      while j < n && is_mbt_ident_cont(cu[j].to_int()) {
        j += 1
      }
      i = j
      flush(i, Name)
      continue
    }
    // @pkg.Name path (may include "/" for package paths like @moonbitlang/core/debug.Debug)
    if c == '@' {
      flush(i, Type)
      let mut j = i + 1
      while j < n {
        let cj = cu[j].to_int()
        if is_mbt_ident_cont(cj) || cj == '.' || cj == '/' {
          j += 1
        } else {
          break
        }
      }
      i = j
      flush(i, Name)
      continue
    }
    // identifier / keyword / type
    if is_mbt_ident_start(c) {
      let mut j = i
      while j < n && is_mbt_ident_cont(cu[j].to_int()) {
        j += 1
      }
      let word = src.unsafe_substring(start=i, end=j)
      if mbt_keywords.contains(word) {
        flush(i, Keyword)
      } else if is_upper(c) {
        flush(i, Type)
      } else {
        flush(i, Name)
      }
      i = j
      flush(i, Name)
      continue
    }
    // everything else is punctuation
    flush(i, Punct)
    i += 1
    flush(i, Name)
  }
  flush(n, Name)
  out
}

///|
/// Tokenise `src` into Html spans. The text content of the result is
/// exactly `src`.
pub fn highlight_mbt(src : String) -> Array[Html] {
  tokenize_mbt(src).map(tok => {
    let (cls, s) = tok
    if cls.is_empty() {
      text(s)
    } else {
      span(class=cls, s)
    }
  })
}
