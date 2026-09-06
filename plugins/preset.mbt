///|
/// The default plugin pipeline, in svgo's preset-default order (the plugins
/// that are not implemented yet are listed in the README).
pub let preset_default : Array[Plugin] = [
  remove_doctype, remove_xml_proc_inst, remove_comments, remove_metadata, remove_editors_ns_data,
  cleanup_attrs, remove_desc, cleanup_ids, remove_useless_defs, cleanup_numeric_values,
  convert_colors, remove_unknowns_and_defaults, remove_useless_stroke_and_fill, remove_hidden_elems,
  remove_empty_text, convert_shape_to_path, convert_ellipse_to_circle, collapse_groups,
  convert_path_data, convert_transform, merge_paths, remove_empty_attrs, remove_empty_containers,
  remove_unused_ns, sort_attrs,
]

///|
/// Plugins that are available but not enabled by default.
pub let optional_plugins : Array[Plugin] = [remove_dimensions, remove_title]

///|
/// Look a plugin up by its svgo name (for example `"convertPathData"`).
pub fn find_plugin(name : String) -> Plugin? {
  for p in preset_default {
    if p.name == name {
      return Some(p)
    }
  }
  for p in optional_plugins {
    if p.name == name {
      return Some(p)
    }
  }
  None
}
