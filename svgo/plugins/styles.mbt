///|
/// CSS-related plugins: mergeStyles, inlineStyles, minifyStyles.

///|
/// Merge multiple `<style>` elements into one.
pub let merge_styles : Plugin = {
  name: "mergeStyles",
  description: "merge multiple style elements into one",
  run: (doc, _) => {
    guard doc.root() is Some(root) else { return false }
    let mut changed = false
    let mut collected_styles = ""
    let mut first_style : @xml.Element? = None
    let mut is_cdata = false

    fn walk(elem : @xml.Element) -> Unit {
      let mut i = 0
      while i < elem.children.length() {
        match elem.children[i] {
          Element(child) => {
            if child.name == "foreignObject" {
              i = i + 1
              continue
            }
            if child.name != "style" {
              walk(child)
              i = i + 1
              continue
            }

            // Check style type attribute
            match child.attrs.get("type") {
              Some(t) if !t.is_empty() && t != "text/css" => {
                i = i + 1
                continue
              }
              _ => ()
            }

            // Extract css content
            let mut css = ""
            for c in child.children {
              match c {
                Text(t) => css = css + t
                CData(cdata) => {
                  is_cdata = true
                  css = css + cdata
                }
                _ => ()
              }
            }

            // Remove empty style elements
            if css.trim().is_empty() {
              ignore(elem.children.remove(i))
              changed = true
              continue
            }

            let css_clean = css

            // Collect css and wrap with media query if present in attribute
            let css_wrapped = match child.attrs.get("media") {
              Some(m) => {
                child.attrs.remove("media")
                changed = true
                "@media " + m + "{" + css_clean + "}"
              }
              None => css_clean
            }

            // Combine collected styles in first style element
            match first_style {
              None => {
                first_style = Some(child)
                collected_styles = css_wrapped
                i = i + 1
              }
              Some(fs) => {
                ignore(elem.children.remove(i))
                collected_styles = collected_styles + css_wrapped
                let new_child : @xml.Node = if is_cdata {
                  CData(collected_styles)
                } else {
                  Text(collected_styles)
                }
                fs.children.clear()
                fs.children.push(new_child)
                changed = true
              }
            }
          }
          _ => i = i + 1
        }
      }
    }

    walk(root)
    changed
  },
}

///|
/// Inline styles from `<style>` elements into matching elements' `style` attributes.
pub let inline_styles : Plugin = {
  name: "inlineStyles",
  description: "inline styles from style elements into style attributes",
  run: (doc, ctx) => run_inline_styles(doc, ctx),
}

///|
/// Minify styles in `<style>` elements and `style` attributes.
pub let minify_styles : Plugin = {
  name: "minifyStyles",
  description: "minify styles in style elements and style attributes",
  run: (doc, ctx) => run_minify_styles(doc, ctx),
}

///|
fn run_minify_styles(doc : @xml.Document, ctx : Context) -> Bool {
  let root = match doc.root() {
    Some(r) => r
    None => return false
  }
  let mut changed = false

  // Check if there are scripts or event attributes that prevent removing unused styles
  let mut has_scripts = false
  fn check_scripts(elem : @xml.Element) -> Unit {
    if elem.name == "script" {
      has_scripts = true
      return
    }
    for k, _ in elem.attrs {
      if is_event_attribute(k) {
        has_scripts = true
        return
      }
    }
    for c in elem.children {
      match c {
        Element(child) => check_scripts(child)
        _ => ()
      }
    }
  }
  check_scripts(root)

  // Parse usage options. `usage.force: true` forces usage-based minification
  // even when scripts or event handlers are present.
  let usage_param = ctx.param("usage")
  let force = match usage_param {
    Some(Object(map)) =>
      match map.get("force") {
        Some(True) => true
        _ => false
      }
    _ => false
  }

  let usage_opt : @css.Usage? = if has_scripts && !force {
    None
  } else {
    match usage_param {
      Some(False) => None
      Some(Object(map)) => {
        let tags_enabled = match map.get("tags") {
          Some(False) => false
          _ => true
        }
        let ids_enabled = match map.get("ids") {
          Some(False) => false
          _ => true
        }
        let classes_enabled = match map.get("classes") {
          Some(False) => false
          _ => true
        }
        let tags : Set[String] = Set([], capacity=0)
        let ids : Set[String] = Set([], capacity=0)
        let classes : Set[String] = Set([], capacity=0)
        fn collect_usage(elem : @xml.Element) -> Unit {
          tags.add(elem.name)
          match elem.attrs.get("id") {
            Some(id) => ids.add(id)
            None => ()
          }
          match elem.attrs.get("class") {
            Some(cls) =>
              for c in cls.split(" ") {
                let s = c.trim().to_owned()
                if !s.is_empty() {
                  classes.add(s)
                }
              }
            None => ()
          }
          for ch in elem.children {
            match ch {
              Element(child) => collect_usage(child)
              _ => ()
            }
          }
        }
        collect_usage(root)
        Some({
          tags: if tags_enabled {
            Some(tags)
          } else {
            None
          },
          ids: if ids_enabled {
            Some(ids)
          } else {
            None
          },
          classes: if classes_enabled {
            Some(classes)
          } else {
            None
          },
        })
      }
      _ => {
        let tags : Set[String] = Set([], capacity=0)
        let ids : Set[String] = Set([], capacity=0)
        let classes : Set[String] = Set([], capacity=0)
        fn collect_usage(elem : @xml.Element) -> Unit {
          tags.add(elem.name)
          match elem.attrs.get("id") {
            Some(id) => ids.add(id)
            None => ()
          }
          match elem.attrs.get("class") {
            Some(cls) =>
              for c in cls.split(" ") {
                let s = c.trim().to_owned()
                if !s.is_empty() {
                  classes.add(s)
                }
              }
            None => ()
          }
          for ch in elem.children {
            match ch {
              Element(child) => collect_usage(child)
              _ => ()
            }
          }
        }
        collect_usage(root)
        Some({ tags: Some(tags), ids: Some(ids), classes: Some(classes), })
      }
    }
  }

  // 1. Minify inline style attributes
  fn walk_elements(elem : @xml.Element) -> Unit {
    match elem.attrs.get("style") {
      Some(style_val) => {
        let decls = @css.parse_declarations(style_val)
        let minified_decls = @css.minify_declarations(decls)
        let new_style = @css.serialize_declarations(minified_decls)
        if new_style != style_val {
          if new_style.is_empty() {
            elem.attrs.remove("style")
          } else {
            elem.attrs["style"] = new_style
          }
          changed = true
        }
      }
      None => ()
    }
    for c in elem.children {
      match c {
        Element(child) => walk_elements(child)
        _ => ()
      }
    }
  }
  walk_elements(root)

  // 2. Minify <style> elements
  let empty_styles : Array[@xml.Element] = []
  fn process_style_elements(elem : @xml.Element) -> Unit {
    if elem.name == "foreignObject" {
      return
    }
    if elem.name == "style" {
      let sb = StringBuilder()
      for c in elem.children {
        match c {
          Text(t) => sb.write_string(t)
          CData(cd) => sb.write_string(cd)
          _ => ()
        }
      }
      let raw_css = sb.to_string()
      if raw_css.is_empty() {
        // Originally empty <style>: keep it (serializes to <style/>).
        elem.children.clear()
      } else {
        let sheet = @css.parse_stylesheet(raw_css)
        let min_sheet = @css.minify_stylesheet_with_usage(sheet, usage_opt)
        let min_css = min_sheet.to_css()
        if min_css.is_empty() {
          // All rules were removed (e.g. unused selectors): drop the element.
          empty_styles.push(elem)
        } else {
          elem.children.clear()
          // Use CDATA when the CSS contains characters that would otherwise
          // need XML escaping (<, >, &), matching svgo/csso's behaviour.
          let needs_cdata = min_css.contains("<") ||
            min_css.contains(">") ||
            min_css.contains("&")
          if needs_cdata {
            elem.children.push(CData(min_css))
          } else {
            elem.children.push(Text(min_css))
          }
          if min_css != raw_css {
            changed = true
          }
        }
      }
    }
    for c in elem.children {
      match c {
        Element(child) => process_style_elements(child)
        _ => ()
      }
    }
  }
  process_style_elements(root)

  if empty_styles.length() > 0 {
    fn is_empty_style(elem : @xml.Element) -> Bool {
      for es in empty_styles {
        if physical_equal(es, elem) {
          return true
        }
      }
      false
    }
    fn remove_empty(parent : @xml.Element) -> Unit {
      let mut i = 0
      while i < parent.children.length() {
        match parent.children[i] {
          Element(child) =>
            if is_empty_style(child) {
              parent.children.remove(i) |> ignore
              changed = true
            } else {
              remove_empty(child)
              i = i + 1
            }
          _ => i = i + 1
        }
      }
    }
    remove_empty(root)
  }

  changed
}

///|
fn is_event_attribute(name : String) -> Bool {
  name.has_prefix("on")
}
