///|
/// Serializes CSS AST back to CSS text.

///|
pub fn StyleSheet::to_css(self : StyleSheet) -> String {
  let sb = StringBuilder()
  for item in self.items {
    item.write_css(sb)
  }
  sb.to_string()
}

///|
pub fn StyleSheetItem::write_css(
  self : StyleSheetItem,
  sb : StringBuilder,
) -> Unit {
  match self {
    Rule(r) => r.write_css(sb)
    Declarations(decls) =>
      for i = 0; i < decls.length(); i = i + 1 {
        if i > 0 {
          sb.write_string(";")
        }
        decls[i].write_css(sb)
      }
    AtRule(name, params, children) => {
      sb.write_string("@")
      sb.write_string(name)
      if !params.is_empty() {
        sb.write_string(" ")
        sb.write_string(normalize_at_rule_params(params))
      }
      match children {
        Some(items) => {
          sb.write_string("{")
          for item in items {
            item.write_css(sb)
          }
          sb.write_string("}")
        }
        None => sb.write_string(";")
      }
    }
    Raw(s) => sb.write_string(s)
  }
}

///|
/// Normalize at-rule prelude (params) the way csstree does: drop whitespace
/// around `:`, `(`, `)`, `,`, `;`; collapse runs of spaces to a single space;
/// use double quotes for strings; strip quotes from `url()` when the URL is
/// safe (no spaces or special characters).
fn normalize_at_rule_params(s : String) -> String {
  let chars = s.code_units()
  let len = chars.length()
  let sb = StringBuilder()
  let mut i = 0
  while i < len {
    let c = chars[i]
    if c == 32 || c == 9 || c == 10 || c == 13 {
      // whitespace run
      let mut j = i
      while j < len &&
            (
              chars[j] == 32 ||
              chars[j] == 9 ||
              chars[j] == 10 ||
              chars[j] == 13
            ) {
        j += 1
      }
      let prev_is_punct = i > 0 &&
        (
          chars[i - 1] == 58 ||
          chars[i - 1] == 40 ||
          chars[i - 1] == 44 ||
          chars[i - 1] == 59
        )
      let next_is_punct = j < len &&
        (chars[j] == 58 || chars[j] == 41 || chars[j] == 44 || chars[j] == 59)
      if !prev_is_punct && !next_is_punct {
        sb.write_char(' ')
      }
      i = j
    } else if c == 39 || c == 34 {
      // quoted string: normalize to double quotes
      let quote = c
      i += 1
      let str_start = i
      while i < len && chars[i] != quote {
        if chars[i] == 92 && i + 1 < len {
          i += 1
        }
        i += 1
      }
      let content = s[str_start:i].to_owned()
      sb.write_char('"')
      sb.write_string(content)
      sb.write_char('"')
      if i < len {
        i += 1
      }
    } else if c == 117 &&
      i + 3 < len &&
      chars[i + 1] == 114 &&
      chars[i + 2] == 108 &&
      chars[i + 3] == 40 {
      // url(...)
      sb.write_string("url(")
      i += 4
      // skip whitespace
      while i < len &&
            (
              chars[i] == 32 ||
              chars[i] == 9 ||
              chars[i] == 10 ||
              chars[i] == 13
            ) {
        i += 1
      }
      let mut url_val = ""
      if i < len && (chars[i] == 39 || chars[i] == 34) {
        let q = chars[i]
        i += 1
        let us = i
        while i < len && chars[i] != q {
          if chars[i] == 92 && i + 1 < len {
            i += 1
          }
          i += 1
        }
        url_val = s[us:i].to_owned()
        if i < len {
          i += 1
        }
      } else {
        let us = i
        while i < len && chars[i] != 41 {
          i += 1
        }
        url_val = s[us:i].to_owned().trim().to_owned()
      }
      // skip whitespace before ')'
      while i < len &&
            (
              chars[i] == 32 ||
              chars[i] == 9 ||
              chars[i] == 10 ||
              chars[i] == 13
            ) {
        i += 1
      }
      if i < len && chars[i] == 41 {
        i += 1
      }
      // Decide whether to quote the URL. csstree quotes only when the URL
      // contains characters that would break the unquoted form.
      let mut needs_quotes = url_val.is_empty()
      for ch in url_val {
        if ch == ' ' ||
          ch == '\t' ||
          ch == '\n' ||
          ch == '\r' ||
          ch == '"' ||
          ch == '\'' ||
          ch == '(' ||
          ch == ')' ||
          ch == '\\' {
          needs_quotes = true
          break
        }
      }
      if needs_quotes {
        sb.write_char('"')
        sb.write_string(url_val)
        sb.write_char('"')
      } else {
        sb.write_string(url_val)
      }
      sb.write_char(')')
    } else {
      match c.to_char() {
        Some(ch) => sb.write_char(ch)
        None => ()
      }
      i += 1
    }
  }
  sb.to_string().trim().to_owned()
}

///|
pub fn Rule::to_css(self : Rule) -> String {
  let sb = StringBuilder()
  self.write_css(sb)
  sb.to_string()
}

///|
pub fn Rule::write_css(self : Rule, sb : StringBuilder) -> Unit {
  for i = 0; i < self.selectors.length(); i = i + 1 {
    if i > 0 {
      sb.write_string(",")
    }
    self.selectors[i].write_css(sb)
  }
  sb.write_string("{")
  for i = 0; i < self.declarations.length(); i = i + 1 {
    if i > 0 {
      sb.write_string(";")
    }
    self.declarations[i].write_css(sb)
  }
  sb.write_string("}")
}

///|
pub fn ComplexSelector::to_css(self : ComplexSelector) -> String {
  let sb = StringBuilder()
  self.write_css(sb)
  sb.to_string()
}

///|
pub fn ComplexSelector::write_css(
  self : ComplexSelector,
  sb : StringBuilder,
) -> Unit {
  self.head.write_css(sb)
  for step in self.tail {
    let (comb, comp) = step
    match comb {
      Descendant => sb.write_string(" ")
      Child => sb.write_string(">")
      NextSibling => sb.write_string("+")
      SubsequentSibling => sb.write_string("~")
      Deep => sb.write_string("/deep/")
    }
    comp.write_css(sb)
  }
}

///|
pub fn CompoundSelector::write_css(
  self : CompoundSelector,
  sb : StringBuilder,
) -> Unit {
  for s in self.simples {
    s.write_css(sb)
  }
}

///|
pub fn SimpleSelector::write_css(
  self : SimpleSelector,
  sb : StringBuilder,
) -> Unit {
  match self {
    Universal => sb.write_string("*")
    Type(t) => sb.write_string(t)
    Id(id) => {
      sb.write_string("#")
      sb.write_string(id)
    }
    Class(cls) => {
      sb.write_string(".")
      sb.write_string(cls)
    }
    Attribute(name, matcher) => {
      sb.write_string("[")
      sb.write_string(name)
      match matcher {
        Exists => ()
        Equals(val) => {
          sb.write_string("=")
          write_attribute_value_css(val, sb)
        }
        Includes(val) => {
          sb.write_string("~=")
          write_attribute_value_css(val, sb)
        }
        DashMatch(val) => {
          sb.write_string("|=")
          write_attribute_value_css(val, sb)
        }
        PrefixMatch(val) => {
          sb.write_string("^=")
          write_attribute_value_css(val, sb)
        }
        SuffixMatch(val) => {
          sb.write_string("$=")
          write_attribute_value_css(val, sb)
        }
        SubstringMatch(val) => {
          sb.write_string("*=")
          write_attribute_value_css(val, sb)
        }
      }
      sb.write_string("]")
    }
    PseudoClass(name, arg) => {
      sb.write_string(":")
      sb.write_string(name)
      match arg {
        Some(a) => {
          sb.write_string("(")
          sb.write_string(a)
          sb.write_string(")")
        }
        None => ()
      }
    }
    PseudoElement(name) => {
      sb.write_string("::")
      sb.write_string(name)
    }
  }
}

///|
fn write_attribute_value_css(val : String, sb : StringBuilder) -> Unit {
  let mut needs_quotes = val.is_empty()
  for c in val {
    if c == ' ' ||
      c == '\t' ||
      c == '\n' ||
      c == '\r' ||
      c == '"' ||
      c == '\'' ||
      c == '=' ||
      c == '<' ||
      c == '>' ||
      c == '`' ||
      c == '[' ||
      c == ']' {
      needs_quotes = true
      break
    }
  }
  if needs_quotes {
    sb.write_string("\"")
    for c in val {
      if c == '"' || c == '\\' {
        sb.write_char('\\')
      }
      sb.write_char(c)
    }
    sb.write_string("\"")
  } else {
    sb.write_string(val)
  }
}

///|
pub fn Declaration::to_css(self : Declaration) -> String {
  let sb = StringBuilder()
  self.write_css(sb)
  sb.to_string()
}

///|
pub fn Declaration::write_css(self : Declaration, sb : StringBuilder) -> Unit {
  sb.write_string(self.name)
  sb.write_string(":")
  sb.write_string(self.value)
  if self.important {
    sb.write_string("!important")
  }
}

///|
/// Formats a list of declarations as inline style value (e.g. "fill:red;stroke:blue")
pub fn serialize_declarations(decls : Array[Declaration]) -> String {
  let sb = StringBuilder()
  for i = 0; i < decls.length(); i = i + 1 {
    if i > 0 {
      sb.write_string(";")
    }
    decls[i].write_css(sb)
  }
  sb.to_string()
}
