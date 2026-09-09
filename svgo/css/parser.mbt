///|
/// CSS tokenizer and parser using code unit slicing.

///|
priv struct Parser {
  text : String
  src : ArrayView[UInt16]
  mut pos : Int
}

///|
fn Parser::new(text : String) -> Parser {
  { text, src: text.code_units(), pos: 0, }
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
fn Parser::skip_ws_and_comments(self : Parser) -> Unit {
  while !self.eof() {
    let c = self.peek()
    if c == 32 || c == 9 || c == 10 || c == 13 || c == 12 {
      self.pos += 1
    } else if c == 47 && self.peek(offset=1) == 42 {
      // /* comment */
      self.pos += 2
      while !self.eof() && !(self.peek() == 42 && self.peek(offset=1) == 47) {
        self.pos += 1
      }
      if !self.eof() {
        self.pos += 2
      }
    } else {
      break
    }
  }
}

///|
fn is_ident_start(c : Int) -> Bool {
  (c >= 97 && c <= 122) || (c >= 65 && c <= 90) || c == 95 || c >= 128
}

///|
fn is_ident_char(c : Int) -> Bool {
  is_ident_start(c) || (c >= 48 && c <= 57) || c == 45
}

///|
fn Parser::parse_ident(self : Parser) -> String {
  let start = self.pos
  if self.peek() == 45 {
    self.pos += 1
  }
  while !self.eof() {
    let c = self.peek()
    if is_ident_char(c) {
      self.pos += 1
    } else if c == 92 && self.pos + 1 < self.src.length() {
      // escape
      self.pos += 2
    } else {
      break
    }
  }
  self.slice(start, self.pos)
}

///|
fn Parser::parse_quoted_string(self : Parser) -> String {
  if self.eof() {
    return ""
  }
  let quote = self.peek()
  self.pos += 1
  let start = self.pos
  while !self.eof() {
    let c = self.peek()
    if c == quote {
      let res = self.slice(start, self.pos)
      self.pos += 1
      return res
    } else if c == 92 && self.pos + 1 < self.src.length() {
      self.pos += 2
    } else {
      self.pos += 1
    }
  }
  self.slice(start, self.pos)
}

///|
fn Parser::parse_attribute_selector(self : Parser) -> SimpleSelector? {
  self.skip_ws_and_comments()
  let attr_name = self.parse_ident()
  if attr_name.is_empty() {
    return None
  }
  self.skip_ws_and_comments()
  if self.peek() == 93 {
    // ']'
    self.pos += 1
    return Some(Attribute(attr_name, Exists))
  }

  // Operator
  let mut op = ""
  let c = self.peek()
  if c == 61 {
    // '='
    op = "="
    self.pos += 1
  } else if self.peek(offset=1) == 61 {
    if c == 126 {
      op = "~="
    } else if c == 124 {
      op = "|="
    } else if c == 94 {
      op = "^="
    } else if c == 36 {
      op = "$="
    } else if c == 42 {
      op = "*="
    }
    if !op.is_empty() {
      self.pos += 2
    }
  }

  if op.is_empty() {
    return None
  }

  self.skip_ws_and_comments()
  let mut val = ""
  let quote = self.peek()
  if quote == 34 || quote == 39 {
    val = self.parse_quoted_string()
  } else {
    let val_start = self.pos
    while !self.eof() {
      let ch = self.peek()
      if ch == 93 || ch == 32 || ch == 9 || ch == 10 || ch == 13 {
        break
      }
      self.pos += 1
    }
    val = self.slice(val_start, self.pos)
  }

  self.skip_ws_and_comments()
  if self.peek() == 93 {
    self.pos += 1
  }

  let matcher = match op {
    "=" => Equals(val)
    "~=" => Includes(val)
    "|=" => DashMatch(val)
    "^=" => PrefixMatch(val)
    "$=" => SuffixMatch(val)
    "*=" => SubstringMatch(val)
    _ => Exists
  }
  Some(Attribute(attr_name, matcher))
}

///|
fn Parser::parse_simple_selector(self : Parser) -> SimpleSelector? {
  if self.eof() {
    return None
  }
  let c = self.peek()
  if c == 42 {
    // '*'
    self.pos += 1
    return Some(Universal)
  }
  if c == 35 {
    // '#'
    self.pos += 1
    let id_name = self.parse_ident()
    if id_name.is_empty() {
      return None
    }
    return Some(Id(id_name))
  }
  if c == 46 {
    // '.'
    self.pos += 1
    let class_name = self.parse_ident()
    if class_name.is_empty() {
      return None
    }
    return Some(Class(class_name))
  }
  if c == 91 {
    // '['
    self.pos += 1
    return self.parse_attribute_selector()
  }
  if c == 58 {
    // ':'
    if self.peek(offset=1) == 58 {
      // '::'
      self.pos += 2
      let name = self.parse_ident()
      if name.is_empty() {
        return None
      }
      return Some(PseudoElement(name))
    }
    self.pos += 1
    let name = self.parse_ident()
    if name.is_empty() {
      return None
    }
    if self.peek() == 40 {
      // '('
      self.pos += 1
      let mut depth = 1
      let arg_start = self.pos
      while !self.eof() && depth > 0 {
        let ch = self.peek()
        if ch == 40 {
          depth += 1
        } else if ch == 41 {
          depth -= 1
        }
        self.pos += 1
      }
      let arg = self.slice(arg_start, self.pos - 1).trim().to_owned()
      return Some(PseudoClass(name, Some(arg)))
    }
    return Some(PseudoClass(name, None))
  }
  // Keyframe percentage selector (e.g. 0%, 50%, 100%) must be checked
  // before the type selector, since parse_ident would consume the digits
  // but leave the '%' behind.
  if c >= 48 && c <= 57 {
    let num_start = self.pos
    while !self.eof() && self.peek() >= 48 && self.peek() <= 57 {
      self.pos += 1
    }
    if self.peek() == 37 { // '%'
      self.pos += 1
      return Some(Type(self.slice(num_start, self.pos)))
    }
    self.pos = num_start
  }
  // Type selector
  let type_name = self.parse_ident()
  if !type_name.is_empty() {
    return Some(Type(type_name))
  }
  None
}

///|
fn Parser::parse_compound_selector(self : Parser) -> CompoundSelector? {
  let simples = []
  while !self.eof() {
    let c = self.peek()
    if c == 32 ||
      c == 9 ||
      c == 10 ||
      c == 13 ||
      c == 12 ||
      c == 62 ||
      c == 43 ||
      c == 126 ||
      c == 44 ||
      c == 123 ||
      c == 41 {
      break
    }
    if c == 47 && self.starts_with("/deep/") {
      break
    }
    match self.parse_simple_selector() {
      Some(simple) => simples.push(simple)
      None => break
    }
  }
  if simples.is_empty() {
    return None
  }
  Some({ simples, })
}

///|
pub fn parse_complex_selector(raw_str : String) -> ComplexSelector? {
  let s = raw_str.trim().to_owned()
  if s.is_empty() {
    return None
  }
  let p = Parser::new(s)
  let head = match p.parse_compound_selector() {
    Some(h) => h
    None => return None
  }
  let tail = []
  while !p.eof() {
    let prev_pos = p.pos
    p.skip_ws_and_comments()
    if p.eof() {
      break
    }
    let had_ws = p.pos > prev_pos
    let mut comb = Combinator::Descendant
    let c = p.peek()
    if c == 62 {
      // '>'
      comb = Child
      p.pos += 1
      p.skip_ws_and_comments()
    } else if c == 43 {
      // '+'
      comb = NextSibling
      p.pos += 1
      p.skip_ws_and_comments()
    } else if c == 126 {
      // '~'
      comb = SubsequentSibling
      p.pos += 1
      p.skip_ws_and_comments()
    } else if c == 47 && p.starts_with("/deep/") {
      comb = Deep
      p.pos += 6
      p.skip_ws_and_comments()
    } else if !had_ws {
      break
    }

    match p.parse_compound_selector() {
      Some(compound) => tail.push((comb, compound))
      None => break
    }
  }
  Some({ head, tail, raw: s, })
}

///|
pub fn parse_selector_list(s : String) -> Array[ComplexSelector] {
  let res = []
  let len = s.length()
  let mut start = 0
  let mut depth = 0
  let mut in_quote = 0
  let cu = s.code_units()
  let mut i = 0
  while i < len {
    let c = cu[i].to_int()
    if in_quote != 0 {
      if c == in_quote {
        in_quote = 0
      } else if c == 92 && i + 1 < len {
        i += 1
      }
    } else if c == 34 || c == 39 {
      in_quote = c
    } else if c == 40 || c == 91 {
      depth += 1
    } else if c == 41 || c == 93 {
      if depth > 0 {
        depth -= 1
      }
    } else if c == 44 && depth == 0 {
      let part = s[start:i].to_owned().trim().to_owned()
      if !part.is_empty() {
        if parse_complex_selector(part) is Some(sel) {
          res.push(sel)
        }
      }
      start = i + 1
    }
    i += 1
  }
  let part = s[start:len].to_owned().trim().to_owned()
  if !part.is_empty() {
    if parse_complex_selector(part) is Some(sel) {
      res.push(sel)
    }
  }
  res
}

///|
pub fn parse_declarations(s : String) -> Array[Declaration] {
  let p = Parser::new(s)
  let res = []
  while !p.eof() {
    p.skip_ws_and_comments()
    if p.eof() {
      break
    }
    // Read property name until ':'
    let name_start = p.pos
    while !p.eof() && p.peek() != 58 && p.peek() != 59 && p.peek() != 125 {
      p.pos += 1
    }
    if p.eof() || p.peek() != 58 {
      if !p.eof() && (p.peek() == 59 || p.peek() == 125) {
        p.pos += 1
      }
      continue
    }
    let prop_name = p.slice(name_start, p.pos).trim().to_owned()
    p.pos += 1 // skip ':'

    p.skip_ws_and_comments()
    let val_start = p.pos
    let mut in_paren = 0
    let mut in_quote = 0
    while !p.eof() {
      let c = p.peek()
      if in_quote != 0 {
        if c == in_quote {
          in_quote = 0
        } else if c == 92 && p.pos + 1 < p.src.length() {
          p.pos += 1
        }
      } else if c == 34 || c == 39 {
        in_quote = c
      } else if c == 40 {
        in_paren += 1
      } else if c == 41 {
        if in_paren > 0 {
          in_paren -= 1
        }
      } else if in_paren == 0 && (c == 59 || c == 125) {
        break
      }
      p.pos += 1
    }

    let mut val_str = p.slice(val_start, p.pos).trim().to_owned()
    if !p.eof() && p.peek() == 59 {
      p.pos += 1
    }

    if !prop_name.is_empty() && !val_str.is_empty() {
      let mut important = false
      if val_str.has_suffix("!important") {
        important = true
        val_str = val_str[0:val_str.length() - 10].to_owned().trim().to_owned()
      } else if val_str.has_suffix("! important") {
        important = true
        val_str = val_str[0:val_str.length() - 11].to_owned().trim().to_owned()
      }
      res.push({ name: prop_name, value: val_str, important, })
    }
  }
  res
}

///|
/// Parse the block body of an at-rule. The body may contain declarations
/// (e.g. @font-face, @viewport, @page) or rules (e.g. @keyframes, @supports,
/// @document, @media). Declarations are stored as Rule items with empty
/// selector lists.
fn parse_at_rule_block(body : String) -> Array[StyleSheetItem] {
  let p = Parser::new(body)
  let items = []
  while !p.eof() {
    p.skip_ws_and_comments()
    if p.eof() {
      break
    }
    let start = p.pos
    let mut in_quote = 0
    let mut has_brace = false
    while !p.eof() {
      let c = p.peek()
      if in_quote != 0 {
        if c == in_quote {
          in_quote = 0
        } else if c == 92 && p.pos + 1 < p.src.length() {
          p.pos += 1
        }
      } else if c == 34 || c == 39 {
        in_quote = c
      } else if c == 123 {
        has_brace = true
        break
      } else if c == 59 {
        break
      }
      p.pos += 1
    }

    if has_brace {
      // Rule or keyframe block: selector { declarations }
      let sel_str = p.slice(start, p.pos).trim().to_owned()
      p.pos += 1 // skip '{'
      let block_start = p.pos
      let mut depth = 1
      while !p.eof() && depth > 0 {
        let c = p.peek()
        if c == 123 {
          depth += 1
        } else if c == 125 {
          depth -= 1
        }
        p.pos += 1
      }
      let inner_body = p.slice(block_start, p.pos - 1)
      let selectors = parse_selector_list(sel_str)
      let declarations = parse_declarations(inner_body)
      if !selectors.is_empty() || !declarations.is_empty() {
        items.push(Rule({ selectors, declarations, }))
      }
    } else {
      // Declaration(s). Collect all consecutive declarations (separated by
      // ';') into a single Rule with an empty selector list, so they
      // serialize as `prop:val;prop:val` inside at-rules like @font-face.
      let decl_sb = StringBuilder()
      decl_sb.write_string(p.slice(start, p.pos))
      while !p.eof() && p.peek() == 59 {
        p.pos += 1 // consume ';'
        decl_sb.write_string(";")
        p.skip_ws_and_comments()
        if p.eof() {
          break
        }
        // Peek ahead: if the next segment contains '{', it's a rule, stop.
        let peek_start = p.pos
        let mut peek_in_quote = 0
        let mut peek_has_brace = false
        while !p.eof() {
          let c = p.peek()
          if peek_in_quote != 0 {
            if c == peek_in_quote {
              peek_in_quote = 0
            } else if c == 92 && p.pos + 1 < p.src.length() {
              p.pos += 1
            }
          } else if c == 34 || c == 39 {
            peek_in_quote = c
          } else if c == 123 {
            peek_has_brace = true
            break
          } else if c == 59 {
            break
          }
          p.pos += 1
        }
        if peek_has_brace {
          // Rewind: the next segment is a rule, not a declaration.
          p.pos = peek_start
          break
        }
        decl_sb.write_string(p.slice(peek_start, p.pos))
      }
      let declarations = parse_declarations(decl_sb.to_string())
      if !declarations.is_empty() {
        items.push(Declarations(declarations))
      }
    }
  }
  items
}

///|
pub fn parse_stylesheet(css_text : String) -> StyleSheet {
  let p = Parser::new(css_text)
  let items = []

  while !p.eof() {
    p.skip_ws_and_comments()
    if p.eof() {
      break
    }

    // Check for @-rule
    if p.peek() == 64 {
      // '@'
      p.pos += 1 // skip '@'
      let at_name = p.parse_ident()
      p.skip_ws_and_comments()

      // Parse params until '{' or ';'
      let params_start = p.pos
      let mut in_quote = 0
      while !p.eof() {
        let c = p.peek()
        if in_quote != 0 {
          if c == in_quote {
            in_quote = 0
          } else if c == 92 && p.pos + 1 < p.src.length() {
            p.pos += 1
          }
        } else if c == 34 || c == 39 {
          in_quote = c
        } else if c == 123 || c == 59 {
          break
        }
        p.pos += 1
      }
      let params = p.slice(params_start, p.pos).trim().to_owned()

      if p.eof() {
        if !at_name.is_empty() || !params.is_empty() {
          items.push(AtRule(at_name, params, None))
        }
        break
      }
      if p.peek() == 59 {
        // ';' - at-rule without block (e.g. @charset, @namespace, @import)
        p.pos += 1
        items.push(AtRule(at_name, params, None))
        continue
      }
      if p.peek() == 123 {
        // '{' - at-rule with block
        p.pos += 1
        let block_start = p.pos
        let mut depth = 1
        while !p.eof() && depth > 0 {
          let c = p.peek()
          if c == 123 {
            depth += 1
          } else if c == 125 {
            depth -= 1
          }
          p.pos += 1
        }
        let block_body = p.slice(block_start, p.pos - 1)
        let inner_items = parse_at_rule_block(block_body)
        items.push(AtRule(at_name, params, Some(inner_items)))
        continue
      }
    }

    // Normal rule
    let sel_start = p.pos
    while !p.eof() && p.peek() != 123 {
      p.pos += 1
    }
    if p.eof() {
      let trailing = p.slice(sel_start, p.pos).trim().to_owned()
      if !trailing.is_empty() {
        items.push(Raw(trailing))
      }
      break
    }

    let sel_str = p.slice(sel_start, p.pos).trim().to_owned()
    p.pos += 1 // skip '{'
    let block_start = p.pos
    let mut depth = 1
    while !p.eof() && depth > 0 {
      let c = p.peek()
      if c == 123 {
        depth += 1
      } else if c == 125 {
        depth -= 1
      }
      p.pos += 1
    }
    let block_body = p.slice(block_start, p.pos - 1)
    let selectors = parse_selector_list(sel_str)
    let declarations = parse_declarations(block_body)
    if !selectors.is_empty() || !declarations.is_empty() {
      items.push(Rule({ selectors, declarations, }))
    }
  }

  { items, }
}
