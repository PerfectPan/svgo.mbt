///|
test "parse_args defaults" {
  let cfg = parse_args([]).unwrap()
  assert_eq(cfg.inputs.length(), 0)
  assert_eq(cfg.output, None)
  assert_false(cfg.recursive)
  assert_eq(cfg.precision, 3)
  assert_false(cfg.pretty)
  assert_true(cfg.multipass)
  assert_false(cfg.stats)
  assert_false(cfg.json)
  assert_eq(cfg.bench, 0)
  assert_false(cfg.quiet)
  assert_eq(cfg.disabled.length(), 0)
  assert_eq(cfg.enabled.length(), 0)
  assert_eq(cfg.explicit, None)
}

///|
test "parse_args collects input files" {
  let cfg = parse_args(["a.svg", "b.svg"]).unwrap()
  assert_eq(cfg.inputs.length(), 2)
  assert_eq(cfg.inputs[0], "a.svg")
  assert_eq(cfg.inputs[1], "b.svg")
}

///|
test "parse_args -o sets output" {
  let cfg = parse_args(["-o", "out.svg", "in.svg"]).unwrap()
  assert_eq(cfg.output, Some("out.svg"))
  assert_eq(cfg.inputs.length(), 1)
  assert_eq(cfg.inputs[0], "in.svg")
}

///|
test "parse_args --output sets output" {
  let cfg = parse_args(["--output", "out.svg"]).unwrap()
  assert_eq(cfg.output, Some("out.svg"))
}

///|
test "parse_args -r sets recursive" {
  let cfg = parse_args(["-r"]).unwrap()
  assert_true(cfg.recursive)
}

///|
test "parse_args --recursive sets recursive" {
  let cfg = parse_args(["--recursive"]).unwrap()
  assert_true(cfg.recursive)
}

///|
test "parse_args -p sets precision" {
  let cfg = parse_args(["-p", "5"]).unwrap()
  assert_eq(cfg.precision, 5)
}

///|
test "parse_args --precision sets precision" {
  let cfg = parse_args(["--precision", "1"]).unwrap()
  assert_eq(cfg.precision, 1)
}

///|
test "parse_args invalid precision falls back to 3" {
  let cfg = parse_args(["-p", "abc"]).unwrap()
  assert_eq(cfg.precision, 3)
}

///|
test "parse_args --pretty sets pretty" {
  let cfg = parse_args(["--pretty"]).unwrap()
  assert_true(cfg.pretty)
}

///|
test "parse_args --no-multipass disables multipass" {
  let cfg = parse_args(["--no-multipass"]).unwrap()
  assert_false(cfg.multipass)
}

///|
test "parse_args --stats sets stats" {
  let cfg = parse_args(["--stats"]).unwrap()
  assert_true(cfg.stats)
}

///|
test "parse_args --json sets json" {
  let cfg = parse_args(["--json"]).unwrap()
  assert_true(cfg.json)
}

///|
test "parse_args --bench sets bench count" {
  let cfg = parse_args(["--bench", "42"]).unwrap()
  assert_eq(cfg.bench, 42)
}

///|
test "parse_args -q sets quiet" {
  let cfg = parse_args(["-q"]).unwrap()
  assert_true(cfg.quiet)
}

///|
test "parse_args --quiet sets quiet" {
  let cfg = parse_args(["--quiet"]).unwrap()
  assert_true(cfg.quiet)
}

///|
test "parse_args --disable collects disabled plugins" {
  let cfg = parse_args([
    "--disable", "convertColors", "--disable", "removeComments",
  ]).unwrap()
  assert_eq(cfg.disabled.length(), 2)
  assert_eq(cfg.disabled[0], "convertColors")
  assert_eq(cfg.disabled[1], "removeComments")
}

///|
test "parse_args --enable collects enabled plugins" {
  let cfg = parse_args(["--enable", "removeDimensions"]).unwrap()
  assert_eq(cfg.enabled.length(), 1)
  assert_eq(cfg.enabled[0], "removeDimensions")
}

///|
test "parse_args --plugins sets explicit plugin list" {
  let cfg = parse_args(["--plugins", "convertColors,removeComments"]).unwrap()
  match cfg.explicit {
    Some(list) => {
      assert_eq(list.length(), 2)
      assert_eq(list[0], "convertColors")
      assert_eq(list[1], "removeComments")
    }
    None => assert_true(false)
  }
}

///|
test "parse_args --plugins trims whitespace" {
  let cfg = parse_args(["--plugins", " convertColors , removeComments "]).unwrap()
  match cfg.explicit {
    Some(list) => {
      assert_eq(list.length(), 2)
      assert_eq(list[0], "convertColors")
      assert_eq(list[1], "removeComments")
    }
    None => assert_true(false)
  }
}

///|
test "parse_args --param parses plugin.key=value" {
  let cfg = parse_args(["--param", "convertColors.currentColor=#fff"]).unwrap()
  let obj = match cfg.params.get("convertColors") {
    Some(Json::Object(o)) => o
    _ => {
      let m : Map[String, Json] = Map([])
      m
    }
  }
  assert_eq(obj.get("currentColor"), Some(Json::string("#fff")))
}

///|
test "parse_args unknown option returns error" {
  let r = parse_args(["--bogus"])
  assert_true(r is Err(_))
}

///|
test "parse_args malformed --param returns error" {
  let r = parse_args(["--param", "noequals"])
  assert_true(r is Err(_))
}

///|
test "last_index_of finds last occurrence" {
  assert_eq(last_index_of("a/b/c", '/'), 3)
  assert_eq(last_index_of("abc", '/'), -1)
  assert_eq(last_index_of("/a", '/'), 0)
  assert_eq(last_index_of("a/", '/'), 1)
  assert_eq(last_index_of("", '/'), -1)
}

///|
test "output_path_for single input writes to -o path" {
  assert_eq(output_path_for("in.svg", Some("out.svg"), false), Some("out.svg"))
}

///|
test "output_path_for no -o writes to stdout" {
  assert_eq(output_path_for("in.svg", None, false), None)
}

///|
test "output_path_for multi input treats -o as directory" {
  assert_eq(
    output_path_for("dir/in.svg", Some("out"), true),
    Some("out/in.svg"),
  )
}

///|
test "output_path_for multi input with nested path uses basename" {
  assert_eq(output_path_for("a/b/c.svg", Some("out"), true), Some("out/c.svg"))
}

///|
test "parse_args treats a bare dash as the stdin input" {
  match parse_args(["-"]) {
    Ok(cfg) => assert_eq(cfg.inputs, ["-"])
    Err(e) => fail("expected \"-\" to be an input, got error: \{e}")
  }
}

///|
test "parse_args still rejects unknown options" {
  match parse_args(["--nonsense"]) {
    Ok(_) => fail("expected --nonsense to be rejected")
    Err(e) => assert_eq(e, "unknown option --nonsense")
  }
}
