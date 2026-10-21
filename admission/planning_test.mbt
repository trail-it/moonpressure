///|
fn resources(memory : Int64, cpu : Int64) -> @admission.Resources raise {
  @admission.Resources::new(memory_bytes=memory, cpu_millis=cpu)
}

///|
fn scope(
  id : String,
  memory : Int64,
  cpu : Int64,
  parent? : String,
  gate~ : @admission.Gate = Open,
) -> @admission.Scope raise {
  @admission.Scope::new(id, resources(memory, cpu), parent?, gate~)
}

///|
fn job(
  id : String,
  target : String,
  memory : Int64,
  cpu : Int64,
  value~ : Int64 = 1L,
) -> @admission.Job raise {
  @admission.Job::new(id, value~, [
    @admission.Allocation::new(target, resources(memory, cpu)),
  ])
}

///|
test "shared ancestors change joint admission with identical leaf measurements" {
  let jobs = [job("a", "left", 60L, 1L), job("b", "right", 60L, 1L)]
  let shared = @admission.Ledger::new([
    scope("parent", 100L, 100L),
    scope("left", 100L, 100L, parent="parent"),
    scope("right", 100L, 100L, parent="parent"),
  ])
  let plan = shared.plan(jobs)
  assert_eq(plan.selected(), ["a"])
  assert_true(plan.deferred()[0].blockers.contains(Memory("parent", 60L, 40L)))
  let separate = @admission.Ledger::new([
    scope("one", 100L, 100L),
    scope("two", 100L, 100L),
    scope("left", 100L, 100L, parent="one"),
    scope("right", 100L, 100L, parent="two"),
  ])
  assert_eq(separate.plan(jobs).selected(), ["a", "b"])
}

///|
test "complementary resources beat greedy and a changed relation reverses the optimum" {
  let ledger = @admission.Ledger::new([scope("root", 10L, 10L)])
  let a = job("a", "root", 10L, 10L, value=9L)
  let b = job("b", "root", 6L, 4L, value=6L)
  let c = job("c", "root", 4L, 6L, value=6L)
  let plan = ledger.plan([a, b, c])
  assert_eq(plan.selected(), ["b", "c"])
  assert_eq(plan.value(), 12L)
  assert_eq(ledger.revision(), 0L)
  let changed = ledger.plan([a, b, job("c", "root", 7L, 6L, value=6L)])
  assert_eq(changed.selected(), ["a"])
  assert_eq(changed.value(), 9L)
}

///|
test "gang charges every ancestor and gate blocks only the affected branch" {
  let scopes = [
    scope("root", 12L, 12L),
    scope("left", 10L, 10L, parent="root"),
    scope("right", 10L, 10L, parent="root", gate=Pressure),
  ]
  let gang = @admission.Job::new("gang", value=20L, [
    @admission.Allocation::new("left", resources(4L, 4L)),
    @admission.Allocation::new("right", resources(4L, 4L)),
  ])
  let ledger = @admission.Ledger::new(scopes)
  let plan = ledger.plan([gang, job("local", "left", 6L, 6L)])
  assert_eq(plan.selected(), ["local"])
  assert_true(plan.deferred()[0].blockers.contains(Pressure("right")))
  ignore(plan.commit())
  assert_eq(ledger.balances()[2].reserved, resources(6L, 6L))
  ledger.release("local")
  ledger.refresh([
    scope("root", 7L, 7L),
    scope("left", 10L, 10L, parent="root"),
    scope("right", 10L, 10L, parent="root"),
  ])
  let denied = ledger.plan([gang])
  assert_eq(denied.selected(), [])
  assert_true(denied.deferred()[0].blockers.contains(Memory("root", 8L, 7L)))
  ledger.refresh([
    scope("root", 12L, 12L),
    scope("left", 10L, 10L, parent="root"),
    scope("right", 10L, 10L, parent="root"),
  ])
  assert_eq(ledger.plan([gang]).commit(), ["gang"])
  assert_eq(ledger.balances()[2].reserved, resources(8L, 8L))
}

///|
test "objective ties use cardinality then stable IDs independent of input order" {
  let ledger = @admission.Ledger::new([scope("root", 2L, 2L)])
  let a = job("a", "root", 2L, 2L, value=2L)
  let b = job("b", "root", 1L, 1L)
  let c = job("c", "root", 1L, 1L)
  assert_eq(ledger.plan([c, a, b]).selected(), ["b", "c"])
  assert_eq(ledger.plan([job("z", "root", 2L, 2L, value=2L), a]).selected(), [
    "a",
  ])
  assert_eq(
    ledger
    .plan([job("b", "root", 2L, 2L), job("aa", "root", 2L, 2L)])
    .selected(),
    ["aa"],
  )
}

///|
test "large exact resources keep Int64 precision across JSON and selection" {
  let limit = 9007199254740993L
  let ledger = @admission.Ledger::new([scope("root", limit, 10L)])
  let plan = ledger.plan([
    job("a", "root", limit - 1L, 1L),
    job("b", "root", 1L, 1L),
  ])
  assert_eq(plan.selected(), ["a", "b"])
  ignore(plan.commit())
  assert_eq(ledger.balances()[0].reserved.memory_bytes, limit)
  assert_true(
    ledger.balances()[0].to_json().stringify().contains("9007199254740993"),
  )
}
