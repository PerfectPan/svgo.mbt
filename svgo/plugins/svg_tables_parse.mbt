///|
/// Pipe-separated records, comma-separated lists, key=value defaults.
/// Shared groups are parsed once; element rules are expanded on demand.
priv struct SvgTables {
  attr_groups : Map[String, Array[String]]
  group_defaults : Map[String, Map[String, String]]
  content_groups : Map[String, Array[String]]
  elements : Map[String, Array[StringView]]
  expanded : Map[String, SvgElementTables]
  known_elements : Set[String]
  presentation_non_inheritable : Set[String]
  inheritable : Set[String]
  path_elems : Set[String]
  references_props : Set[String]
  deprecated_groups : Map[String, DeprecatedAttrs]
}

///|
priv struct DeprecatedAttrs {
  safe : Set[String]
  unsafe_attrs : Set[String]
}

///|
priv struct SvgElementTables {
  allowed_attrs : Set[String]
  defaults : Map[String, String]
  allowed_children : Set[String]
  deprecated_safe : Set[String]
  deprecated_unsafe : Set[String]
}

///|
let svg_tables_cache : Ref[SvgTables?] = { val: None, }

///|
fn table_list(raw : StringView) -> Array[String] {
  raw.split(",").filter(s => !s.is_empty()).map(s => s.to_owned()).to_array()
}

///|
fn table_pairs(raw : StringView) -> Map[String, String] {
  let values : Map[String, String] = Map([])
  for entry in raw.split(",") {
    if entry.to_owned().split_once("=") is Some((key, value)) {
      values[key.to_owned()] = value.to_owned()
    }
  }
  values
}

///|
fn table_groups(raw : String) -> Map[String, Array[String]] {
  let groups : Map[String, Array[String]] = Map([])
  for row in raw.split("\n") {
    if row.to_owned().split_once("|") is Some((name, values)) {
      groups[name.to_owned()] = table_list(values)
    }
  }
  groups
}

///|
fn deprecated_groups(raw : String) -> Map[String, DeprecatedAttrs] {
  let groups : Map[String, DeprecatedAttrs] = Map([])
  for row in raw.split("\n") {
    let fields = row.split("|").to_array()
    if fields.length() < 3 {
      continue
    }
    let name = fields[0].to_owned()
    groups[name] = {
      safe: Set::from_array(table_list(fields[1])),
      unsafe_attrs: Set::from_array(table_list(fields[2])),
    }
  }
  groups
}

///|
fn svg_tables() -> SvgTables {
  if svg_tables_cache.val is Some(tables) {
    return tables
  }
  let group_defaults : Map[String, Map[String, String]] = Map([])
  for row in svg_attr_defaults_data.split("\n") {
    if row.to_owned().split_once("|") is Some((name, values)) {
      group_defaults[name.to_owned()] = table_pairs(values)
    }
  }
  let tables : SvgTables = {
    attr_groups: table_groups(svg_attr_groups_data),
    group_defaults,
    content_groups: table_groups(svg_content_groups_data),
    elements: Map([]),
    expanded: Map([]),
    known_elements: Set([]),
    presentation_non_inheritable: Set::from_array(
      table_list(svg_non_inheritable_data[:]),
    ),
    inheritable: Set::from_array(table_list(svg_inheritable_data[:])),
    path_elems: Set::from_array(table_list(svg_path_elems_data[:])),
    references_props: Set::from_array(table_list(svg_references_props_data[:])),
    deprecated_groups: deprecated_groups(svg_deprecated_groups_data),
  }
  for row in svg_elements_data.split("\n") {
    let fields = row.split("|").to_array()
    let name = fields[0].to_owned()
    tables.elements[name] = fields
    tables.known_elements.add(name)
  }
  svg_tables_cache.val = Some(tables)
  tables
}

///|
fn SvgTables::element(self : SvgTables, name : String) -> SvgElementTables? {
  if self.expanded.get(name) is Some(element) {
    return Some(element)
  }
  guard self.elements.get(name) is Some(fields) else { return None }
  let attrs = Set::from_array(table_list(fields[2]))
  let defaults = table_pairs(fields[3])
  // Preserve the previous generator's precedence: own defaults first,
  // then each attribute group's defaults in upstream declaration order.
  for group in table_list(fields[1]) {
    if self.attr_groups.get(group) is Some(values) {
      for value in values {
        attrs.add(value)
      }
    }
    if self.group_defaults.get(group) is Some(values) {
      for key, value in values {
        defaults[key] = value
      }
    }
  }
  let children = Set::from_array(table_list(fields[5]))
  for group in table_list(fields[4]) {
    if self.content_groups.get(group) is Some(values) {
      for value in values {
        children.add(value)
      }
    }
  }
  let deprecated_safe = if fields.length() > 6 {
    Set::from_array(table_list(fields[6]))
  } else {
    Set([])
  }
  let deprecated_unsafe = if fields.length() > 7 {
    Set::from_array(table_list(fields[7]))
  } else {
    Set([])
  }
  // merge group-level deprecated attributes into the element's sets
  for group in table_list(fields[1]) {
    if self.deprecated_groups.get(group) is Some(dep) {
      for name in dep.safe {
        deprecated_safe.add(name)
      }
      for name in dep.unsafe_attrs {
        deprecated_unsafe.add(name)
      }
    }
  }
  let element : SvgElementTables = {
    allowed_attrs: attrs,
    defaults,
    allowed_children: children,
    deprecated_safe,
    deprecated_unsafe,
  }
  self.expanded[name] = element
  Some(element)
}
