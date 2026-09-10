///|
/// CSS selector matching against @xml.Element nodes using a DocumentContext.

///|
fn match_attribute_value(val : String, matcher : AttrMatcher) -> Bool {
  match matcher {
    Exists => true
    Equals(target) => val == target
    Includes(target) => {
      let parts = val.split(" ")
      for part in parts {
        if part == target {
          return true
        }
      }
      false
    }
    DashMatch(target) => val == target || val.has_prefix(target + "-")
    PrefixMatch(target) => !target.is_empty() && val.has_prefix(target)
    SuffixMatch(target) => !target.is_empty() && val.has_suffix(target)
    SubstringMatch(target) => !target.is_empty() && val.contains(target)
  }
}

///|
pub fn match_simple(
  ctx : DocumentContext,
  node_id : Int,
  simple : SimpleSelector,
) -> Bool {
  let el = ctx.elements[node_id]
  match simple {
    Universal => true
    Type(t) => el.name == t
    Id(id) => el.attrs.get("id") == Some(id)
    Class(cls) =>
      match el.attrs.get("class") {
        None => false
        Some(classes) => {
          for c in classes.split(" ") {
            if c == cls {
              return true
            }
          }
          false
        }
      }
    Attribute(name, matcher) =>
      match el.attrs.get(name) {
        None => false
        Some(val) => match_attribute_value(val, matcher)
      }
    PseudoClass(name, arg) =>
      if name == "not" {
        match arg {
          None => false
          Some(sel_str) => {
            let inner_selectors = parse_selector_list(sel_str)
            for sel in inner_selectors {
              if match_complex(ctx, node_id, sel) {
                return false
              }
            }
            true
          }
        }
      } else {
        // dynamic or unsupported pseudo does not statically match
        false
      }
    PseudoElement(_) => false
  }
}

///|
pub fn match_compound(
  ctx : DocumentContext,
  node_id : Int,
  compound : CompoundSelector,
) -> Bool {
  for s in compound.simples {
    if !match_simple(ctx, node_id, s) {
      return false
    }
  }
  true
}

///|
/// Test if a complex selector matches a node in its document context.
pub fn match_complex(
  ctx : DocumentContext,
  node_id : Int,
  selector : ComplexSelector,
) -> Bool {
  let n = selector.tail.length()
  if n == 0 {
    return match_compound(ctx, node_id, selector.head)
  }

  // Right-most compound is selector.tail[n - 1].1
  let right_compound = selector.tail[n - 1].1
  if !match_compound(ctx, node_id, right_compound) {
    return false
  }

  // Work backwards from right to left
  fn match_prev(curr_id : Int, step_idx : Int) -> Bool {
    if step_idx < 0 {
      return true
    }
    let (comb, prev_compound) = if step_idx == 0 {
      (selector.tail[0].0, selector.head)
    } else {
      (selector.tail[step_idx].0, selector.tail[step_idx - 1].1)
    }

    match comb {
      Child => {
        let parent_id = ctx.parents[curr_id]
        if parent_id >= 0 {
          if match_compound(ctx, parent_id, prev_compound) {
            match_prev(parent_id, step_idx - 1)
          } else {
            false
          }
        } else {
          false
        }
      }
      Descendant | Deep => {
        let mut ancestor_id = ctx.parents[curr_id]
        while ancestor_id >= 0 {
          if match_compound(ctx, ancestor_id, prev_compound) &&
            match_prev(ancestor_id, step_idx - 1) {
            return true
          }
          ancestor_id = ctx.parents[ancestor_id]
        }
        false
      }
      NextSibling => {
        let prev_id = ctx.prev_siblings[curr_id]
        if prev_id >= 0 {
          if match_compound(ctx, prev_id, prev_compound) {
            match_prev(prev_id, step_idx - 1)
          } else {
            false
          }
        } else {
          false
        }
      }
      SubsequentSibling => {
        let mut prev_id = ctx.prev_siblings[curr_id]
        while prev_id >= 0 {
          if match_compound(ctx, prev_id, prev_compound) &&
            match_prev(prev_id, step_idx - 1) {
            return true
          }
          prev_id = ctx.prev_siblings[prev_id]
        }
        false
      }
    }
  }

  match_prev(node_id, n - 1)
}

///|
/// A flattened indexed view of an XML document for fast DOM traversal during CSS matching.
pub(all) struct DocumentContext {
  elements : Array[@xml.Element]
  parents : Array[Int]
  prev_siblings : Array[Int]
}

///|
pub fn DocumentContext::build(doc : @xml.Document) -> DocumentContext {
  let elements : Array[@xml.Element] = []
  let parents : Array[Int] = []
  let prev_siblings : Array[Int] = []

  fn walk_node(
    node : @xml.Node,
    parent_idx : Int,
    prev_sibling_idx : Int,
  ) -> Int {
    match node {
      Element(el) => {
        let my_idx = elements.length()
        elements.push(el)
        parents.push(parent_idx)
        prev_siblings.push(prev_sibling_idx)

        let mut last_child_el_idx = -1
        for child in el.children {
          if child is Element(_) {
            last_child_el_idx = walk_node(child, my_idx, last_child_el_idx)
          }
        }
        my_idx
      }
      _ => prev_sibling_idx
    }
  }

  let mut last_root_idx = -1
  for child in doc.children {
    if child is Element(_) {
      last_root_idx = walk_node(child, -1, last_root_idx)
    }
  }

  { elements, parents, prev_siblings, }
}

///|
pub fn DocumentContext::find_all_matches(
  self : DocumentContext,
  selector : ComplexSelector,
) -> Array[Int] {
  let result : Array[Int] = []
  for i = 0; i < self.elements.length(); i = i + 1 {
    if match_complex(self, i, selector) {
      result.push(i)
    }
  }
  result
}
