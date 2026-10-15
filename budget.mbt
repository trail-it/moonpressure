///|
/// A visible cgroup layer. Missing controller files are distinct from `max`.
pub fn Layer::parse(
  name : String,
  cpu_max? : String,
  memory_max? : String,
  memory_high? : String,
  memory_current? : String,
) -> Layer raise ParseError {
  guard name.length() > 0 && name.length() <= 4096 else {
    raise Invalid("invalid layer name")
  }
  let cpu = match cpu_max {
    Some(text) => Some(parse_cpu_max(text))
    None => None
  }
  let max = match memory_max {
    Some(text) => Some(parse_limit(text))
    None => None
  }
  let high = match memory_high {
    Some(text) => Some(parse_limit(text))
    None => None
  }
  let current = match memory_current {
    Some(text) => Some(parse_counter(text))
    None => None
  }
  if (max is Some(Finite(_)) || high is Some(Finite(_))) && current is None {
    raise Invalid("finite memory limit needs current usage")
  }
  { name, cpu, memory_max: max, memory_high: high, memory_current: current, }
}

///|
fn remaining(limit : Int64, current : Int64) -> Int64 {
  if current >= limit {
    0L
  } else {
    limit - current
  }
}

///|
/// Reduces visible layers, including ancestors' *own* current usage.
/// CPU result is a quota upper bound, not affinity-aware guaranteed capacity.
pub fn budget(layers : ArrayView[Layer]) -> Budget raise ParseError {
  guard layers.length() > 0 && layers.length() <= 256 else {
    raise Invalid("expected 1..256 hierarchy layers")
  }
  let mut quota : Double? = None
  let mut hard : Int64? = None
  let mut high : Int64? = None
  let mut quota_source : String? = None
  let mut hard_source : String? = None
  let mut high_source : String? = None
  let seen : Map[String, Bool] = Map([])
  for layer in layers {
    guard !seen.contains(layer.name) else {
      raise Invalid("duplicate hierarchy layer")
    }
    seen[layer.name] = true
    if layer.cpu is Some({ quota: Finite(q), period_us: p, }) {
      let cores = q.to_double() / p.to_double()
      if quota is None || (quota is Some(old) && cores < old) {
        quota = Some(cores)
        quota_source = Some(layer.name)
      }
    }
    if layer.memory_max is Some(Finite(max)) &&
      layer.memory_current is Some(current) {
      let free = remaining(max, current)
      if hard is None || (hard is Some(old) && free < old) {
        hard = Some(free)
        hard_source = Some(layer.name)
      }
    }
    if layer.memory_high is Some(Finite(max)) &&
      layer.memory_current is Some(current) {
      let free = remaining(max, current)
      if high is None || (high is Some(old) && free < old) {
        high = Some(free)
        high_source = Some(layer.name)
      }
    }
  }
  {
    quota_cores: quota,
    hard_headroom_bytes: hard,
    high_headroom_bytes: high,
    quota_source,
    hard_source,
    high_source,
  }
}
