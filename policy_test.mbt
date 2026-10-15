///|
fn sample(
  t : Int64,
  stall : Int64,
  oom~ : Int64 = 0L,
  missing~ : Bool = false,
) -> @moonpressure.Snapshot raise {
  let p = if missing {
    None
  } else {
    Some("some avg10=0 avg60=0 avg300=0 total=\{stall}")
  }
  @moonpressure.Snapshot::parse(
    "synthetic:controller",
    t,
    cpu_stat="usage_usec 0",
    memory_current="100",
    memory_events="high 0\nmax 0\noom \{oom}\noom_kill 0",
    cpu_pressure?=p,
    memory_pressure?=p,
    io_pressure?=p,
  )
}

///|
test "sustained high enters Shed and sustained low recovers" {
  let c = @moonpressure.Controller::new(@moonpressure.Policy::new())
  let b = @moonpressure.budget([@moonpressure.Layer::parse("unlimited")])
  let a = sample(0L, 0L)
  let d = sample(1000000L, 300000L)
  let e = sample(2000000L, 600000L)
  assert_eq(c.update(@moonpressure.interval(a, d), b).state, Ready)
  assert_eq(c.update(@moonpressure.interval(d, e), b).state, Shed)
  let f = sample(3000000L, 600000L)
  let g = sample(4000000L, 600000L)
  let h = sample(5000000L, 600000L)
  assert_eq(c.update(@moonpressure.interval(e, f), b).state, Shed)
  assert_eq(c.update(@moonpressure.interval(f, g), b).state, Shed)
  assert_eq(c.update(@moonpressure.interval(g, h), b).state, Ready)
}

///|
test "OOM enters immediately duplicate interval rejects without mutating state" {
  let c = @moonpressure.Controller::new(@moonpressure.Policy::new())
  let b = @moonpressure.budget([@moonpressure.Layer::parse("x")])
  let a = sample(0L, 0L)
  let d = sample(1000000L, 0L, oom=1L)
  let delta = @moonpressure.interval(a, d)
  let result = c.update(delta, b)
  assert_eq(result.state, Shed)
  assert_true(result.reasons.contains(OutOfMemory))
  assert_true(
    try {
      ignore(c.update(delta, b))
      false
    } catch {
      _ => true
    },
  )
  let e = sample(2000000L, 0L, oom=1L)
  assert_eq(c.update(@moonpressure.interval(d, e), b).low_streak, 1)
  c.reset()
  assert_eq(c.update(delta, b).high_streak, 1)
}

///|
test "missing PSI is explicit and prevents claiming recovery" {
  let c = @moonpressure.Controller::new(@moonpressure.Policy::new())
  let b = @moonpressure.budget([@moonpressure.Layer::parse("x")])
  let d = @moonpressure.interval(
    sample(0L, 0L, missing=true),
    sample(1000000L, 0L, missing=true),
  )
  let a = c.update(d, b)
  assert_true(a.reasons.contains(MissingPressure))
  assert_eq(a.low_streak, 0)
}

///|
test "headroom and high soft limit produce reasons and policy validates" {
  let c = @moonpressure.Controller::new(
    @moonpressure.Policy::new(enter_intervals=1),
  )
  let b = @moonpressure.budget([
    @moonpressure.Layer::parse(
      "x",
      memory_max="1000",
      memory_high="100",
      memory_current="200",
    ),
  ])
  let d = @moonpressure.interval(sample(0L, 0L), sample(1000000L, 0L))
  let a = c.update(d, b)
  assert_eq(a.state, Shed)
  assert_true(a.reasons.contains(LowMemoryHeadroom))
  assert_true(a.reasons.contains(MemoryHigh))
  assert_true(
    try {
      ignore(@moonpressure.Policy::new(enter_percent=5.0, exit_percent=10.0))
      false
    } catch {
      _ => true
    },
  )
  assert_true(
    try {
      ignore(@moonpressure.Policy::new(enter_intervals=0))
      false
    } catch {
      _ => true
    },
  )
  assert_true(
    try {
      ignore(@moonpressure.Policy::new(enter_percent=0.0 / 0.0))
      false
    } catch {
      _ => true
    },
  )
}
