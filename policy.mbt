///|
pub struct Policy {
  enter_percent : Double
  exit_percent : Double
  enter_intervals : Int32
  exit_intervals : Int32
  min_headroom_bytes : Int64
} derive(Debug, Eq)

///|
/// Percent thresholds apply independently to PSI some and throttled periods.
/// These defaults are heuristics; callers tune for their workload.
pub fn Policy::new(
  enter_percent~ : Double = 20.0,
  exit_percent~ : Double = 5.0,
  enter_intervals~ : Int32 = 2,
  exit_intervals~ : Int32 = 3,
  min_headroom_bytes~ : Int64 = 67108864L,
) -> Policy raise ParseError {
  guard exit_percent >= 0.0 &&
    enter_percent <= 100.0 &&
    exit_percent < enter_percent &&
    enter_intervals >= 1 &&
    enter_intervals <= 1000 &&
    exit_intervals >= 1 &&
    exit_intervals <= 1000 &&
    min_headroom_bytes >= 0L else {
    raise Invalid("invalid policy thresholds")
  }
  {
    enter_percent,
    exit_percent,
    enter_intervals,
    exit_intervals,
    min_headroom_bytes,
  }
}

///|
pub struct Controller {
  priv policy : Policy
  priv mut state : Admission
  priv mut high_streak : Int32
  priv mut low_streak : Int32
  priv mut identity : String?
  priv mut last_end_us : Int64?
}

///|
pub fn Controller::new(policy : Policy) -> Controller {
  {
    policy,
    state: Ready,
    high_streak: 0,
    low_streak: 0,
    identity: None,
    last_end_us: None,
  }
}

///|
/// Explicitly reset after a source/generation change. No invalid update mutates state.
pub fn Controller::reset(self : Controller) -> Unit {
  self.state = Ready
  self.high_streak = 0
  self.low_streak = 0
  self.identity = None
  self.last_end_us = None
}

///|
/// Consume contiguous intervals exactly once. Missing PSI prevents automatic recovery.
pub fn Controller::update(
  self : Controller,
  sample : Interval,
  limits : Budget,
) -> Advice raise DeltaError {
  if self.identity is Some(old) && old != sample.identity {
    raise IdentityChanged
  }
  if self.last_end_us is Some(old) && sample.end_us - sample.elapsed_us != old {
    raise InvalidInterval
  }
  let p = self.policy
  let reasons : Array[Reason] = []
  let mut low = true
  let mut missing = false
  let streams = [
    (sample.cpu_stall, CpuStall),
    (sample.memory_stall, MemoryStall),
    (sample.io_stall, IoStall),
  ]
  for item in streams {
    let (stall, reason) = item
    match stall {
      Some(value) => {
        if value.some_percent >= p.enter_percent {
          reasons.push(reason)
        }
        if value.some_percent > p.exit_percent {
          low = false
        }
      }
      None => {
        missing = true
        low = false
      }
    }
  }
  if sample.throttled_period_percent is Some(value) {
    if value >= p.enter_percent {
      reasons.push(CpuThrottled)
    }
    if value > p.exit_percent {
      low = false
    }
  }
  if limits.hard_headroom_bytes is Some(free) && free <= p.min_headroom_bytes {
    reasons.push(LowMemoryHeadroom)
    low = false
  }
  if limits.high_headroom_bytes is Some(0L) || sample.memory_high_events > 0L {
    reasons.push(MemoryHigh)
    low = false
  }
  if sample.memory_max_events > 0L {
    reasons.push(MemoryMax)
    low = false
  }
  let emergency = sample.oom_events > 0L || sample.oom_kills > 0L
  if emergency {
    reasons.push(OutOfMemory)
    low = false
  }
  let high = !reasons.is_empty()
  self.high_streak = if high {
    Int32::min(self.high_streak + 1, p.enter_intervals)
  } else {
    0
  }
  self.low_streak = if low {
    Int32::min(self.low_streak + 1, p.exit_intervals)
  } else {
    0
  }
  if emergency || self.high_streak >= p.enter_intervals {
    self.state = Shed
  }
  if self.state == Shed && self.low_streak >= p.exit_intervals {
    self.state = Ready
  }
  if self.state == Shed && !high {
    reasons.push(Recovering)
  }
  if missing {
    reasons.push(MissingPressure)
  }
  self.identity = Some(sample.identity)
  self.last_end_us = Some(sample.end_us)
  {
    state: self.state,
    reasons,
    high_streak: self.high_streak,
    low_streak: self.low_streak,
  }
}

///|
pub extend Policy with Debug::{to_repr}

///|
pub extend Policy with Eq::{equal, not_equal}
