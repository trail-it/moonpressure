///|
pub fn Resources::to_json(self : Resources) -> Json {
  {
    "memory_bytes": Json(self.memory_bytes.to_string()),
    "cpu_millis": Json(self.cpu_millis.to_string()),
  }
}

///|
pub fn Gate::label(self : Gate) -> String {
  match self {
    Open => "open"
    Pressure => "pressure"
    Unknown => "unknown"
  }
}

///|
pub fn Scope::to_json(self : Scope) -> Json {
  {
    "id": Json(self.id),
    "parent": match self.parent {
      None => Json::null()
      Some(p) => Json(p)
    },
    "capacity": self.capacity.to_json(),
    "gate": Json(self.gate.label()),
  }
}

///|
pub fn Job::to_json(self : Job) -> Json {
  {
    "id": Json(self.id),
    "value": Json(self.value.to_string()),
    "allocations": Json(
      self.allocations.map(a => {
        "scope": Json(a.scope),
        "resources": a.resources.to_json(),
      }),
    ),
  }
}

///|
pub fn Blocker::to_json(self : Blocker) -> Json {
  match self {
    Memory(scope, requested, available) =>
      {
        "kind": Json("memory"),
        "scope": Json(scope),
        "requested": Json(requested.to_string()),
        "available": Json(available.to_string()),
      }
    Cpu(scope, requested, available) =>
      {
        "kind": Json("cpu"),
        "scope": Json(scope),
        "requested": Json(requested.to_string()),
        "available": Json(available.to_string()),
      }
    Pressure(scope) => { "kind": Json("pressure"), "scope": Json(scope) }
    UnknownPressure(scope) =>
      { "kind": Json("unknown_pressure"), "scope": Json(scope) }
  }
}

///|
pub fn Balance::to_json(self : Balance) -> Json {
  {
    "scope": Json(self.scope),
    "capacity": self.capacity.to_json(),
    "reserved": self.reserved.to_json(),
    "free": self.free.to_json(),
    "deficit": self.deficit.to_json(),
    "gate": Json(self.gate.label()),
  }
}

///|
/// Admission schema 1 is separate from diagnostic JSON. All Int64 values are decimal strings.
pub fn Plan::to_json(self : Plan) -> Json {
  {
    "schema_version": Json(1),
    "revision": Json(self.revision.to_string()),
    "selected": Json(self.selected()),
    "total_value": Json(self.value.to_string()),
    "explored_states": Json(self.explored),
    "deferred": Json(
      self.deferred.map(d => {
        "job_id": Json(d.job_id),
        "blockers": Json(d.blockers.map(b => b.to_json())),
      }),
    ),
  }
}
