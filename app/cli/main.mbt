///|
const VERSION = "0.2.1"

///|
/// The installed command name, for the npm bin and the native binary alike.
const PROG = "svgo-mbt"

///|
/// Help after the title line. `app/website/gen.mjs` reads the flag table
/// between `options:` and `exit status:` for the site.
const USAGE =
  #|usage:
  #|  svgo-mbt [options] [input.svg ...]
  #|  svgo-mbt in.svg -o out.svg
  #|  svgo-mbt icons -r -o dist
  #|  cat in.svg | svgo-mbt > out.svg
  #|
  #|  With no input, or input "-", svgo-mbt reads stdin when it is not a terminal.
  #|  With -o, the files are written and a size report goes to stderr. Without it,
  #|  the optimized SVG goes to stdout and nothing else does.
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
  #|  --stats                 also print the size report when the SVG goes to stdout
  #|  --json                  print a JSON object {data, originalSize, size, passes, applied}
  #|                          per input instead of the report
  #|  --bench <n>             optimize each input n times in-process and report timing
  #|  -q, --quiet             do not print the size report
  #|  --version               print the version and exit
  #|  --list                  list available plugins
  #|  -h, --help              show this help
  #|
  #|exit status:
  #|  0  success
  #|  1  usage error
  #|  2  an input could not be read, parsed, optimized or written (names on stderr)

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
  // svgo_args is per target (io_js.mbt / io_native.mbt): process.argv carries
  // the runtime and the script on js, argv carries only the program on native.
  let args = svgo_args()
  if args.contains("-h") || args.contains("--help") {
    println(help(Term::detect(1)))
    return
  }
  if args.contains("--version") {
    println(VERSION)
    return
  }
  if args.contains("--list") {
    println(plugin_list(Term::detect(1), @svgo.list_plugins()))
    return
  }
  let cfg = match parse_args(args) {
    Ok(c) => c
    Err(msg) => {
      svgo_eprintln("\{PROG}: \{msg}")
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
  let config : @svgo.Config = {
    ..@svgo.Config::default(),
    plugins,
    params: cfg.params,
    precision: cfg.precision,
    multipass: cfg.multipass,
    pretty: cfg.pretty,
  }
  let inputs = collect_inputs(cfg.inputs, cfg.recursive)
  if inputs.length() == 0 {
    svgo_eprintln("\{PROG}: no input files")
    svgo_exit(1)
    return
  }
  let labels = inputs.map(i => if i == "-" { "<stdin>" } else { i })
  let ok = if cfg.bench > 0 {
    bench(inputs, labels, config, cfg.bench)
  } else {
    optimize_all(inputs, labels, config, cfg)
  }
  if !ok {
    svgo_exit(2)
  }
}

///|
/// Optimize every input, write or print it, and report on stderr. Returns
/// false when any input failed.
fn optimize_all(
  inputs : Array[String],
  labels : Array[String],
  config : @svgo.Config,
  cfg : CliConfig,
) -> Bool {
  let multi = inputs.length() > 1 || cfg.recursive
  // stdout may carry the SVG, so without -o the report is opt-in
  let show = !cfg.json && !cfg.quiet && (cfg.output is Some(_) || cfg.stats)
  let report = Report::new(Term::detect(2), labels)
  let start = svgo_clock_ms()
  let mut failed = 0
  let mut original = 0
  let mut size = 0
  for i, input in inputs {
    let label = labels[i]
    let out = output_path_for(label, cfg.output, multi)
    match optimize_one(input, out, config, cfg.json) {
      Ok(r) => {
        original += r.original_size
        size += r.size
        if show {
          svgo_eprintln(report.row(label, r))
          if inputs.length() == 1 && !r.applied.is_empty() {
            svgo_eprintln(report.plugins(r.applied))
          }
        }
      }
      Err(msg) => {
        failed += 1
        svgo_eprintln(report.error(label, msg))
        if show && inputs.length() > 1 {
          svgo_eprintln(report.failed_row(label))
        }
      }
    }
  }
  if show && inputs.length() > 1 {
    svgo_eprintln(
      report.totals(
        files=inputs.length(),
        failed~,
        original~,
        size~,
        elapsed_ms=svgo_clock_ms() - start,
      ),
    )
  }
  failed == 0
}

///|
/// Read, optimize and write one input; `out` is `None` for stdout. The error
/// is the message for the diagnostic line.
fn optimize_one(
  input : String,
  out : String?,
  config : @svgo.Config,
  json : Bool,
) -> Result[@svgo.Result, String] {
  let source = match read_input(input) {
    Some(s) => s
    None => return Err("cannot read the file")
  }
  let result = @svgo.optimize(source, config~) catch {
    e => return Err(e.to_string())
  }
  match out {
    Some(path) => {
      let idx = last_index_of(path, '/')
      if idx > 0 {
        ignore(svgo_mkdir_p(path[:idx].to_owned()))
      }
      if svgo_write_file(path, @utf8.encode(result.data)) != 0 {
        return Err("cannot write \{path}")
      }
      if json {
        println(to_json(result, data=false))
      }
    }
    None => println(if json { to_json(result, data=true) } else { result.data })
  }
  Ok(result)
}

///|
/// The input's text; `None` when a file cannot be read.
fn read_input(input : String) -> String? {
  if input == "-" {
    return Some(@utf8.decode_lossy(svgo_read_stdin()[:]))
  }
  let bytes = svgo_read_file(input)
  if bytes.length() == 0 {
    None
  } else {
    Some(@utf8.decode_lossy(bytes[:]))
  }
}

///|
/// Optimize each input `runs` times after one warm-up run and print a timing
/// row per input on stdout. Returns false when any input failed.
fn bench(
  inputs : Array[String],
  labels : Array[String],
  config : @svgo.Config,
  runs : Int,
) -> Bool {
  let report = Report::new(Term::detect(1), labels)
  let errors = Report::new(Term::detect(2), labels)
  let mut ok = true
  for i, input in inputs {
    let label = labels[i]
    let timed = match read_input(input) {
      None => Err("cannot read the file")
      Some(source) =>
        try {
          ignore(@svgo.optimize(source, config~))
          let start = svgo_clock_ms()
          for _ in 0..<runs {
            ignore(@svgo.optimize(source, config~))
          }
          Ok((svgo_clock_ms() - start, source))
        } catch {
          e => Err(e.to_string())
        }
    }
    match timed {
      Ok((total_ms, source)) =>
        println(
          report.bench(
            label,
            runs~,
            total_ms~,
            input_size=@utf8.encode(source).length(),
          ),
        )
      Err(msg) => {
        ok = false
        svgo_eprintln(errors.error(label, msg))
      }
    }
  }
  ok
}

///|
/// Title line with the version, then `USAGE` with its headings in bold.
fn help(term : Term) -> String {
  let lines = ["\{PROG} \{VERSION}, an SVG optimizer written in MoonBit", ""]
  for line in USAGE.split("\n") {
    let line = line.to_owned()
    lines.push(
      if line.has_suffix(":") && !line.has_prefix(" ") {
        term.bold(line)
      } else {
        line
      },
    )
  }
  lines.join("\n")
}

///|
/// The plugins in two groups, preset-default in execution order, then the
/// optional ones.
fn plugin_list(term : Term, plugins : Array[(String, String, Bool)]) -> String {
  let mut width = 0
  for p in plugins {
    width = width.max(p.0.length())
  }
  let lines : Array[String] = []
  for group in [(true, "preset-default"), (false, "optional")] {
    let (on, title) = group
    if !lines.is_empty() {
      lines.push("")
    }
    lines.push(term.bold(title))
    for p in plugins {
      let (name, description, enabled) = p
      if enabled == on {
        lines.push("  \{name.pad_end(width, ' ')}  \{description}")
      }
    }
  }
  lines.join("\n")
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
    if svgo_is_tty(0) {
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
          "\{PROG}: \{input} is a directory (use -r to process recursively)",
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
  // readdir order differs between file systems; sort so reports are stable
  let names = entries
    .split("\n")
    .filter(n => !n.is_empty())
    .map(n => n.to_owned())
    .to_array()
  names.sort_by((a, b) => a.lexical_compare(b))
  for name in names {
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
