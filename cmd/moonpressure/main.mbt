///|
fn main raise {
  let args = @env.args()
  guard args.length() >= 4 && (args[1] == "capture" || args[1] == "watch") else {
    println(
      "MoonPressure 0.2.0\nUsage: capture ROOT RELATIVE [raw]\n       watch ROOT RELATIVE COUNT DELAY_MS [raw]\nUse empty string for relative root. Linux cgroup v2 only. See README.",
    )
    return
  }
  let raw = args[args.length() - 1] == "raw"
  if args[1] == "capture" {
    println(
      @native.collect(args[2], args[3]).to_json(include_raw=raw).stringify(),
    )
  } else {
    guard args.length() >= 6 else { abort("watch requires COUNT DELAY_MS") }
    let count64 = @pressure.parse_counter(args[4])
    let delay64 = @pressure.parse_counter(args[5])
    guard count64 >= 2L && count64 <= 120L && delay64 >= 1L && delay64 <= 59000L else {
      abort("COUNT must be 2..120; DELAY_MS must be 1..59000")
    }
    let controller = @pressure.Controller::new(@pressure.Policy::new())
    let mut previous = @native.collect(args[2], args[3])
    println(previous.to_json(include_raw=raw).stringify())
    for _ in 1..<count64.to_int() {
      @native.sleep_ms(delay64.to_int())
      let current = @native.collect(args[2], args[3])
      let delta = @pressure.interval(previous.snapshot, current.snapshot)
      let advice = controller.update(delta, current.limits)
      let record : Json = {
        "observation": current.to_json(include_raw=raw),
        "interval": delta.to_json(),
        "advice": advice.to_json(),
      }
      println(record.stringify())
      previous = current
    }
  }
}
