///|
test "schema keeps large counters as decimal strings and missing values as null" {
  let s = @moonpressure.Snapshot::parse(
    "fixture\"escape",
    1L,
    cpu_stat="usage_usec 9007199254740993",
    memory_current="0",
    memory_events="high 0\nmax 0\noom 0\noom_kill 0",
  )
  let text = s.to_json().stringify()
  assert_true(text.contains("\"cpu_usage_us\":\"9007199254740993\""))
  assert_true(text.contains("\"cpu_pressure\":null"))
  assert_true(text.contains("fixture\\\"escape"))
}
