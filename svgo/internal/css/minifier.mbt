///|
/// CSS minifier module for svgo/css.
/// Performs safe, semantics-preserving minification:
/// - Whitespace removal around punctuation
/// - Semicolon deduplication and trailing semicolon omission
/// - Merging 4-part TRBL box-properties (e.g., margin: 1em 1em 1em 1em -> margin: 1em)
/// - Shortening hex colors (#ffffff -> #fff)
/// - Packing numbers like csso (0.50 -> .5, 6.000 -> 6, 0px -> 0)
/// - Removing unused selectors/rules when element usage is provided

///|
pub fn min_box_shorthand(
  top : String,
  right : String,
  bottom : String,
  left : String,
) -> String {
  if top == right && right == bottom && bottom == left {
    top
  } else if top == bottom && right == left {
    top + " " + right
  } else if right == left {
    top + " " + right + " " + bottom
  } else {
    top + " " + right + " " + bottom + " " + left
  }
}

///|
/// Compresses 4 physical properties into a shorthand if all 4 are present and simple.
pub fn compress_box_properties(
  decls : Array[Declaration],
) -> Array[Declaration] {
  // We check for margin and padding
  let mut has_margin = false
  let mut has_padding = false
  for d in decls {
    if d.name.has_prefix("margin-") {
      has_margin = true
    }
    if d.name.has_prefix("padding-") {
      has_padding = true
    }
  }
  if !has_margin && !has_padding {
    return decls
  }

  let prefixes = ["margin", "padding"]
  let mut current = decls
  for prefix in prefixes {
    let top_key = prefix + "-top"
    let right_key = prefix + "-right"
    let bottom_key = prefix + "-bottom"
    let left_key = prefix + "-left"

    let mut top : (String, Bool)? = None
    let mut right : (String, Bool)? = None
    let mut bottom : (String, Bool)? = None
    let mut left : (String, Bool)? = None

    for d in current {
      if d.name == top_key {
        top = Some((d.value, d.important))
      } else if d.name == right_key {
        right = Some((d.value, d.important))
      } else if d.name == bottom_key {
        bottom = Some((d.value, d.important))
      } else if d.name == left_key {
        left = Some((d.value, d.important))
      }
    }

    match (top, right, bottom, left) {
      (Some((t_v, t_i)), Some((r_v, r_i)), Some((b_v, b_i)), Some((l_v, l_i))) =>
        // If all 4 have the same important flag
        if t_i == r_i && r_i == b_i && b_i == l_i {
          let shorthand_val = min_box_shorthand(t_v, r_v, b_v, l_v)
          let next = []
          let mut inserted = false
          for d in current {
            if d.name == top_key ||
              d.name == right_key ||
              d.name == bottom_key ||
              d.name == left_key {
              if !inserted {
                next.push({
                  name: prefix,
                  value: shorthand_val,
                  important: t_i,
                })
                inserted = true
              }
            } else {
              next.push(d)
            }
          }
          current = next
        }
      _ => ()
    }
  }
  current
}

///|
/// Compresses font-family value by removing unnecessary quotes or spaces
pub fn minify_value(prop : String, val : String) -> String {
  let v = val.trim().to_owned()
  if prop == "font-family" {
    // e.g. "Helvetica LT Std, Helvetica, Arial" -> "Helvetica LT Std,Helvetica,Arial"
    let sb = StringBuilder()
    let parts = v.split(",")
    let mut first = true
    for p in parts {
      if !first {
        sb.write_string(",")
      }
      first = false
      sb.write_string(p.trim().to_owned())
    }
    return sb.to_string()
  }
  if v.has_prefix("#") && v.length() == 7 {
    // Try #ffffff -> #fff
    let c1 = v[1]
    let c2 = v[2]
    let c3 = v[3]
    let c4 = v[4]
    let c5 = v[5]
    let c6 = v[6]
    if c1 == c2 && c3 == c4 && c5 == c6 {
      let sb = StringBuilder()
      sb.write_char('#')
      sb.write_char(v[1].to_int().to_char().unwrap())
      sb.write_char(v[3].to_int().to_char().unwrap())
      sb.write_char(v[5].to_int().to_char().unwrap())
      return sb.to_string()
    }
  }
  if prop.has_prefix("--") {
    // Custom property values are opaque token lists (csso keeps them raw).
    return v
  }
  pack_numbers(prop, v)
}

///|
/// Length units whose zero value may drop the unit, as in csso's Dimension.
let zero_length_units : Set[String] = Set([
  "px", "mm", "cm", "in", "pt", "pc", "em", "ex", "ch", "rem", "vh", "vw", "vmin",
  "vmax", "vm",
])

///|
/// csso's packNumber: `+1.50` -> `1.5`, `0.50` -> `.5`, `-0.0` -> `0`.
/// Numbers with an exponent stay as they are, like csso's regexp leaves them.
fn pack_number(num : StringView) -> String {
  let mut i = 0
  let mut neg = false
  if num[0] == '+' || num[0] == '-' {
    neg = num[0] == '-'
    i = 1
  }
  let int_start = i
  while i < num.length() && num[i] >= '0' && num[i] <= '9' {
    i += 1
  }
  let int_end = i
  let mut frac_start = i
  let mut frac_end = i
  if i < num.length() && num[i] == '.' {
    frac_start = i + 1
    i += 1
    while i < num.length() && num[i] >= '0' && num[i] <= '9' {
      i += 1
    }
    frac_end = i
  }
  if i < num.length() {
    // exponent
    return num.to_owned()
  }
  let mut s = int_start
  while s < int_end && num[s] == '0' {
    s += 1
  }
  let mut e = frac_end
  while e > frac_start && num[e - 1] == '0' {
    e -= 1
  }
  if s == int_end && e == frac_start {
    return "0"
  }
  let sb = StringBuilder()
  if neg {
    sb.write_char('-')
  }
  sb.write_string(num[s:int_end].to_owned())
  if e > frac_start {
    sb.write_char('.')
    sb.write_string(num[frac_start:e].to_owned())
  }
  sb.to_string()
}

///|
fn is_ascii_digit(c : UInt16) -> Bool {
  c >= '0' && c <= '9'
}

///|
fn is_word_char(c : UInt16) -> Bool {
  (c >= 'a' && c <= 'z') ||
  (c >= 'A' && c <= 'Z') ||
  is_ascii_digit(c) ||
  c == '_' ||
  c == '-' ||
  c == '\\' ||
  c >= 0x80
}

///|
/// Whether a CSS number token starts at `i`: a digit, `.digit`, or a sign
/// followed by either.
fn number_starts_at(v : String, i : Int) -> Bool {
  let n = v.length()
  let mut j = i
  if v[j] == '+' || v[j] == '-' {
    j += 1
  }
  if j < n && is_ascii_digit(v[j]) {
    return true
  }
  j + 1 < n && v[j] == '.' && is_ascii_digit(v[j + 1])
}

///|
/// Rewrites number, dimension and percentage tokens of a declaration value the
/// way csso does: packed numbers, and zero lengths without their unit outside
/// `flex` and math functions. Strings, `url()`, `var()`, hashes and identifiers
/// are copied verbatim. A token is rewritten only when it stands alone (after a
/// separator and not followed by `.`), where csso's output cannot re-tokenize
/// differently; csso also rewrites glued tokens such as `1-0.5`, and would
/// split `Foo2.0` into `Foo2 0`, which this skips.
fn pack_numbers(prop : String, v : String) -> String {
  let n = v.length()
  // Cheap exit: nothing to pack without a digit.
  let mut has_digit = false
  for i in 0..<n {
    if is_ascii_digit(v[i]) {
      has_digit = true
      break
    }
  }
  if !has_digit {
    return v
  }
  let lower_prop = prop.to_lower()
  let keep_zero_unit = lower_prop == "flex" || lower_prop == "-ms-flex"
  let sb = StringBuilder()
  // Enclosing function names, lowercased; "" for a bare parenthesis.
  let funcs : Array[String] = []
  // Depth inside url()/var(), whose contents are copied verbatim.
  let mut verbatim_depth = 0
  let mut i = 0
  while i < n {
    let c = v[i]
    if c == '"' || c == '\'' {
      let start = i
      i += 1
      while i < n && v[i] != c {
        if v[i] == '\\' {
          i += 1
        }
        i += 1
      }
      i = if i < n { i + 1 } else { n }
      sb.write_string(v[start:i].to_owned())
      continue
    }
    if c == '(' {
      funcs.push("")
      if verbatim_depth > 0 {
        verbatim_depth += 1
      }
      sb.write_char('(')
      i += 1
      continue
    }
    if c == ')' {
      funcs.pop() |> ignore
      if verbatim_depth > 0 {
        verbatim_depth -= 1
      }
      sb.write_char(')')
      i += 1
      continue
    }
    if verbatim_depth == 0 && number_starts_at(v, i) {
      let prev : UInt16 = if i == 0 { ' ' } else { v[i - 1] }
      let standalone = prev == ' ' ||
        prev == '\t' ||
        prev == '\n' ||
        prev == '\r' ||
        prev == ',' ||
        prev == '/' ||
        prev == '(' ||
        prev == '*'
      let start = i
      if v[i] == '+' || v[i] == '-' {
        i += 1
      }
      while i < n && is_ascii_digit(v[i]) {
        i += 1
      }
      if i + 1 < n && v[i] == '.' && is_ascii_digit(v[i + 1]) {
        i += 1
        while i < n && is_ascii_digit(v[i]) {
          i += 1
        }
      }
      if i + 1 < n && (v[i] == 'e' || v[i] == 'E') {
        let mut j = i + 1
        if v[j] == '+' || v[j] == '-' {
          j += 1
        }
        if j < n && is_ascii_digit(v[j]) {
          i = j
          while i < n && is_ascii_digit(v[i]) {
            i += 1
          }
        }
      }
      let num_end = i
      let mut unit_ok = true
      if i < n && v[i] == '%' {
        i += 1
      } else if i < n &&
        ((v[i] >= 'a' && v[i] <= 'z') || (v[i] >= 'A' && v[i] <= 'Z')) {
        while i < n && is_word_char(v[i]) {
          if !((v[i] >= 'a' && v[i] <= 'z') || (v[i] >= 'A' && v[i] <= 'Z')) {
            unit_ok = false
          }
          i += 1
        }
      } else if i < n && (is_word_char(v[i]) || v[i] == '.') {
        unit_ok = false
      }
      if !standalone || !unit_ok {
        sb.write_string(v[start:i].to_owned())
        continue
      }
      let packed = pack_number(v[start:num_end])
      let unit = v[num_end:i]
      sb.write_string(packed)
      let drop_unit = packed == "0" &&
        !keep_zero_unit &&
        zero_length_units.contains(unit.to_owned().to_lower()) &&
        (match funcs.last() {
          Some(f) => f != "calc" && f != "min" && f != "max" && f != "clamp"
          None => true
        })
      if !drop_unit {
        sb.write_string(unit.to_owned())
      }
      continue
    }
    if c == '#' || is_word_char(c) {
      let start = i
      i += 1
      while i < n && is_word_char(v[i]) {
        if v[i] == '\\' && i + 1 < n {
          i += 1
        }
        i += 1
      }
      let word = v[start:i].to_owned()
      if i < n && v[i] == '(' {
        let name = word.to_lower()
        funcs.push(name)
        if verbatim_depth > 0 || name == "url" || name == "var" {
          verbatim_depth += 1
        }
        sb.write_string(word)
        sb.write_char('(')
        i += 1
        continue
      }
      sb.write_string(word)
      continue
    }
    sb.write_char(c.to_int().unsafe_to_char())
    i += 1
  }
  sb.to_string()
}

///|
/// Minifies a declaration list (box compression + value compression)
pub fn minify_declarations(decls : Array[Declaration]) -> Array[Declaration] {
  let compressed = compress_box_properties(decls)
  let result = []
  for d in compressed {
    result.push({
      name: d.name,
      value: minify_value(d.name, d.value),
      important: d.important,
    })
  }
  result
}

///|
pub(all) struct Usage {
  tags : Set[String]?
  ids : Set[String]?
  classes : Set[String]?
}

///|
fn is_selector_used(sel : ComplexSelector, usage : Usage) -> Bool {
  fn check_compound(compound : CompoundSelector) -> Bool {
    for s in compound.simples {
      match s {
        Type(t) =>
          match usage.tags {
            Some(tags) => if !tags.contains(t) { return false }
            None => ()
          }
        Id(id) =>
          match usage.ids {
            Some(ids) => if !ids.contains(id) { return false }
            None => ()
          }
        Class(cls) =>
          match usage.classes {
            Some(classes) => if !classes.contains(cls) { return false }
            None => ()
          }
        _ => ()
      }
    }
    true
  }

  if !check_compound(sel.head) {
    return false
  }
  for pair in sel.tail {
    if !check_compound(pair.1) {
      return false
    }
  }
  true
}

///|
pub fn minify_stylesheet_with_usage(
  sheet : StyleSheet,
  usage : Usage?,
) -> StyleSheet {
  let new_items : Array[StyleSheetItem] = []
  for item in sheet.items {
    match item {
      Rule(rule) => {
        let new_selectors : Array[ComplexSelector] = match usage {
          Some(u) => rule.selectors.filter(fn(sel) { is_selector_used(sel, u) })
          None => rule.selectors
        }
        if new_selectors.length() > 0 {
          let min_decls = minify_declarations(rule.declarations)
          new_items.push(
            Rule({ selectors: new_selectors, declarations: min_decls, }),
          )
        }
      }
      AtRule(name, params, children) =>
        match children {
          Some(inner_items) => {
            let inner_sheet : StyleSheet = { items: inner_items, }
            let min_inner = minify_stylesheet_with_usage(inner_sheet, usage)
            if min_inner.items.length() > 0 {
              new_items.push(AtRule(name, params, Some(min_inner.items)))
            }
          }
          None => new_items.push(AtRule(name, params, None))
        }
      Raw(s) => new_items.push(Raw(s))
      Declarations(decls) => {
        let min_decls = minify_declarations(decls)
        if !min_decls.is_empty() {
          new_items.push(Declarations(min_decls))
        }
      }
    }
  }
  { items: new_items, }
}
