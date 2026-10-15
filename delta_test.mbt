///|
fn psi(n : Int64) -> String {
  "some avg10=0 avg60=0 avg300=0 total=\{n}\nfull avg10=0 avg60=0 avg300=0 total=\{n / 2L}"
}

///|
fn snapshot(
  t : Int64,
  count : Int64,
  identity~ : String = "synthetic:1",
  pressure~ : Bool = true,
  oom~ : Int64 = 0L,
) -> @moonpressure.Snapshot raise {
  let p = if pressure { Some(psi(count)) } else { None }
  @moonpressure.Snapshot::parse(
    identity,
    t,
    cpu_stat="usage_usec \{count * 2L}\nnr_periods \{t / 100000L}\nnr_throttled \{t / 200000L}\nthrottled_usec \{count}",
    memory_current="10",
    memory_events="high 0\nmax 0\noom \{oom}\noom_kill 0",
    cpu_pressure?=p,
    memory_pressure?=p,
    io_pressure?=p,
  )
}

///|
test "counter deltas use elapsed microseconds not PSI moving averages" {
  let d = @moonpressure.interval(
    snapshot(1000000L, 1000L),
    snapshot(2000000L, 251000L),
  )
  assert_eq(d.elapsed_us, 1000000L)
  assert_eq(d.cpu_cores_used, 0.5)
  assert_eq(d.throttled_period_percent, Some(50.0))
  assert_true(
    d.memory_stall is Some({ some_percent: 25.0, full_percent: Some(12.5), }),
  )
  assert_eq(d.oom_events, 0L)
}

///|
test "identity reset counter reset invalid timestamps and gaps reject" {
  let a = snapshot(1000000L, 1000L)
  for
    b in [
      snapshot(2000000L, 2000L, identity="synthetic:2"),
      snapshot(2000000L, 999L),
      snapshot(1000000L, 1001L),
      snapshot(999999L, 1001L),
      snapshot(62000000L, 1001L),
      snapshot(2000000L, 1001L, pressure=false),
    ] {
    assert_true(
      try {
        ignore(@moonpressure.interval(a, b))
        false
      } catch {
        _ => true
      },
    )
  }
}

///|
test "zero periods yields unknown not zero throttling" {
  let a = @moonpressure.Snapshot::parse(
    "x",
    1L,
    cpu_stat="usage_usec 0\nnr_periods 0\nnr_throttled 0\nthrottled_usec 0",
    memory_current="0",
    memory_events="high 0\nmax 0\noom 0\noom_kill 0",
  )
  let b = @moonpressure.Snapshot::parse(
    "x",
    2L,
    cpu_stat="usage_usec 0\nnr_periods 0\nnr_throttled 0\nthrottled_usec 0",
    memory_current="0",
    memory_events="high 0\nmax 0\noom 0\noom_kill 0",
  )
  let d = @moonpressure.interval(a, b)
  assert_eq(d.throttled_period_percent, None)
  assert_eq(d.cpu_stall, None)
}
