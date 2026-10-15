///|
// Original synthetic trace: cumulative counters at six one-second boundaries.
fn point(
  t : Int32,
  stall : Int64,
  usage : Int64,
  throttled : Int64,
) -> @pressure.Snapshot raise {
  let psi = "some avg10=0 avg60=0 avg300=0 total=\{stall}\nfull avg10=0 avg60=0 avg300=0 total=\{stall / 2L}"
  @pressure.Snapshot::parse(
    "synthetic:queue",
    t.to_int64() * 1000000L,
    cpu_stat="usage_usec \{usage}\nnr_periods \{t * 10}\nnr_throttled \{throttled}\nthrottled_usec \{stall}",
    memory_current="104857600",
    memory_events="high 0\nmax 0\noom 0\noom_kill 0",
    cpu_pressure=psi,
    memory_pressure=psi,
    io_pressure=psi,
  )
}

///|
fn main raise {
  // Parent's siblings consume 800 MiB. Only 100 MiB shared headroom remains.
  let limits = @pressure.budget([
    @pressure.Layer::parse(
      "queue",
      cpu_max="max 100000",
      memory_max="max",
      memory_current="104857600",
    ),
    @pressure.Layer::parse(
      "parent",
      cpu_max="50000 100000",
      memory_max="1048576000",
      memory_current="943718400",
    ),
  ])
  let controller = @pressure.Controller::new(@pressure.Policy::new())
  let points = [
    point(0, 0L, 0L, 0L),
    point(1, 300000L, 500000L, 5L),
    point(2, 600000L, 1000000L, 10L),
    point(3, 600000L, 1000000L, 10L),
    point(4, 600000L, 1000000L, 10L),
    point(5, 600000L, 1000000L, 10L),
  ]
  for i in 1..<points.length() {
    let delta = @pressure.interval(points[i - 1], points[i])
    let advice = controller.update(delta, limits)
    let record : Json = {
      "schema": 1,
      "source": "synthetic",
      "step": Json(i),
      "budget": limits.to_json(),
      "interval": delta.to_json(),
      "advice": advice.to_json(),
    }
    println(record.stringify())
  }
}
