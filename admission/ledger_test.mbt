///|
test "stale concurrent plans and repeated release never spend twice" {
  let ledger = @admission.Ledger::new([scope("root", 100L, 100L)])
  let first = ledger.plan([job("a", "root", 60L, 60L)])
  let stale = ledger.plan([job("b", "root", 60L, 60L)])
  assert_eq(first.commit(), ["a"])
  let before = ledger.balances()
  assert_true(
    try {
      ignore(stale.commit())
      false
    } catch {
      StalePlan => true
      _ => false
    },
  )
  assert_true(
    try {
      ignore(first.commit())
      false
    } catch {
      StalePlan => true
      _ => false
    },
  )
  assert_eq(ledger.balances(), before)
  assert_eq(ledger.plan([job("b", "root", 60L, 60L)]).selected(), [])
  ledger.release("a")
  assert_eq(ledger.plan([job("b", "root", 60L, 60L)]).commit(), ["b"])
  let revision = ledger.revision()
  assert_true(
    try {
      ledger.release("a")
      false
    } catch {
      UnknownLease("a") => true
      _ => false
    },
  )
  assert_eq(ledger.revision(), revision)
}

///|
test "budget shrink retains leases reports deficits and invalidates plans" {
  let ledger = @admission.Ledger::new([scope("root", 100L, 100L)])
  ignore(ledger.plan([job("a", "root", 80L, 80L)]).commit())
  let old = ledger.plan([job("b", "root", 10L, 10L)])
  ledger.refresh([scope("root", 50L, 70L)])
  assert_eq(ledger.balances()[0].reserved, resources(80L, 80L))
  assert_eq(ledger.balances()[0].deficit, resources(30L, 10L))
  assert_eq(ledger.balances()[0].free, resources(0L, 0L))
  assert_true(
    try {
      ignore(old.commit())
      false
    } catch {
      StalePlan => true
      _ => false
    },
  )
  assert_eq(ledger.plan([job("b", "root", 1L, 1L)]).selected(), [])
  ledger.release("a")
  assert_eq(ledger.balances()[0].deficit, resources(0L, 0L))
  assert_eq(ledger.plan([job("b", "root", 50L, 70L)]).selected(), ["b"])
}

///|
test "input and display arrays cannot alter a pending transaction" {
  let ledger = @admission.Ledger::new([scope("root", 100L, 100L)])
  let original = job("a", "root", 60L, 60L)
  let plan = ledger.plan([original, job("b", "root", 70L, 70L)])
  original.allocations.clear()
  let selected = plan.selected()
  selected.clear()
  let deferred = plan.deferred()
  deferred[0].blockers.clear()
  assert_eq(plan.selected(), ["a"])
  assert_true(!plan.deferred()[0].blockers.is_empty())
  assert_eq(plan.commit(), ["a"])
  assert_eq(ledger.balances()[0].reserved, resources(60L, 60L))
  ledger.release("a")
  assert_eq(ledger.balances()[0].reserved, resources(0L, 0L))
}

///|
test "invalid topology jobs and sums fail without modifying the ledger" {
  assert_true(
    try {
      ignore(
        @admission.Ledger::new([
          scope("a", 1L, 1L, parent="b"),
          scope("b", 1L, 1L, parent="a"),
        ]),
      )
      false
    } catch {
      _ => true
    },
  )
  assert_true(
    try {
      ignore(@admission.Ledger::new([scope("a", 1L, 1L, parent="missing")]))
      false
    } catch {
      _ => true
    },
  )
  assert_true(
    try {
      ignore(@admission.Ledger::new([scope("a", 1L, 1L), scope("a", 1L, 1L)]))
      false
    } catch {
      _ => true
    },
  )
  let ledger = @admission.Ledger::new([
    scope("root", 9223372036854775807L, 100L),
  ])
  let good = job("a", "root", 1L, 1L)
  assert_true(
    try {
      ignore(ledger.plan([good, good]))
      false
    } catch {
      _ => true
    },
  )
  assert_true(
    try {
      ignore(ledger.plan([job("x", "missing", 1L, 1L)]))
      false
    } catch {
      _ => true
    },
  )
  let overflow = @admission.Job::new("overflow", value=1L, [
    @admission.Allocation::new("root", resources(9223372036854775807L, 0L)),
    @admission.Allocation::new("root", resources(1L, 0L)),
  ])
  assert_true(
    try {
      ignore(ledger.plan([overflow]))
      false
    } catch {
      _ => true
    },
  )
  assert_true(
    try {
      ledger.refresh([scope("changed", 1L, 1L)])
      false
    } catch {
      _ => true
    },
  )
  assert_eq(ledger.revision(), 0L)
  assert_eq(ledger.balances()[0].reserved.memory_bytes, 0L)
  assert_eq(ledger.plan([good]).commit(), ["a"])
  let revision = ledger.revision()
  assert_true(
    try {
      ignore(ledger.plan([good]))
      false
    } catch {
      _ => true
    },
  )
  assert_eq(ledger.revision(), revision)
}

///|
test "bounded exact window and empty commits have explicit lifecycle" {
  let ledger = @admission.Ledger::new([scope("root", 100L, 100L)])
  let jobs = [ for i in 0..<17 => job("job-\{i}", "root", 1L, 1L) ]
  assert_true(
    try {
      ignore(ledger.plan(jobs))
      false
    } catch {
      _ => true
    },
  )
  assert_eq(ledger.revision(), 0L)
  assert_eq(ledger.plan(jobs[:16]).selected().length(), 16)
  let empty = ledger.plan([])
  assert_eq(empty.value(), 0L)
  assert_eq(empty.commit(), [])
  assert_eq(ledger.revision(), 1L)
  assert_true(
    try {
      ignore(empty.commit())
      false
    } catch {
      StalePlan => true
      _ => false
    },
  )
}
