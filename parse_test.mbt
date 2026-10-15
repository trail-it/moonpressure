///|
test "unsigned counters retain precision beyond double and reject overflow" {
  assert_eq(
    @moonpressure.parse_counter("9007199254740993\n"),
    9007199254740993L,
  )
  assert_eq(
    @moonpressure.parse_counter("9223372036854775807"),
    9223372036854775807L,
  )
  for
    invalid in [
      "", "-1", "+1", "1e3", "1 2", "9223372036854775808", "18446744073709551615",
    ] {
    let rejected = try {
      ignore(@moonpressure.parse_counter(invalid))
      false
    } catch {
      _ => true
    }
    assert_true(rejected)
  }
}

///|
test "PSI reordered fields optional full and extension keys" {
  let p = @moonpressure.parse_pressure(
    "some total=123 avg300=3.25 avg10=1.50 avg60=2.00 future=ok\r\n",
  )
  assert_eq(p.some.total_us, 123L)
  assert_eq(p.some.avg10, 1.5)
  assert_eq(p.some.avg300, 3.25)
  assert_eq(p.full, None)
  let both = @moonpressure.parse_pressure(
    "full avg10=0 avg60=0 avg300=0 total=1\nsome avg10=0 avg60=0 avg300=0 total=2",
  )
  assert_true(both.full is Some({ total_us: 1L, .. }))
}

///|
test "PSI rejects duplicate lines fields invalid percentages missing keys" {
  let valid = "some avg10=0 avg60=0 avg300=0 total=0"
  for
    bad in [
      valid + "\n" + valid,
      "full avg10=0 avg60=0 avg300=0 total=0",
      "some avg10=0 avg10=1 avg60=0 avg300=0 total=0",
      "some avg10=NaN avg60=0 avg300=0 total=0",
      "some avg10=100.1 avg60=0 avg300=0 total=0",
      "some avg10=0 avg60=0 total=0",
      "some avg10=-1 avg60=0 avg300=0 total=0",
      "some avg10=1..0 avg60=0 avg300=0 total=0",
      "unknown avg10=0 avg60=0 avg300=0 total=0",
    ] {
    let rejected = try {
      ignore(@moonpressure.parse_pressure(bad))
      false
    } catch {
      _ => true
    }
    assert_true(rejected)
  }
}

///|
test "cpu quota and partial throttle data" {
  assert_eq(@moonpressure.parse_cpu_max("max 100000").quota, Unlimited)
  assert_eq(@moonpressure.parse_cpu_max("50000 100000").quota, Finite(50000L))
  assert_eq(
    @moonpressure.parse_cpu_stat("usage_usec 10\nuser_usec 2\nsystem_usec 8").throttle,
    None,
  )
  for
    bad in [
      "usage_usec 1\nnr_periods 2", "usage_usec 1\nnr_periods 2\nnr_throttled 3\nthrottled_usec 0",
      "usage_usec 1\nusage_usec 2",
    ] {
    let rejected = try {
      ignore(@moonpressure.parse_cpu_stat(bad))
      false
    } catch {
      _ => true
    }
    assert_true(rejected)
  }
  for bad in ["0 100000", "max 0", "100", "-1 10"] {
    let rejected = try {
      ignore(@moonpressure.parse_cpu_max(bad))
      false
    } catch {
      _ => true
    }
    assert_true(rejected)
  }
}

///|
test "memory events extensions supported missing fields rejected" {
  let e = @moonpressure.parse_memory_events(
    "low 0\nhigh 3\nmax 4\noom 5\noom_kill 6\noom_group_kill 0\n",
  )
  assert_eq(e.high, 3L)
  assert_eq(e.oom_kill, 6L)
  let rejected = try {
    ignore(@moonpressure.parse_memory_events("high 0\nmax 0\noom 0"))
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
}
