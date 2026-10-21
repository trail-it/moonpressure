///|
suberror ProtocolError {
  InvalidInput
}

///|
extern "C" fn line_raw() -> Bytes = "mp_example_line"

///|
extern "C" fn flush_raw() -> Int32 = "mp_example_flush"

///|
fn read_line() -> String? raise {
  let bytes = line_raw()
  guard bytes.length() >= 4 else { raise InvalidInput }
  let status = bytes[0].to_int() |
    (bytes[1].to_int() << 8) |
    (bytes[2].to_int() << 16) |
    (bytes[3].to_int() << 24)
  if status == -1 {
    return None
  }
  guard status == 0 else { raise InvalidInput }
  Some(@utf8.decode(bytes[4:]))
}

///|
fn send(value : Json) -> Unit {
  println(value.stringify())
  if flush_raw() != 0 {
    abort("output closed")
  }
}

///|
fn field(json : Json, name : String) -> Json raise ProtocolError {
  guard json is Object(fields) && fields.get(name) is Some(value) else {
    raise InvalidInput
  }
  value
}

///|
fn text(json : Json) -> String raise ProtocolError {
  guard json is String(s) else { raise InvalidInput }
  s
}

///|
fn array(json : Json) -> Array[Json] raise ProtocolError {
  guard json is Array(items) else { raise InvalidInput }
  items
}

///|
fn number(json : Json) -> Int64 raise {
  @pressure.parse_counter(text(json))
}

///|
fn gate(json : Json) -> @admission.Gate raise ProtocolError {
  match text(json) {
    "open" => Open
    "pressure" => Pressure
    "unknown" => Unknown
    _ => raise InvalidInput
  }
}

///|
fn resources(json : Json) -> @admission.Resources raise {
  @admission.Resources::new(
    memory_bytes=number(field(json, "memory_bytes")),
    cpu_millis=number(field(json, "cpu_millis")),
  )
}

///|
fn scopes(json : Json) -> Array[@admission.Scope] raise {
  array(json).map(s => {
    let parent = match field(s, "parent") {
      Null => None
      value => Some(text(value))
    }
    @admission.Scope::new(
      text(field(s, "id")),
      resources(field(s, "capacity")),
      parent?,
      gate=gate(field(s, "gate")),
    )
  })
}

///|
fn job(json : Json) -> @admission.Job raise {
  let allocations = array(field(json, "allocations")).map(a => {
    @admission.Allocation::new(
      text(field(a, "scope")),
      resources(field(a, "resources")),
    )
  })
  @admission.Job::new(
    text(field(json, "id")),
    value=number(field(json, "value")),
    allocations,
  )
}

///|
fn snapshot(
  d : @driver.Dispatcher,
  actions : Array[@driver.Action],
  changed : Bool,
) -> Json {
  {
    "ok": Json(true),
    "actions": Json(actions.map(a => a.to_json())),
    "changed": Json(changed),
    "tasks": Json(d.tasks().map(t => t.to_json())),
    "balances": Json(d.balances().map(b => b.to_json())),
    "revision": Json(d.revision().to_string()),
  }
}

///|
fn error_name(error : Error) -> String {
  match error {
    @driver.StaleAttempt => "stale_attempt"
    @driver.UnknownJob(_) => "unknown_job"
    @driver.Invalid(_) => "invalid"
    @admission.Invalid(_) => "invalid"
    _ => "invalid_request"
  }
}
