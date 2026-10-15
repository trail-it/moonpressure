///|
pub(all) suberror ParseError {
  Invalid(String)
} derive(Debug, Eq)

///|
pub(all) suberror DeltaError {
  IdentityChanged
  InvalidInterval
  CounterReset(String)
  AvailabilityChanged(String)
} derive(Debug, Eq)

///|
pub(all) enum Limit {
  Unlimited
  Finite(Int64)
} derive(Debug, Eq)

///|
pub struct PressureLine {
  avg10 : Double
  avg60 : Double
  avg300 : Double
  total_us : Int64
} derive(Debug, Eq)

///|
pub struct Pressure {
  some : PressureLine
  full : PressureLine?
} derive(Debug, Eq)

///|
pub struct CpuMax {
  quota : Limit
  period_us : Int64
} derive(Debug, Eq)

///|
pub struct Throttle {
  periods : Int64
  throttled_periods : Int64
  throttled_us : Int64
} derive(Debug, Eq)

///|
pub struct CpuStat {
  usage_us : Int64
  throttle : Throttle?
} derive(Debug, Eq)

///|
pub struct MemoryEvents {
  high : Int64
  max : Int64
  oom : Int64
  oom_kill : Int64
} derive(Debug, Eq)

///|
pub struct Layer {
  name : String
  cpu : CpuMax?
  memory_max : Limit?
  memory_high : Limit?
  memory_current : Int64?
} derive(Debug, Eq)

///|
pub struct Budget {
  quota_cores : Double?
  hard_headroom_bytes : Int64?
  high_headroom_bytes : Int64?
  quota_source : String?
  hard_source : String?
  high_source : String?
} derive(Debug, Eq)

///|
pub struct Snapshot {
  identity : String
  time_us : Int64
  cpu : CpuStat
  memory_current : Int64
  events : MemoryEvents
  cpu_pressure : Pressure?
  memory_pressure : Pressure?
  io_pressure : Pressure?
} derive(Debug, Eq)

///|
pub struct StallDelta {
  some_percent : Double
  full_percent : Double?
} derive(Debug, Eq)

///|
pub struct Interval {
  identity : String
  end_us : Int64
  elapsed_us : Int64
  cpu_cores_used : Double
  throttled_period_percent : Double?
  throttled_us : Int64?
  memory_current_bytes : Int64
  memory_high_events : Int64
  memory_max_events : Int64
  oom_events : Int64
  oom_kills : Int64
  cpu_stall : StallDelta?
  memory_stall : StallDelta?
  io_stall : StallDelta?
} derive(Debug, Eq)

///|
pub(all) enum Admission {
  Ready
  Shed
} derive(Debug, Eq)

///|
pub(all) enum Reason {
  CpuStall
  MemoryStall
  IoStall
  CpuThrottled
  LowMemoryHeadroom
  MemoryHigh
  MemoryMax
  OutOfMemory
  Recovering
  MissingPressure
} derive(Debug, Eq)

///|
pub struct Advice {
  state : Admission
  reasons : Array[Reason]
  high_streak : Int32
  low_streak : Int32
} derive(Debug, Eq)

///|
pub extend ParseError with Debug::{to_repr}

///|
pub extend ParseError with Eq::{equal, not_equal}

///|
pub extend DeltaError with Debug::{to_repr}

///|
pub extend DeltaError with Eq::{equal, not_equal}

///|
pub extend Limit with Debug::{to_repr}

///|
pub extend Limit with Eq::{equal, not_equal}

///|
pub extend PressureLine with Debug::{to_repr}

///|
pub extend PressureLine with Eq::{equal, not_equal}

///|
pub extend Pressure with Debug::{to_repr}

///|
pub extend Pressure with Eq::{equal, not_equal}

///|
pub extend CpuMax with Debug::{to_repr}

///|
pub extend CpuMax with Eq::{equal, not_equal}

///|
pub extend Throttle with Debug::{to_repr}

///|
pub extend Throttle with Eq::{equal, not_equal}

///|
pub extend CpuStat with Debug::{to_repr}

///|
pub extend CpuStat with Eq::{equal, not_equal}

///|
pub extend MemoryEvents with Debug::{to_repr}

///|
pub extend MemoryEvents with Eq::{equal, not_equal}

///|
pub extend Layer with Debug::{to_repr}

///|
pub extend Layer with Eq::{equal, not_equal}

///|
pub extend Budget with Debug::{to_repr}

///|
pub extend Budget with Eq::{equal, not_equal}

///|
pub extend Snapshot with Debug::{to_repr}

///|
pub extend Snapshot with Eq::{equal, not_equal}

///|
pub extend StallDelta with Debug::{to_repr}

///|
pub extend StallDelta with Eq::{equal, not_equal}

///|
pub extend Interval with Debug::{to_repr}

///|
pub extend Interval with Eq::{equal, not_equal}

///|
pub extend Admission with Debug::{to_repr}

///|
pub extend Admission with Eq::{equal, not_equal}

///|
pub extend Reason with Debug::{to_repr}

///|
pub extend Reason with Eq::{equal, not_equal}

///|
pub extend Advice with Debug::{to_repr}

///|
pub extend Advice with Eq::{equal, not_equal}
