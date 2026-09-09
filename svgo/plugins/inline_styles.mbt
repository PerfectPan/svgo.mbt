///|
/// Implementation of inlineStyles plugin matching upstream SVGO exactly.

///|
fn includes_attr_selector_in_complex(
  selector : @css.ComplexSelector,
  attr_name : String,
  val : String?,
  traversed : Bool,
) -> Bool {
  fn check_compound(compound : @css.CompoundSelector) -> Bool {
    for s in compound.simples {
      match s {
        Attribute(a, matcher) =>
          if a == attr_name {
            match val {
              None => return true
              Some(v) =>
                match matcher {
                  Equals(target) => if target == v { return true }
                  _ => ()
                }
            }
          }
        Class(cls) =>
          if attr_name == "class" {
            match val {
              None => return true
              Some(v) => if cls == v { return true }
            }
          }
        Id(id) =>
          if attr_name == "id" {
            match val {
              None => return true
              Some(v) => if id == v { return true }
            }
          }
        PseudoClass(_, Some(arg)) => {
          let inner_list = @css.parse_selector_list(arg)
          for sel in inner_list {
            if includes_attr_selector_in_complex(sel, attr_name, val, traversed) {
              return true
            }
          }
        }
        _ => ()
      }
    }
    false
  }

  if traversed {
    if check_compound(selector.head) && selector.tail.length() > 0 {
      return true
    }
    for i = 0; i < selector.tail.length() - 1; i = i + 1 {
      if check_compound(selector.tail[i].1) {
        return true
      }
    }
    false
  } else {
    if check_compound(selector.head) {
      return true
    }
    for pair in selector.tail {
      if check_compound(pair.1) {
        return true
      }
    }
    false
  }
}

///|
fn strip_unsupported_pseudos(
  selector : @css.ComplexSelector,
  use_pseudos : Array[String],
) -> (@css.ComplexSelector, Bool) {
  fn filter_compound(
    compound : @css.CompoundSelector,
  ) -> (@css.CompoundSelector, Bool) {
    let new_simples : Array[@css.SimpleSelector] = []
    for s in compound.simples {
      match s {
        PseudoClass(name, _) =>
          if name == "not" ||
            name == "is" ||
            name == "where" ||
            name == "has" ||
            name == "first-child" ||
            name == "last-child" ||
            name == "only-child" ||
            name == "first-of-type" ||
            name == "last-of-type" ||
            name == "only-of-type" ||
            name == "nth-child" ||
            name == "nth-last-child" ||
            name == "nth-of-type" ||
            name == "nth-last-of-type" ||
            name == "root" ||
            name == "empty" {
            new_simples.push(s)
          } else {
            let colon_name = ":" + name
            if use_pseudos.contains(name) || use_pseudos.contains(colon_name) {
              ()
            } else {
              return ({ simples: [], }, false)
            }
          }
        PseudoElement(name) => {
          let colon_name = "::" + name
          if use_pseudos.contains(name) || use_pseudos.contains(colon_name) {
            ()
          } else {
            return ({ simples: [], }, false)
          }
        }
        _ => new_simples.push(s)
      }
    }
    ({ simples: new_simples, }, true)
  }

  let (new_head, ok1) = filter_compound(selector.head)
  if !ok1 {
    return (selector, false)
  }
  let new_tail : Array[(@css.Combinator, @css.CompoundSelector)] = []
  for pair in selector.tail {
    let (c, ok) = filter_compound(pair.1)
    if !ok {
      return (selector, false)
    }
    new_tail.push((pair.0, c))
  }
  ({ head: new_head, tail: new_tail, raw: selector.raw, }, true)
}

///|
priv struct SelectorEntry {
  raw_selector : @css.ComplexSelector
  matched_selector : @css.ComplexSelector
  declarations : Array[@css.Declaration]
  parent_items : Array[@css.StyleSheetItem]
  item_idx : Int
  selector_idx : Int
  order : Int
  specificity : @css.Specificity
  mut matched_indices : Array[Int]
}

///|
/// Normalize a media query / at-rule prelude string for comparison against
/// the `useMqs` list. svgo compares against csstree.generate output, which
/// drops whitespace around `:`, `(`, `)`, `,` and collapses runs of spaces.
fn normalize_mq(s : String) -> String {
  let chars = s.code_units()
  let len = chars.length()
  let sb = StringBuilder()
  let mut i = 0
  while i < len {
    let c = chars[i]
    if c == 32 || c == 9 || c == 10 || c == 13 {
      // whitespace: skip if adjacent to punctuation, else emit one space
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
          chars[i - 1] == 41 ||
          chars[i - 1] == 44 ||
          chars[i - 1] == 59
        )
      let next_is_punct = j < len &&
        (
          chars[j] == 58 ||
          chars[j] == 41 ||
          chars[j] == 44 ||
          chars[j] == 59 ||
          chars[j] == 40
        )
      if !prev_is_punct && !next_is_punct {
        sb.write_char(' ')
      }
      i = j
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
fn collect_style_text(elem : @xml.Element) -> String {
  let sb = StringBuilder()
  for child in elem.children {
    match child {
      Text(t) => sb.write_string(t)
      CData(cd) => sb.write_string(cd)
      _ => ()
    }
  }
  sb.to_string()
}

///|
fn run_inline_styles(doc : @xml.Document, ctx : Context) -> Bool {
  let only_matched_once = ctx.param_bool("onlyMatchedOnce", true)
  let remove_matched_selectors = ctx.param_bool("removeMatchedSelectors", true)
  let use_mqs_param = ctx.param_strings("useMqs")
  let use_mqs = if use_mqs_param.is_empty() {
    ["", "screen"]
  } else {
    use_mqs_param
  }
  let use_pseudos_param = ctx.param_strings("usePseudos")
  let use_pseudos = if use_pseudos_param.is_empty() {
    [""]
  } else {
    use_pseudos_param
  }

  let root = match doc.root() {
    Some(r) => r
    None => return false
  }

  // 1. Collect all style elements not inside foreignObject
  let style_elements : Array[@xml.Element] = []
  fn find_styles(elem : @xml.Element, inside_fo : Bool) {
    let is_fo = inside_fo || elem.name == "foreignObject"
    if !is_fo && elem.name == "style" {
      style_elements.push(elem)
    }
    for child in elem.children {
      match child {
        Element(e) => find_styles(e, is_fo)
        _ => ()
      }
    }
  }
  find_styles(root, false)
  if style_elements.is_empty() {
    return false
  }

  // 2. Parse stylesheets and collect selectors
  let parsed_sheets : Array[(@xml.Element, @css.StyleSheet)] = []
  let all_selectors : Array[SelectorEntry] = []
  let mut order_counter = 0

  for elem in style_elements {
    // svgo skips <style> elements whose type is neither empty nor "text/css".
    match elem.attrs.get("type") {
      Some(t) if !t.is_empty() && t != "text/css" => continue
      _ => ()
    }
    let css_text = match elem.attrs.get("media") {
      Some(m) if !m.is_empty() && m != "all" =>
        "@media " + m + "{" + collect_style_text(elem) + "}"
      _ => collect_style_text(elem)
    }
    let sheet = @css.parse_stylesheet(css_text)
    parsed_sheets.push((elem, sheet))

    // Collect selectors from rules, descending into at-rules whose
    // media query is allowed by useMqs.
    fn collect_from_items(
      items : Array[@css.StyleSheetItem],
      media_query : String,
      style_elem : @xml.Element,
    ) -> Unit {
      for item_idx = 0; item_idx < items.length(); item_idx = item_idx + 1 {
        match items[item_idx] {
          Rule(rule) =>
            for sel_idx = 0
                sel_idx < rule.selectors.length()
                sel_idx = sel_idx + 1 {
              let sel = rule.selectors[sel_idx]
              let (matched_sel, can_match) = strip_unsupported_pseudos(
                sel, use_pseudos,
              )
              if can_match {
                let spec = sel.specificity()
                all_selectors.push({
                  raw_selector: sel,
                  matched_selector: matched_sel,
                  declarations: rule.declarations,
                  parent_items: items,
                  item_idx,
                  selector_idx: sel_idx,
                  order: order_counter,
                  specificity: spec,
                  matched_indices: [],
                })
              }
              order_counter = order_counter + 1
            }
          AtRule(name, params, children) => {
            let mq = if media_query.is_empty() {
              let raw = name +
                (if params.is_empty() { "" } else { " " + params })
              normalize_mq(raw)
            } else {
              media_query
            }
            if use_mqs.iter().any(fn(m) { normalize_mq(m) == mq }) {
              match children {
                Some(inner) => collect_from_items(inner, mq, style_elem)
                None => ()
              }
            }
          }
          _ => ()
        }
      }
    }
    collect_from_items(sheet.items, "", elem)
  }

  if all_selectors.is_empty() {
    return false
  }

  // Build document context for matching
  let tables = svg_tables()
  let doc_ctx = @css.DocumentContext::build(doc)
  let mut changed = false

  // Sort selectors by specificity descending, then by order descending
  stable_sort_by(all_selectors, fn(a, b) {
    let cmp = b.specificity.compare(a.specificity)
    if cmp != 0 {
      cmp
    } else {
      b.order.compare(a.order)
    }
  })

  // Track selectors to remove
  let selectors_to_remove : Array[SelectorEntry] = []

  // First pass: match selectors and apply styles. Class/ID cleanup is
  // deferred until after all selectors have been matched, otherwise
  // removing a class mid-loop makes later selectors for that class miss.
  for entry in all_selectors {
    let matched_indices = doc_ctx.find_all_matches(entry.matched_selector)
    if matched_indices.is_empty() {
      continue
    }
    if only_matched_once && matched_indices.length() > 1 {
      continue
    }
    entry.matched_indices = matched_indices

    // Apply styles to matched elements
    for idx in matched_indices {
      let el = doc_ctx.elements[idx]
      let existing_style = match el.attrs.get("style") {
        Some(s) => s
        None => ""
      }
      let existing_decls = @css.parse_declarations(existing_style)
      let decl_map : Map[String, (@css.Declaration, Int)] = Map([])
      for i = 0; i < existing_decls.length(); i = i + 1 {
        decl_map[existing_decls[i].name] = (existing_decls[i], i)
      }

      let new_decls : Array[@css.Declaration] = []
      for rule_decl in entry.declarations {
        let prop = rule_decl.name

        let is_pres = match tables.attr_groups.get("presentation") {
          Some(arr) => arr.contains(prop)
          None => false
        }
        if is_pres {
          let used_in_attr_sel = all_selectors
            .iter()
            .any(fn(s) {
              includes_attr_selector_in_complex(
                s.raw_selector,
                prop,
                None,
                false,
              )
            })
          if !used_in_attr_sel {
            if el.attrs.contains(prop) {
              el.attrs.remove(prop)
              changed = true
            }
          }
        }

        match decl_map.get(prop) {
          None => new_decls.push(rule_decl)
          Some((existing, _)) =>
            if !existing.important && rule_decl.important {
              new_decls.push(rule_decl)
            }
        }
      }

      for d in existing_decls {
        let prop = d.name
        let overridden = new_decls.iter().any(fn(nd) { nd.name == prop })
        if !overridden {
          new_decls.push(d)
        }
      }

      let serialized_style = @css.serialize_declarations(new_decls)
      if el.attrs.get("style") != Some(serialized_style) {
        if serialized_style.is_empty() {
          el.attrs.remove("style")
        } else {
          el.attrs["style"] = serialized_style
        }
        changed = true
      }
    }

    if remove_matched_selectors {
      selectors_to_remove.push(entry)
    }
  }

  // Second pass: clean up class and id attributes on matched elements.
  for entry in all_selectors {
    if entry.matched_indices.is_empty() {
      continue
    }
    if only_matched_once && entry.matched_indices.length() > 1 {
      continue
    }

    for idx in entry.matched_indices {
      let el = doc_ctx.elements[idx]
      match el.attrs.get("class") {
        Some(cls_str) => {
          let classes = cls_str
            .split(" ")
            .filter(fn(s) { !s.is_empty() })
            .to_array()
          let new_classes : Array[String] = []
          for c in classes {
            let cv = c.to_owned()
            let used_in_selector = all_selectors
              .iter()
              .any(fn(s) {
                includes_attr_selector_in_complex(
                  s.raw_selector,
                  "class",
                  Some(cv),
                  true,
                )
              })
            if used_in_selector {
              new_classes.push(cv)
            }
          }
          if new_classes.is_empty() {
            el.attrs.remove("class")
            changed = true
          } else {
            let joined = new_classes.join(" ")
            if joined != cls_str {
              el.attrs["class"] = joined
              changed = true
            }
          }
        }
        None => ()
      }

      match el.attrs.get("id") {
        Some(id_val) => {
          let is_first_id = match entry.raw_selector.head.simples[0] {
            Id(id_name) => id_name == id_val
            _ => false
          }
          if is_first_id {
            let used_in_selector = all_selectors
              .iter()
              .any(fn(s) {
                includes_attr_selector_in_complex(
                  s.raw_selector,
                  "id",
                  Some(id_val),
                  true,
                )
              })
            if !used_in_selector {
              el.attrs.remove("id")
              changed = true
            }
          }
        }
        None => ()
      }
    }
  }

  // Remove matched selectors from their rules. We mutate the parsed AST
  // directly (arrays are shared), then re-serialize each stylesheet.
  for entry in selectors_to_remove {
    match entry.parent_items[entry.item_idx] {
      Rule(rule) => {
        // Remove the selector from the rule's selector list.
        let new_sels : Array[@css.ComplexSelector] = []
        for i = 0; i < rule.selectors.length(); i = i + 1 {
          if i != entry.selector_idx {
            new_sels.push(rule.selectors[i])
          }
        }
        rule.selectors.clear()
        for s in new_sels {
          rule.selectors.push(s)
        }
      }
      _ => ()
    }
  }

  // Remove rules that have no selectors left. svgo does NOT remove empty
  // at-rules (e.g. an empty @media block is preserved), only empty rules.
  // Declarations (inside @font-face, @viewport, @page) are also kept.
  fn clean_empty_rules(items : Array[@css.StyleSheetItem]) -> Unit {
    let mut i = 0
    while i < items.length() {
      match items[i] {
        @css.Rule(rule) =>
          if rule.selectors.is_empty() {
            items.remove(i) |> ignore
            continue
          }
        @css.AtRule(_, _, children) =>
          match children {
            Some(inner) => clean_empty_rules(inner)
            None => ()
          }
        _ => ()
      }
      i = i + 1
    }
  }

  // Update or remove style elements. Always re-serialize so the CSS is
  // normalized (trailing semicolons dropped, etc.), matching svgo which
  // round-trips every stylesheet through csstree.generate.
  for pair in parsed_sheets {
    let (style_elem, sheet) = pair
    clean_empty_rules(sheet.items)

    if sheet.items.is_empty() {
      // Remove style element from parent
      fn remove_elem_from(p : @xml.Element, target : @xml.Element) -> Bool {
        let mut removed = false
        let new_children : Array[@xml.Node] = []
        for child in p.children {
          match child {
            Element(e) =>
              if physical_equal(e, target) {
                removed = true
              } else {
                if remove_elem_from(e, target) {
                  removed = true
                }
                new_children.push(child)
              }
            _ => new_children.push(child)
          }
        }
        p.children.clear()
        for c in new_children {
          p.children.push(c)
        }
        removed
      }
      ignore(remove_elem_from(root, style_elem))
      changed = true
    } else {
      let new_css = sheet.to_css()
      style_elem.children.clear()
      style_elem.children.push(Text(new_css))
      changed = true
    }
  }

  changed
}
