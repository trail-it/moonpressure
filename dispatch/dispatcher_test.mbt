///|
fn capacity(n : Int64) -> @admission.Resources raise {
  @admission.Resources::new(memory_bytes=n, cpu_millis=n)
}

///|
fn scopes(n : Int64) -> Array[@admission.Scope] raise {
  [@admission.Scope::new("root", capacity(n))]
}

///|
fn job(id : String, n~ : Int64 = 1L) -> @admission.Job raise {
  @admission.Job::new(id, value=1L, [
    @admission.Allocation::new("root", capacity(n)),
  ])
}

///|
fn ticket(actions : Array[@dispatch.Action]) -> Int64 {
  match actions[0] {
    Start(_, t) => t
    _ => abort("expected start")
  }
}

///|
test "successful failed and uncreated children release exactly once" {
  let d = @dispatch.Dispatcher::new(scopes(1L))
  d.submit(job("a"))
  let t = ticket(d.dispatch())
  assert_eq(d.balances()[0].reserved.memory_bytes, 1L)
  assert_eq(d.started(t), None)
  assert_eq(d.started(t), None)
  assert_true(d.exited(t, 0))
  assert_true(!d.exited(t, 7))
  assert_eq(d.status("a").state, Succeeded)
  assert_eq(d.status("a").exit_code, Some(0))
  d.submit(job("b"))
  let b = ticket(d.dispatch())
  assert_true(d.spawn_failed(b))
  assert_true(!d.spawn_failed(b))
  assert_eq(d.status("b").state, Failed)
  assert_eq(d.status("b").exit_code, None)
  d.retry("b")
  let retry = ticket(d.dispatch())
  ignore(d.started(retry))
  assert_true(
    try {
      ignore(d.spawn_failed(retry))
      false
    } catch {
      _ => true
    },
  )
  assert_eq(d.balances()[0].reserved.memory_bytes, 1L)
  ignore(d.exited(retry, 7))
  assert_eq(d.status("b").exit_code, Some(7))
  assert_eq(d.balances()[0].reserved.memory_bytes, 0L)
}

///|
test "cancel cannot release a starting or running child before death acknowledgment" {
  let d = @dispatch.Dispatcher::new(scopes(1L))
  d.submit(job("a"))
  d.submit(job("b"))
  let t = ticket(d.dispatch())
  assert_eq(d.cancel("a"), Some(Stop("a", t)))
  assert_eq(d.status("a").state, Stopping)
  assert_eq(d.started(t), Some(Stop("a", t)))
  assert_eq(d.cancel("a"), None)
  assert_eq(d.dispatch(), [])
  ignore(d.exited(t, -15))
  assert_eq(d.status("a").state, Cancelled)
  let b = ticket(d.dispatch())
  ignore(d.started(b))
  ignore(d.cancel("b"))
  assert_eq(d.balances()[0].reserved.memory_bytes, 1L)
  ignore(d.exited(b, -15))
  d.submit(job("queued"))
  ignore(d.cancel("queued"))
  assert_eq(d.status("queued").ticket, None)
  assert_eq(d.dispatch(), [])
  d.retry("queued")
  let q = ticket(d.dispatch())
  ignore(d.cancel("queued"))
  ignore(d.spawn_failed(q))
  assert_eq(d.status("queued").state, Cancelled)
  assert_eq(d.balances()[0].reserved.memory_bytes, 0L)
}

///|
test "late old callbacks cannot release a retried attempt" {
  let d = @dispatch.Dispatcher::new(scopes(1L))
  d.submit(job("a"))
  let old = ticket(d.dispatch())
  ignore(d.spawn_failed(old))
  d.retry("a")
  let fresh = ticket(d.dispatch())
  assert_true(fresh > old)
  assert_true(
    try {
      ignore(d.exited(old, 0))
      false
    } catch {
      @dispatch.StaleAttempt => true
      _ => false
    },
  )
  assert_true(
    try {
      ignore(d.spawn_failed(old))
      false
    } catch {
      @dispatch.StaleAttempt => true
      _ => false
    },
  )
  assert_eq(d.status("a").ticket, Some(fresh))
  assert_eq(d.balances()[0].reserved.memory_bytes, 1L)
  ignore(d.exited(fresh, 0))
  d.forget("a")
  d.submit(job("a"))
  let reused = ticket(d.dispatch())
  assert_true(reused > fresh)
  assert_true(
    try {
      ignore(d.started(fresh))
      false
    } catch {
      StaleAttempt => true
      _ => false
    },
  )
  assert_eq(d.balances()[0].reserved.memory_bytes, 1L)
}

///|
test "queue window tracked limit and forgetting preserve admission bounds" {
  let d = @dispatch.Dispatcher::new(scopes(1000L))
  for i in 0..<128 {
    d.submit(job("job-\{i}"))
  }
  assert_true(
    try {
      d.submit(job("overflow"))
      false
    } catch {
      _ => true
    },
  )
  let actions = d.dispatch()
  assert_eq(actions.length(), 16)
  assert_eq(d.balances()[0].reserved.memory_bytes, 16L)
  assert_true(
    try {
      d.forget("job-0")
      false
    } catch {
      _ => true
    },
  )
  for a in actions {
    match a {
      Start(_, t) => ignore(d.exited(t, 0))
      _ => abort("start")
    }
  }
  d.forget("job-0")
  d.submit(job("new"))
  assert_eq(d.dispatch().length(), 16)
}

///|
test "queue owns input snapshots and refresh shrink does not cancel execution" {
  let d = @dispatch.Dispatcher::new(scopes(4L))
  let original = job("a", n=3L)
  d.submit(original)
  original.allocations.clear()
  let t = ticket(d.dispatch())
  d.refresh(scopes(1L))
  assert_eq(d.status("a").state, Starting)
  assert_eq(d.balances()[0].deficit.memory_bytes, 2L)
  let revision = d.revision()
  assert_true(
    try {
      d.refresh([@admission.Scope::new("other", capacity(1L))])
      false
    } catch {
      _ => true
    },
  )
  assert_eq(d.revision(), revision)
  ignore(d.exited(t, 0))
  assert_eq(d.balances()[0].reserved.memory_bytes, 0L)
}
