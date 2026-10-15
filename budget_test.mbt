///|
test "parent shared usage limits headroom more than leaf" {
  let leaf = @moonpressure.Layer::parse(
    "leaf",
    cpu_max="max 100000",
    memory_max="max",
    memory_high="max",
    memory_current="100",
  )
  let parent = @moonpressure.Layer::parse(
    "parent",
    cpu_max="150000 100000",
    memory_max="1000",
    memory_high="950",
    memory_current="900",
  )
  let top = @moonpressure.Layer::parse(
    "top",
    cpu_max="25000 100000",
    memory_max="10000",
    memory_current="500",
  )
  let b = @moonpressure.budget([leaf, parent, top])
  assert_eq(b.quota_cores, Some(0.25))
  assert_eq(b.quota_source, Some("top"))
  assert_eq(b.hard_headroom_bytes, Some(100L))
  assert_eq(b.high_headroom_bytes, Some(50L))
  assert_eq(b.hard_source, Some("parent"))
}

///|
test "unlimited absent and already exceeded budgets" {
  let unknown = @moonpressure.budget([@moonpressure.Layer::parse("root")])
  assert_eq(unknown.hard_headroom_bytes, None)
  assert_eq(unknown.quota_cores, None)
  let exceeded = @moonpressure.budget([
    @moonpressure.Layer::parse("a", memory_max="10", memory_current="20"),
  ])
  assert_eq(exceeded.hard_headroom_bytes, Some(0L))
  assert_true(
    try {
      ignore(@moonpressure.Layer::parse("a", memory_max="10"))
      false
    } catch {
      _ => true
    },
  )
  assert_true(
    try {
      ignore(@moonpressure.budget([]))
      false
    } catch {
      _ => true
    },
  )
  let a = @moonpressure.Layer::parse("a")
  assert_true(
    try {
      ignore(@moonpressure.budget([a, a]))
      false
    } catch {
      _ => true
    },
  )
}
