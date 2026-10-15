///|
fn[T : ToJson] optional_json(value : T?) -> Json {
  match value {
    None => Json::null()
    Some(v) => Json(v)
  }
}

///|
fn stall_json(value : StallDelta?) -> Json {
  match value {
    None => Json::null()
    Some(v) =>
      {
        "some_percent": Json(v.some_percent),
        "full_percent": optional_json(v.full_percent),
      }
  }
}

///|
fn pressure_json(value : Pressure?) -> Json {
  match value {
    None => Json::null()
    Some(p) => {
      let full = match p.full {
        None => Json::null()
        Some(v) =>
          {
            "avg10": Json(v.avg10),
            "avg60": Json(v.avg60),
            "avg300": Json(v.avg300),
            "total_us": Json(v.total_us.to_string()),
          }
      }
      {
        "some": {
          "avg10": Json(p.some.avg10),
          "avg60": Json(p.some.avg60),
          "avg300": Json(p.some.avg300),
          "total_us": Json(p.some.total_us.to_string()),
        },
        "full": full,
      }
    }
  }
}

///|
/// Schema 1 uses decimal strings for Int64 counters to preserve JSON precision.
pub fn Snapshot::to_json(self : Snapshot) -> Json {
  let throttle = match self.cpu.throttle {
    None => Json::null()
    Some(t) =>
      {
        "periods": Json(t.periods.to_string()),
        "throttled_periods": Json(t.throttled_periods.to_string()),
        "throttled_us": Json(t.throttled_us.to_string()),
      }
  }
  {
    "identity": Json(self.identity),
    "time_us": Json(self.time_us.to_string()),
    "cpu_usage_us": Json(self.cpu.usage_us.to_string()),
    "throttle": throttle,
    "memory_current_bytes": Json(self.memory_current.to_string()),
    "memory_events": {
      "high": Json(self.events.high.to_string()),
      "max": Json(self.events.max.to_string()),
      "oom": Json(self.events.oom.to_string()),
      "oom_kill": Json(self.events.oom_kill.to_string()),
    },
    "cpu_pressure": pressure_json(self.cpu_pressure),
    "memory_pressure": pressure_json(self.memory_pressure),
    "io_pressure": pressure_json(self.io_pressure),
  }
}

///|
pub fn Budget::to_json(self : Budget) -> Json {
  let hard = self.hard_headroom_bytes.map(x => x.to_string())
  let high = self.high_headroom_bytes.map(x => x.to_string())
  {
    "quota_cores_upper_bound": optional_json(self.quota_cores),
    "hard_headroom_bytes": optional_json(hard),
    "high_headroom_bytes": optional_json(high),
    "quota_source": optional_json(self.quota_source),
    "hard_source": optional_json(self.hard_source),
    "high_source": optional_json(self.high_source),
  }
}

///|
pub fn Interval::to_json(self : Interval) -> Json {
  {
    "elapsed_us": Json(self.elapsed_us.to_string()),
    "cpu_cores_used": Json(self.cpu_cores_used),
    "throttled_period_percent": optional_json(self.throttled_period_percent),
    "throttled_us": optional_json(self.throttled_us.map(x => x.to_string())),
    "memory_high_events": Json(self.memory_high_events.to_string()),
    "memory_max_events": Json(self.memory_max_events.to_string()),
    "oom_events": Json(self.oom_events.to_string()),
    "oom_kills": Json(self.oom_kills.to_string()),
    "cpu_stall": stall_json(self.cpu_stall),
    "memory_stall": stall_json(self.memory_stall),
    "io_stall": stall_json(self.io_stall),
  }
}

///|
pub fn Admission::label(self : Admission) -> String {
  match self {
    Ready => "ready"
    Shed => "shed"
  }
}

///|
pub fn Reason::label(self : Reason) -> String {
  match self {
    CpuStall => "cpu_stall"
    MemoryStall => "memory_stall"
    IoStall => "io_stall"
    CpuThrottled => "cpu_throttled_periods"
    LowMemoryHeadroom => "low_memory_headroom"
    MemoryHigh => "memory_high"
    MemoryMax => "memory_max"
    OutOfMemory => "out_of_memory"
    Recovering => "recovering"
    MissingPressure => "missing_pressure"
  }
}

///|
pub fn Advice::to_json(self : Advice) -> Json {
  {
    "state": Json(self.state.label()),
    "reasons": Json(self.reasons.map(x => x.label())),
    "high_streak": Json(self.high_streak),
    "low_streak": Json(self.low_streak),
  }
}
