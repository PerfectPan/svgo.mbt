///|
/// CSS minifier module for svgo/css.
/// Performs safe, semantics-preserving minification:
/// - Whitespace removal around punctuation
/// - Semicolon deduplication and trailing semicolon omission
/// - Merging 4-part TRBL box-properties (e.g., margin: 1em 1em 1em 1em -> margin: 1em)
/// - Shortening hex colors (#ffffff -> #fff)
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
  v
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
