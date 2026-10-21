///|
test "layer adapter keeps ancestor own usage exact CPU floor and conservative reservation" {
  let layer = @pressure.Layer::parse(
    "root",
    cpu_max="25001 100000",
    memory_max="1000",
    memory_current="900",
  )
  let cap = resources(500L, 1000L)
  let derived = @admission.Scope::from_layer(layer, cap, gate=Open)
  assert_eq(derived.capacity, resources(100L, 250L))
  let ledger = @admission.Ledger::new([derived])
  ignore(ledger.plan([job("a", "root", 60L, 50L)]).commit())
  let later = @pressure.Layer::parse(
    "root",
    cpu_max="25001 100000",
    memory_max="1000",
    memory_current="960",
  )
  ledger.refresh([@admission.Scope::from_layer(later, cap, gate=Open)])
  assert_eq(ledger.balances()[0].capacity.memory_bytes, 40L)
  assert_eq(ledger.balances()[0].reserved.memory_bytes, 60L)
  assert_eq(ledger.balances()[0].deficit.memory_bytes, 20L)
  assert_true(
    try {
      ignore(
        @admission.Scope::from_layer(@pressure.Layer::parse("unknown"), cap),
      )
      false
    } catch {
      _ => true
    },
  )
  let unlimited = @pressure.Layer::parse(
    "unlimited",
    cpu_max="max 100000",
    memory_max="max",
    memory_current="900",
  )
  assert_eq(@admission.Scope::from_layer(unlimited, cap).capacity, cap)
  let high = @pressure.Layer::parse(
    "large",
    cpu_max="9223372036854775807 100000",
    memory_max="max",
    memory_current="0",
  )
  assert_eq(@admission.Scope::from_layer(high, cap).capacity.cpu_millis, 1000L)
}

///|
test "missing pressure never opens an admission scope automatically" {
  let a = @pressure.Snapshot::parse(
    "fixture",
    0L,
    cpu_stat="usage_usec 0",
    memory_current="0",
    memory_events="high 0\nmax 0\noom 0\noom_kill 0",
  )
  let b = @pressure.Snapshot::parse(
    "fixture",
    1000000L,
    cpu_stat="usage_usec 0",
    memory_current="0",
    memory_events="high 0\nmax 0\noom 0\noom_kill 0",
  )
  let controller = @pressure.Controller::new(@pressure.Policy::new())
  let advice = controller.update(
    @pressure.interval(a, b),
    @pressure.budget([@pressure.Layer::parse("root")]),
  )
  let gate = @admission.Gate::from_advice(advice)
  assert_eq(gate, Unknown)
  let ledger = @admission.Ledger::new([scope("root", 100L, 100L, gate~)])
  let plan = ledger.plan([job("a", "root", 1L, 1L)])
  assert_eq(plan.selected(), [])
  assert_true(plan.deferred()[0].blockers.contains(UnknownPressure("root")))
}
