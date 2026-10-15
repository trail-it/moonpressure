///|
pub fn Snapshot::parse(
  identity : String,
  time_us : Int64,
  cpu_stat~ : String,
  memory_current~ : String,
  memory_events~ : String,
  cpu_pressure? : String,
  memory_pressure? : String,
  io_pressure? : String,
) -> Snapshot raise ParseError {
  guard identity.length() > 0 && identity.length() <= 4096 && time_us >= 0L else {
    raise Invalid("invalid snapshot identity or time")
  }
  let cpu_p = match cpu_pressure {
    Some(text) => Some(parse_pressure(text))
    None => None
  }
  let memory_p = match memory_pressure {
    Some(text) => Some(parse_pressure(text))
    None => None
  }
  let io_p = match io_pressure {
    Some(text) => Some(parse_pressure(text))
    None => None
  }
  {
    identity,
    time_us,
    cpu: parse_cpu_stat(cpu_stat),
    memory_current: parse_counter(memory_current),
    events: parse_memory_events(memory_events),
    cpu_pressure: cpu_p,
    memory_pressure: memory_p,
    io_pressure: io_p,
  }
}

///|
fn difference(old : Int64, now : Int64, key : String) -> Int64 raise DeltaError {
  guard now >= old else { raise CounterReset(key) }
  now - old
}

///|
fn stall_delta(
  old : Pressure?,
  now : Pressure?,
  elapsed : Int64,
  key : String,
) -> StallDelta? raise DeltaError {
  match (old, now) {
    (None, None) => None
    (Some(a), Some(b)) => {
      let some = difference(a.some.total_us, b.some.total_us, key)
      let full = match (a.full, b.full) {
        (None, None) => None
        (Some(x), Some(y)) =>
          Some(
            difference(x.total_us, y.total_us, key).to_double() /
            elapsed.to_double() *
            100.0,
          )
        _ => raise AvailabilityChanged(key)
      }
      // Sequential kernel reads can slightly exceed the timestamp interval.
      // Preserve that evidence rather than silently clamping it to 100%.
      Some({
        some_percent: some.to_double() / elapsed.to_double() * 100.0,
        full_percent: full,
      })
    }
    _ => raise AvailabilityChanged(key)
  }
}

///|
/// Only compare the same cgroup generation and a positive <=60s interval.
pub fn interval(old : Snapshot, now : Snapshot) -> Interval raise DeltaError {
  guard old.identity == now.identity else { raise IdentityChanged }
  guard now.time_us > old.time_us else { raise InvalidInterval }
  let elapsed = now.time_us - old.time_us
  guard elapsed <= 60000000L else { raise InvalidInterval }
  let usage = difference(old.cpu.usage_us, now.cpu.usage_us, "usage_usec")
  let (throttle, throttled_us) = match (old.cpu.throttle, now.cpu.throttle) {
    (None, None) => (None, None)
    (Some(a), Some(b)) => {
      let periods = difference(a.periods, b.periods, "nr_periods")
      let throttled = difference(
        a.throttled_periods,
        b.throttled_periods,
        "nr_throttled",
      )
      guard throttled <= periods else {
        raise CounterReset("inconsistent throttle delta")
      }
      let duration = difference(
        a.throttled_us,
        b.throttled_us,
        "throttled_usec",
      )
      let pct = if periods == 0L {
        None
      } else {
        Some(throttled.to_double() / periods.to_double() * 100.0)
      }
      (pct, Some(duration))
    }
    _ => raise AvailabilityChanged("cpu.stat throttle")
  }
  {
    identity: now.identity,
    end_us: now.time_us,
    elapsed_us: elapsed,
    cpu_cores_used: usage.to_double() / elapsed.to_double(),
    throttled_period_percent: throttle,
    throttled_us,
    memory_current_bytes: now.memory_current,
    memory_high_events: difference(
      old.events.high,
      now.events.high,
      "memory.high",
    ),
    memory_max_events: difference(old.events.max, now.events.max, "memory.max"),
    oom_events: difference(old.events.oom, now.events.oom, "memory.oom"),
    oom_kills: difference(
      old.events.oom_kill,
      now.events.oom_kill,
      "memory.oom_kill",
    ),
    cpu_stall: stall_delta(
      old.cpu_pressure,
      now.cpu_pressure,
      elapsed,
      "cpu PSI",
    ),
    memory_stall: stall_delta(
      old.memory_pressure,
      now.memory_pressure,
      elapsed,
      "memory PSI",
    ),
    io_stall: stall_delta(old.io_pressure, now.io_pressure, elapsed, "io PSI"),
  }
}
