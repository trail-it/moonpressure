# Executable API example

The module name is a local placeholder. This example is compiled as a black-box test.

```mbt check
///|
test "visible ancestor budget" {
  let leaf = @moonpressure.Layer::parse(
    "leaf",
    memory_max="max",
    memory_current="100",
  )
  let parent = @moonpressure.Layer::parse(
    "parent",
    cpu_max="50000 100000",
    memory_max="1000",
    memory_current="900",
  )
  let limits = @moonpressure.budget([leaf, parent])
  assert_eq(limits.quota_cores, Some(0.5))
  assert_eq(limits.hard_headroom_bytes, Some(100L))
}
```
