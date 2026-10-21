///|
// Read-only observation -> finite policy ceilings -> logical plan/commit. No processes are launched.
fn main raise {
  let args = @env.args()
  guard args.length() == 3 else { abort("Usage: admission-live ROOT RELATIVE") }
  let before = @native.collect(args[1], args[2])
  @native.sleep_ms(20)
  let current = @native.collect(args[1], args[2])
  let controller = @pressure.Controller::new(@pressure.Policy::new())
  let advice = controller.update(
    @pressure.interval(before.snapshot, current.snapshot),
    current.limits,
  )
  let gate = @scheduler.Gate::from_advice(advice)
  let ceiling = @scheduler.Resources::new(
    memory_bytes=134217728L,
    cpu_millis=500L,
  )
  let scopes : Array[@scheduler.Scope] = []
  for i, layer in current.layers {
    let id = "scope-\{i}"
    let parent = if i + 1 < current.layers.length() {
      Some("scope-\{i + 1}")
    } else {
      None
    }
    let s = if layer.cpu is Some(_) &&
      layer.memory_max is Some(_) &&
      layer.memory_current is Some(_) {
      let derived = @scheduler.Scope::from_layer(layer, ceiling, gate~)
      @scheduler.Scope::new(id, derived.capacity, parent?, gate~)
    } else {
      // The real root lacks limit files by design. Its cap is explicitly caller policy.
      // Incomplete non-root data remains closed rather than being treated as unlimited.
      @scheduler.Scope::new(
        id,
        ceiling,
        parent?,
        gate=if i + 1 == current.layers.length() { gate } else { Unknown },
      )
    }
    scopes.push(s)
  }
  let ledger = @scheduler.Ledger::new(scopes)
  let job = @scheduler.Job::new("example-job", value=1L, [
    @scheduler.Allocation::new(
      "scope-0",
      @scheduler.Resources::new(memory_bytes=1048576L, cpu_millis=10L),
    ),
  ])
  let first = ledger.plan([job])
  let second = ledger.plan([job])
  let committed = first.commit()
  let stale_rejected = try {
    ignore(second.commit())
    false
  } catch {
    StalePlan => true
    _ => false
  }
  for id in committed {
    ledger.release(id)
  }
  let result : Json = {
    "real_linux_collection": Json(true),
    "visible_scopes": Json(scopes.length()),
    "gate": Json(gate.label()),
    "selected_jobs": Json(committed.length()),
    "stale_plan_rejected": Json(stale_rejected),
    "released_all": Json(
      ledger
      .balances()
      .all(b => b.reserved.memory_bytes == 0L && b.reserved.cpu_millis == 0L),
    ),
    "root_ceiling_is_caller_policy": Json(true),
    "processes_started": Json(0),
  }
  println(result.stringify())
}
