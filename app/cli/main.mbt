///|
const VERSION = "0.1.0"

///|
const USAGE =
  #|svgo.mbt - SVG optimizer written in MoonBit
  #|
  #|usage: svgo [options] [input.svg ...]
  #|       svgo -o out.svg in.svg
  #|       cat in.svg | svgo > out.svg
  #|       svgo --list
  #|
  #|With no input file (or input "-"), svgo reads from stdin when stdin is not
  #|a terminal. With no -o, the result is written to stdout.
  #|
  #|options:
  #|  -o, --output <file>     write the result to a file (default: stdout);
  #|                          with multiple inputs or -r, a directory to write into
  #|  -r, --recursive         process directories recursively
  #|  -p, --precision <n>     decimal places to keep (default 3)
  #|  --pretty                indent the output
  #|  --no-multipass          run the plugin pipeline once
  #|  --disable <plugin>      skip a plugin (repeatable)
  #|  --enable <plugin>       add an optional plugin such as removeDimensions (repeatable)
  #|  --plugins <a,b,c>       run exactly these plugins, in this order
  #|  --param <plugin>.<key>=<value>  set a plugin parameter (repeatable)
  #|  --stats                 print size statistics (to stderr when output is stdout)
  #|  --json                  print a JSON object {data, originalSize, size, passes, applied}
  #|  --bench <n>             optimize the input n times in-process and report timing
  #|  -q, --quiet             suppress the stats line
  #|  --version               print the version and exit
  #|  --list                  list available plugins
  #|  -h, --help              show this help
  #|
  #|exit codes: 0 success, 1 usage error, 2 an input failed to parse or optimize.

///|
struct CliConfig {
  inputs : Array[String]
  output : String?
  recursive : Bool
  precision : Int
  pretty : Bool
  multipass : Bool
  stats : Bool
  json : Bool
  bench : Int
  quiet : Bool
  params : Map[String, Json]
  disabled : Array[String]
  enabled : Array[String]
  explicit : Array[String]?
}

///|
fn main {
  // On the js backend `@env.args()` is `process.argv` = [node, script, ...args];
  // on native it is [program, ...args]. Detect the js backend by the first arg
  // being the node executable and skip both leading elements there.
  let raw = @env.args()
  let skip = if raw.length() > 0 && raw[0].contains("node") { 2 } else { 1 }
  let args = raw[skip:].to_owned()
  if args.contains("-h") || args.contains("--help") {
    println(USAGE)
    return
  }
  if args.contains("--version") {
    println(VERSION)
    return
  }
  if args.contains("--list") {
    for p in @svgo.list_plugins() {
      let (name, desc, on) = p
      println("\{if on { "*" } else { " " }} \{name.pad_end(28, ' ')} \{desc}")
    }
    println("\n* = enabled by default")
    return
  }
  let cfg = match parse_args(args) {
    Ok(c) => c
    Err(msg) => {
      svgo_eprintln("svgo: \{msg}")
      svgo_exit(1)
      return
    }
  }
  let plugins = match cfg.explicit {
    Some(list) => list
    None => {
      let list = @svgo.Config::default().plugins.filter(p => {
        !cfg.disabled.contains(p)
      })
      list.append(cfg.enabled[:])
      list
    }
  }
  let inputs = collect_inputs(cfg.inputs, cfg.recursive)
  if inputs.length() == 0 {
    svgo_eprintln("svgo: no input files")
    svgo_exit(1)
    return
  }
  let failures : Array[String] = []
  for input in inputs {
    let (source, label) = match input {
      "-" => {
        let bytes = svgo_read_stdin()
        (@utf8.decode_lossy(bytes[:]), "<stdin>")
      }
      path => {
        let bytes = svgo_read_file(path)
        if bytes.length() == 0 {
          svgo_eprintln("svgo: cannot read \{path}")
          failures.push(path)
          continue
        }
        (@utf8.decode_lossy(bytes[:]), path)
      }
    }
    if cfg.bench > 0 {
      let config : @svgo.Config = {
        plugins,
        params: cfg.params,
        precision: cfg.precision,
        multipass: cfg.multipass,
        pretty: cfg.pretty,
      }
      ignore(
        @svgo.optimize(source, config~) catch {
          _ => {
            failures.push(label)
            continue
          }
        },
      )
      let start = @env.now()
      for _ in 0..<cfg.bench {
        ignore(
          @svgo.optimize(source, config~) catch {
            _ => {
              failures.push(label)
              break
            }
          },
        )
      }
      let elapsed_ms = (@env.now() - start).to_double()
      let per = (elapsed_ms / cfg.bench.to_double() * 1000.0).round() / 1000.0
      println("\{label}: \{cfg.bench} runs in \{elapsed_ms} ms, \{per} ms/run")
      continue
    }
    let result = @svgo.optimize(source, config={
      plugins,
      params: cfg.params,
      precision: cfg.precision,
      multipass: cfg.multipass,
      pretty: cfg.pretty,
    }) catch {
      e => {
        svgo_eprintln("svgo: \{label}: \{e}")
        failures.push(label)
        continue
      }
    }
    let out_path = output_path_for(
      label,
      cfg.output,
      inputs.length() > 1 || cfg.recursive,
    )
    match out_path {
      Some(out) => {
        if inputs.length() > 1 || cfg.recursive {
          // ensure the output directory exists
          let idx = last_index_of(out, '/')
          if idx > 0 {
            let dir = out[:idx].to_owned()
            ignore(svgo_mkdir_p(dir))
          }
        }
        if svgo_write_file(out, @utf8.encode(result.data)) != 0 {
          svgo_eprintln("svgo: cannot write \{out}")
          failures.push(label)
          continue
        }
        if cfg.json {
          println(to_json(result, data=false))
        } else if cfg.stats && !cfg.quiet {
          report(label, result)
        }
      }
      None =>
        if cfg.json {
          println(to_json(result, data=true))
        } else {
          println(result.data)
          if cfg.stats && !cfg.quiet {
            report_stderr(label, result)
          }
        }
    }
  }
  if failures.length() > 0 {
    svgo_eprintln("svgo: failed: \{failures.join(", ")}")
    svgo_exit(2)
  }
}

///|
fn parse_args(args : Array[String]) -> Result[CliConfig, String] {
  let inputs : Array[String] = []
  let mut output : String? = None
  let mut recursive = false
  let mut precision = 3
  let mut pretty = false
  let mut multipass = true
  let mut stats = false
  let mut json = false
  let mut bench = 0
  let mut quiet = false
  let params : Map[String, Json] = Map([])
  let disabled : Array[String] = []
  let enabled : Array[String] = []
  let mut explicit : Array[String]? = None
  let mut i = 0
  while i < args.length() {
    match args[i] {
      "-o" | "--output" => {
        output = args.get(i + 1)
        i += 1
      }
      "-r" | "--recursive" => recursive = true
      "-p" | "--precision" => {
        precision = @string.parse_int(args.get(i + 1).unwrap_or("3")) catch {
          _ => 3
        }
        i += 1
      }
      "--pretty" => pretty = true
      "--no-multipass" => multipass = false
      "--stats" => stats = true
      "--json" => json = true
      "-q" | "--quiet" => quiet = true
      "--bench" => {
        bench = @string.parse_int(args.get(i + 1).unwrap_or("0")) catch {
          _ => 0
        }
        i += 1
      }
      "--disable" => {
        disabled.push(args.get(i + 1).unwrap_or(""))
        i += 1
      }
      "--enable" => {
        enabled.push(args.get(i + 1).unwrap_or(""))
        i += 1
      }
      "--param" => {
        guard args.get(i + 1) is Some(arg) && parse_param(arg, params) else {
          return Err("expected --param <plugin>.<key>=<value>")
        }
        i += 1
      }
      "--plugins" => {
        explicit = Some(
          args
          .get(i + 1)
          .unwrap_or("")
          .split(",")
          .map(p => p.trim().to_owned())
          .filter(p => !p.is_empty())
          .to_array(),
        )
        i += 1
      }
      // a bare "-" is the documented way to say stdin, not an option
      "-" => inputs.push("-")
      a =>
        if a.has_prefix("-") {
          return Err("unknown option \{a}")
        } else {
          inputs.push(a)
        }
    }
    i += 1
  }
  Ok({
    inputs,
    output,
    recursive,
    precision,
    pretty,
    multipass,
    stats,
    json,
    bench,
    quiet,
    params,
    disabled,
    enabled,
    explicit,
  })
}

///|
/// Expand the user-supplied input list into a flat list of file paths.
/// Directories are expanded when `recursive` is true; "-" is kept as a marker
/// for stdin. When no inputs are given and stdin is not a TTY, stdin is used.
fn collect_inputs(raw : Array[String], recursive : Bool) -> Array[String] {
  if raw.length() == 0 {
    if svgo_stdin_is_tty() {
      return []
    }
    return ["-"]
  }
  let out : Array[String] = []
  for input in raw {
    if input == "-" {
      out.push("-")
    } else if svgo_is_dir(input) {
      if recursive {
        expand_dir(input, out)
      } else {
        svgo_eprintln(
          "svgo: \{input} is a directory (use -r to process recursively)",
        )
      }
    } else {
      out.push(input)
    }
  }
  out
}

///|
/// Recursively collect SVG files under `dir` into `out`.
fn expand_dir(dir : String, out : Array[String]) -> Unit {
  let entries = svgo_list_dir(dir)
  if entries.is_empty() {
    return
  }
  for name in entries.split("\n") {
    if name.is_empty() {
      continue
    }
    let path = "\{dir}/\{name}"
    if svgo_is_dir(path) {
      expand_dir(path, out)
    } else if path.to_lower().has_suffix(".svg") {
      out.push(path)
    }
  }
}

///|
/// Return the index of the last occurrence of `ch` in `s`, or -1 if absent.
fn last_index_of(s : String, ch : Char) -> Int {
  let mut idx = -1
  let mut i = 0
  for c in s {
    if c == ch {
      idx = i
    }
    i += 1
  }
  idx
}

///|
/// Decide where to write the output for a given input. Returns `None` to write
/// to stdout. When there are multiple inputs or recursion, a single `-o` is
/// treated as a directory.
fn output_path_for(input : String, output : String?, multi : Bool) -> String? {
  match output {
    None => None
    Some(out) =>
      if multi {
        // output names a directory; write next to the input's basename there
        let base = input.split("/").last().unwrap_or(input)
        Some("\{out}/\{base}")
      } else {
        Some(out)
      }
  }
}

///|
fn report(path : String, r : @svgo.Result) -> Unit {
  let pct = (r.saved_percent() * 10.0).round() / 10.0
  println(
    "\{path}: \{r.original_size} -> \{r.size} bytes (-\{pct}%), \{r.passes} pass(es), plugins: \{r.applied.join(", ")}",
  )
}

///|
/// Like `report` but on stderr, used when the optimized SVG goes to stdout.
fn report_stderr(path : String, r : @svgo.Result) -> Unit {
  let pct = (r.saved_percent() * 10.0).round() / 10.0
  svgo_eprintln(
    "\{path}: \{r.original_size} -> \{r.size} bytes (-\{pct}%), \{r.passes} pass(es), plugins: \{r.applied.join(", ")}",
  )
}

///|
/// Machine readable result, the same shape the wasm build returns.
fn to_json(r : @svgo.Result, data~ : Bool) -> String {
  let obj : Map[String, Json] = {
    "originalSize": r.original_size.to_json(),
    "size": r.size.to_json(),
    "passes": r.passes.to_json(),
    "applied": r.applied.map(s => s.to_json()).to_json(),
  }
  if data {
    obj["data"] = r.data.to_json()
  }
  Json::object(obj).stringify()
}
