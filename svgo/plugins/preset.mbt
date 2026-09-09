///|
/// The default plugin pipeline, in svgo's preset-default order (the plugins
/// that are not implemented yet are listed in the README). `remove_desc` sits
/// last because svgo removes descriptions after the structural passes.
pub let preset_default : Array[Plugin] = [
  remove_doctype, remove_xml_proc_inst, remove_comments, remove_deprecated_attrs,
  remove_metadata, remove_editors_ns_data, cleanup_attrs, cleanup_ids, remove_useless_defs,
  cleanup_numeric_values, convert_colors, remove_unknowns_and_defaults, remove_non_inheritable_group_attrs,
  remove_useless_stroke_and_fill, cleanup_enable_background, remove_hidden_elems,
  remove_empty_text, convert_shape_to_path, convert_ellipse_to_circle, move_elems_attrs_to_group,
  collapse_groups, convert_path_data, convert_transform, merge_paths, remove_empty_attrs,
  remove_empty_containers, remove_unused_ns, sort_attrs, sort_defs_children, remove_desc,
]

///|
/// Plugins that are available but not enabled by default.
///
/// `move_group_attrs_to_elems` is implemented and passes svgo's cases for it,
/// but it stays off here: pushing a group's `transform` onto its children lets
/// `convert_path_data` bake the matrix into every path, which lengthens the
/// coordinates and leaves formerly identical siblings unmergeable. Measured
/// over the eleven files in `svgo/testdata/` and `packages/compare/corpus/`,
/// enabling it costs 15,859 bytes on the Ghostscript tiger and saves 48 bytes
/// everywhere else combined (it does help small icons: 27 bytes on the Sketch
/// export, 21 on the twelve-fold world map). svgo's own output shows the same effect (68,101
/// bytes with it, 52,029 without), so this is a deliberate deviation, not a
/// missing plugin. Enable it with `--enable moveGroupAttrsToElems`.
pub let optional_plugins : Array[Plugin] = [
  remove_dimensions, remove_title, move_group_attrs_to_elems,
]

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
