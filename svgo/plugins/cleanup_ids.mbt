///|
/// Remove unused ids and minify referenced ids, preserving dynamic documents.
pub let cleanup_ids : Plugin = {
  name: "cleanupIds",
  description: "remove unused ids and minify referenced ids",
  run: cleanup_ids_run,
}

///|
fn cleanup_ids_run(doc : @xml.Document, ctx : Context) -> Bool {
  let force = ctx.param_bool("force", false)
  let remove = ctx.param_bool("remove", true)
  let minify = ctx.param_bool("minify", true)
  let preserved = Set::from_array(ctx.param_strings("preserve"))
  let prefixes = ctx.param_strings("preservePrefixes")
  fn keep(id : String) -> Bool {
    preserved.contains(id) ||
    prefixes.iter().any(prefix => id.has_prefix(prefix))
  }
  let mut dynamic = false
  if !force {
    doc.each_element((e, _) => {
      if (e.name == "style" && !e.children.is_empty()) ||
        e.name == "script" ||
        e.attrs.iter().any(kv => kv.0.has_prefix("on")) {
        dynamic = true
      }
    })
  }
  if dynamic {
    return false
  }
  let nodes : Map[String, @xml.Element] = Map([])
  let references : Set[String] = Set([])
  let attributes : Array[(@xml.Element, String, String, Array[IdReference])] = []
  let mut changed = false
  fn collect(e : @xml.Element) {
    // Standalone defs are commonly exported for use by another document.
    if !force &&
      e.name == "svg" &&
      e.children.iter().all(n => n is Element(x) && x.name == "defs") {
      return
    }
    for entry in e.attrs.to_array() {
      let (name, value) = entry
      if name == "id" {
        if nodes.contains(value) {
          e.attrs.remove(name)
          changed = true
        } else {
          nodes[value] = e
        }
      } else if name == "begin" || name == "end" || value.contains_code_unit(35) {
        // 35 is '#': apart from SMIL timing (`begin="r2.click"`) every
        // reference form carries one, so d, width, transform, ... are
        // skipped without scanning
        let refs = id_references(name, value)
        if !refs.is_empty() {
          for reference in refs {
            references.add(reference.id)
          }
          attributes.push((e, name, value, refs))
        }
      }
    }
    for child in e.children {
      if child is Element(x) {
        collect(x)
      }
    }
  }
  if doc.root() is Some(root) {
    collect(root)
  }
  let renamed : Map[String, String] = Map([])
  let reserved : Set[String] = Set([])
  for id in references {
    if !nodes.contains(id) {
      reserved.add(id)
    }
  }
  for id, _ in nodes {
    if keep(id) || (!remove && !references.contains(id)) {
      reserved.add(id)
    }
  }
  let mut next = 0
  for id in references {
    if nodes.contains(id) && minify && !keep(id) {
      let mut short = short_id(next)
      next += 1
      while reserved.contains(short) || keep(short) {
        short = short_id(next)
        next += 1
      }
      renamed[id] = short
    }
  }
  // Apply all replacements against the original values, so swapped ids and
  // multiple references in one attribute cannot cascade into one another.
  for id, node in nodes {
    if renamed.get(id) is Some(short) {
      if short != id {
        node.attrs["id"] = short
        changed = true
      }
    } else if remove && !references.contains(id) && !keep(id) {
      node.attrs.remove("id")
      changed = true
    }
  }
  for entry in attributes {
    let (node, name, value, refs) = entry
    let sb = StringBuilder()
    let mut cursor = 0
    for reference in refs {
      sb.write_string(value[cursor:reference.start].to_owned())
      sb.write_string(
        renamed
        .get(reference.id)
        .unwrap_or(value[reference.start:reference.end].to_owned()),
      )
      cursor = reference.end
    }
    sb.write_string(value[cursor:].to_owned())
    let rewritten = sb.to_string()
    if rewritten != value {
      node.attrs[name] = rewritten
      changed = true
    }
  }
  changed
}

///|
fn short_id(index : Int) -> String {
  let alphabet = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
  let tail = alphabet[index % 52:index % 52 + 1].to_owned()
  if index < 52 {
    tail
  } else {
    short_id(index / 52 - 1) + tail
  }
}
