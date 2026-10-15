///|
pub struct Observation {
  snapshot : @moonpressure.Snapshot
  limits : @moonpressure.Budget
  layers : Array[@moonpressure.Layer]
  priv raw : Map[String, String]
}

///|
fn load(
  root : String,
  relative : String,
  file : String,
  raw : Map[String, String],
) -> String? raise {
  let key = if relative == "" { file } else { "\{relative}/\{file}" }
  let value = Some(read_text("\{root}/\{key}")) catch {
    System(_, 2) => None
    error => raise error
  }
  if value is Some(text) {
    raw[key] = text
  }
  value
}

///|
fn required(raw : Map[String, String], key : String) -> String raise ReadError {
  match raw.get(key) {
    Some(text) => text
    None => raise System(key, 2)
  }
}

///|
/// Explicit mount root and a relative cgroup path; walks only visible ancestors.
/// Does not auto-detect mount namespaces or mutate any kernel control file.
pub fn collect(root : String, relative : String) -> Observation raise {
  guard root.has_prefix("/") &&
    root.length() <= 4096 &&
    !root.contains("\u0000") &&
    (root == "/" || !root.has_suffix("/")) &&
    !relative.has_prefix("/") else {
    raise InvalidPath
  }
  let parts = relative.split("/").collect()
  guard parts.length() <= 255 else { raise InvalidPath }
  if relative != "" {
    for part in parts {
      guard part != "" && part != "." && part != ".." else { raise InvalidPath }
    }
  }
  let leaf_path = if relative == "" { root } else { "\{root}/\{relative}" }
  let id = identity(leaf_path)
  let raw : Map[String, String] = Map([])
  let layers : Array[@moonpressure.Layer] = []
  let mut path = relative
  for ;; {
    let directory = if path == "" { root } else { "\{root}/\{path}" }
    let before = identity(directory)
    let cpu_max = load(root, path, "cpu.max", raw)
    let memory_max = load(root, path, "memory.max", raw)
    let memory_high = load(root, path, "memory.high", raw)
    let memory_current = load(root, path, "memory.current", raw)
    layers.push(
      @moonpressure.Layer::parse(
        if path == "" {
          "/"
        } else {
          path
        },
        cpu_max?,
        memory_max?,
        memory_high?,
        memory_current?,
      ),
    )
    guard identity(directory) == before else { raise ChangedDuringRead }
    if path == "" {
      break
    }
    let segments = path.split("/").collect()
    path = segments[:segments.length() - 1].map(x => x.to_owned()).join("/")
  }
  for
    file in [
      "cpu.stat", "memory.events", "cpu.pressure", "memory.pressure", "io.pressure",
    ] {
    ignore(load(root, relative, file, raw))
  }
  let key = fn(file : String) {
    if relative == "" {
      file
    } else {
      "\{relative}/\{file}"
    }
  }
  let snapshot = @moonpressure.Snapshot::parse(
    id,
    monotonic_us(),
    cpu_stat=required(raw, key("cpu.stat")),
    memory_current=required(raw, key("memory.current")),
    memory_events=required(raw, key("memory.events")),
    cpu_pressure?=raw.get(key("cpu.pressure")),
    memory_pressure?=raw.get(key("memory.pressure")),
    io_pressure?=raw.get(key("io.pressure")),
  )
  guard identity(leaf_path) == id else { raise ChangedDuringRead }
  { snapshot, limits: @moonpressure.budget(layers), layers, raw, }
}

///|
/// Raw texts are opt-in for local oracle/replay use and can contain host details.
pub fn Observation::to_json(
  self : Observation,
  include_raw~ : Bool = false,
) -> Json {
  let result : Map[String, Json] = Map([
    ("schema", 1),
    ("snapshot", self.snapshot.to_json()),
    ("budget", self.limits.to_json()),
  ])
  if include_raw {
    result["raw"] = Json(self.raw)
  }
  Json::object(result)
}
