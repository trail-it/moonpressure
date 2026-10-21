///|
pub(all) suberror AdmissionError {
  Invalid(String)
  StalePlan
  UnknownLease(String)
} derive(Debug, Eq)

///|
pub(all) enum Gate {
  Open
  Pressure
  Unknown
} derive(Debug, Eq)

///|
pub struct Resources {
  memory_bytes : Int64
  cpu_millis : Int64
} derive(Debug, Eq)

///|
pub fn Resources::new(
  memory_bytes~ : Int64,
  cpu_millis~ : Int64,
) -> Resources raise AdmissionError {
  guard memory_bytes >= 0L && cpu_millis >= 0L else {
    raise Invalid("negative resource amount")
  }
  { memory_bytes, cpu_millis, }
}

///|
pub struct Scope {
  id : String
  parent : String?
  capacity : Resources
  gate : Gate
} derive(Debug, Eq)

///|
pub fn Scope::new(
  id : String,
  capacity : Resources,
  parent? : String,
  gate~ : Gate = Open,
) -> Scope raise AdmissionError {
  valid_id(id)
  if parent is Some(p) {
    valid_id(p)
  }
  { id, parent, capacity, gate, }
}

///|
pub fn Gate::from_advice(advice : @pressure.Advice) -> Gate {
  if advice.reasons.contains(MissingPressure) {
    Unknown
  } else if advice.state == Shed {
    Pressure
  } else {
    Open
  }
}

///|
/// Policy ceilings are required even for unlimited controllers. CPU is not idle capacity.
pub fn Scope::from_layer(
  layer : @pressure.Layer,
  ceiling : Resources,
  parent? : String,
  gate~ : Gate = Unknown,
) -> Scope raise AdmissionError {
  guard layer.memory_max is Some(maximum) &&
    layer.memory_current is Some(current) &&
    layer.cpu is Some(cpu) else {
    raise Invalid("missing controller data; cannot derive a scope")
  }
  let memory_bytes = match maximum {
    Unlimited => ceiling.memory_bytes
    Finite(limit) =>
      Int64::min(
        ceiling.memory_bytes,
        if current >= limit {
          0L
        } else {
          limit - current
        },
      )
  }
  let cpu_millis = match cpu.quota {
    Unlimited => ceiling.cpu_millis
    Finite(quota) => {
      // Compare against a policy ceiling first, then use quotient/remainder to avoid q*1000 overflow.
      let whole = quota / cpu.period_us
      let fractional = quota % cpu.period_us
      if whole > ceiling.cpu_millis / 1000L {
        ceiling.cpu_millis
      } else {
        let whole_millis = whole * 1000L
        let remainder_millis = if fractional > 9223372036854775807L / 1000L {
          raise Invalid("CPU period too large for exact millicore conversion")
        } else {
          fractional * 1000L / cpu.period_us
        }
        if remainder_millis >= ceiling.cpu_millis - whole_millis {
          ceiling.cpu_millis
        } else {
          whole_millis + remainder_millis
        }
      }
    }
  }
  Scope::new(layer.name, { memory_bytes, cpu_millis, }, parent?, gate~)
}

///|
pub struct Allocation {
  scope : String
  resources : Resources
} derive(Debug, Eq)

///|
pub fn Allocation::new(
  scope : String,
  resources : Resources,
) -> Allocation raise AdmissionError {
  valid_id(scope)
  guard resources.memory_bytes > 0L || resources.cpu_millis > 0L else {
    raise Invalid("allocation must request a resource")
  }
  { scope, resources, }
}

///|
/// All allocations of one job are admitted together. Value is caller policy, not measured throughput.
pub struct Job {
  id : String
  value : Int64
  allocations : Array[Allocation]
} derive(Debug, Eq)

///|
pub fn Job::new(
  id : String,
  value~ : Int64,
  allocations : ArrayView[Allocation],
) -> Job raise AdmissionError {
  valid_id(id)
  guard value > 0L &&
    value <= 1000000000L &&
    allocations.length() > 0 &&
    allocations.length() <= 16 else {
    raise Invalid("expected value 1..1e9 and 1..16 allocations")
  }
  { id, value, allocations: allocations.to_owned(), }
}

///|
pub(all) enum Blocker {
  Memory(String, Int64, Int64)
  Cpu(String, Int64, Int64)
  Pressure(String)
  UnknownPressure(String)
} derive(Debug, Eq)

///|
pub struct Deferred {
  job_id : String
  blockers : Array[Blocker]
} derive(Debug, Eq)

///|
pub struct Balance {
  scope : String
  capacity : Resources
  reserved : Resources
  free : Resources
  deficit : Resources
  gate : Gate
} derive(Debug, Eq)

///|
fn valid_id(id : String) -> Unit raise AdmissionError {
  guard id.length() > 0 && id.length() <= 256 else {
    raise Invalid("ID length must be 1..256")
  }
}

///|
// Explicit UTF-16 lexicographic ordering, independent of runtime String::compare implementation.
fn compare_ids(a : String, b : String) -> Int32 {
  for i in 0..<Int32::min(a.length(), b.length()) {
    if a[i] < b[i] {
      return -1
    }
    if a[i] > b[i] {
      return 1
    }
  }
  a.length() - b.length()
}

///|
fn checked_add(a : Int64, b : Int64) -> Int64 raise AdmissionError {
  guard b <= 9223372036854775807L - a else {
    raise Invalid("resource sum overflows Int64")
  }
  a + b
}

///|
fn add_resources(
  a : Resources,
  b : Resources,
) -> Resources raise AdmissionError {
  {
    memory_bytes: checked_add(a.memory_bytes, b.memory_bytes),
    cpu_millis: checked_add(a.cpu_millis, b.cpu_millis),
  }
}

///|
fn subtract_resources(a : Resources, b : Resources) -> Resources {
  {
    memory_bytes: a.memory_bytes - b.memory_bytes,
    cpu_millis: a.cpu_millis - b.cpu_millis,
  }
}

///|
fn free_resources(capacity : Resources, used : Resources) -> Resources {
  {
    memory_bytes: if used.memory_bytes >= capacity.memory_bytes {
      0L
    } else {
      capacity.memory_bytes - used.memory_bytes
    },
    cpu_millis: if used.cpu_millis >= capacity.cpu_millis {
      0L
    } else {
      capacity.cpu_millis - used.cpu_millis
    },
  }
}

///|
fn zero_resources() -> Resources {
  { memory_bytes: 0L, cpu_millis: 0L, }
}

///|
pub extend AdmissionError with Debug::{to_repr}

///|
pub extend AdmissionError with Eq::{equal, not_equal}

///|
pub extend Gate with Debug::{to_repr}

///|
pub extend Gate with Eq::{equal, not_equal}

///|
pub extend Resources with Debug::{to_repr}

///|
pub extend Resources with Eq::{equal, not_equal}

///|
pub extend Scope with Debug::{to_repr}

///|
pub extend Scope with Eq::{equal, not_equal}

///|
pub extend Allocation with Debug::{to_repr}

///|
pub extend Allocation with Eq::{equal, not_equal}

///|
pub extend Job with Debug::{to_repr}

///|
pub extend Job with Eq::{equal, not_equal}

///|
pub extend Blocker with Debug::{to_repr}

///|
pub extend Blocker with Eq::{equal, not_equal}

///|
pub extend Deferred with Debug::{to_repr}

///|
pub extend Deferred with Eq::{equal, not_equal}

///|
pub extend Balance with Debug::{to_repr}

///|
pub extend Balance with Eq::{equal, not_equal}
