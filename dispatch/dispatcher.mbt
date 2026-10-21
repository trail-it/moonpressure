///|
/// Pure coordinator state. Executor owns process I/O and must acknowledge death before release.
pub struct Dispatcher {
  priv ledger : @admission.Ledger
  priv tasks : Map[String, Task]
  priv mut last_ticket : Int64
  priv mut last_order : Int64
}

///|
pub fn Dispatcher::new(
  scopes : ArrayView[@admission.Scope],
) -> Dispatcher raise {
  {
    ledger: @admission.Ledger::new(scopes),
    tasks: Map([]),
    last_ticket: 0L,
    last_order: 0L,
  }
}

///|
pub fn Dispatcher::submit(
  self : Dispatcher,
  job : @admission.Job,
) -> Unit raise {
  guard self.tasks.length() < 128 && !self.tasks.contains(job.id) else {
    raise Invalid("duplicate ID or 128 tracked jobs reached")
  }
  let snapshot = @admission.Job::new(job.id, value=job.value, job.allocations)
  // Validate topology and request sums even when gates/budgets currently prevent admission.
  ignore(self.ledger.plan([snapshot]))
  let order = next(self.last_order)
  self.tasks[job.id] = {
    job: snapshot,
    state: Queued,
    ticket: None,
    exit_code: None,
    order,
  }
  self.last_order = order
}

///|
/// Optimize the oldest 16 queued entries; preserves the admission package's bounded search.
pub fn Dispatcher::dispatch(self : Dispatcher) -> Array[Action] raise {
  let waiting : Array[Task] = []
  for _, task in self.tasks {
    if task.state == Queued {
      waiting.push(task)
    }
  }
  waiting.sort_by((a, b) => {
    if a.order < b.order {
      -1
    } else if a.order > b.order {
      1
    } else {
      0
    }
  })
  let window = waiting[:Int32::min(waiting.length(), 16)].map(t => t.job)
  let plan = self.ledger.plan(window)
  let selected = plan.selected()
  if selected.is_empty() {
    return []
  }
  guard self.last_ticket <= 9223372036854775807L - selected.length().to_int64() else {
    raise Invalid("ticket sequence exhausted")
  }
  ignore(plan.commit())
  let actions : Array[Action] = []
  for id in selected {
    self.last_ticket += 1L
    let task = self.tasks[id]
    task.state = Starting
    task.ticket = Some(self.last_ticket)
    actions.push(Start(id, self.last_ticket))
  }
  actions
}

///|
fn Dispatcher::task(self : Dispatcher, id : String) -> Task raise DispatchError {
  match self.tasks.get(id) {
    Some(task) => task
    None => raise UnknownJob(id)
  }
}

///|
fn Dispatcher::attempt(
  self : Dispatcher,
  ticket : Int64,
) -> Task raise DispatchError {
  for _, task in self.tasks {
    if task.ticket == Some(ticket) {
      return task
    }
  }
  raise StaleAttempt
}

///|
pub fn Dispatcher::started(
  self : Dispatcher,
  ticket : Int64,
) -> Action? raise DispatchError {
  let task = self.attempt(ticket)
  match task.state {
    Starting => {
      task.state = Running
      None
    }
    Running => None
    Stopping => Some(Stop(task.job.id, ticket))
    _ => raise StaleAttempt
  }
}

///|
/// Cancelling Starting/Running keeps the lease. Stop is only a request to the executor.
pub fn Dispatcher::cancel(
  self : Dispatcher,
  id : String,
) -> Action? raise DispatchError {
  let task = self.task(id)
  match task.state {
    Queued => {
      task.state = Cancelled
      None
    }
    Starting | Running => {
      task.state = Stopping
      Some(Stop(id, task.ticket.unwrap()))
    }
    _ => None
  }
}

///|
/// Use only when no child was created. A running child requires exited(), not spawn_failed().
pub fn Dispatcher::spawn_failed(
  self : Dispatcher,
  ticket : Int64,
) -> Bool raise {
  let task = self.attempt(ticket)
  if terminal(task.state) {
    return false
  }
  guard task.state == Starting || task.state == Stopping else {
    raise Invalid("spawn failure after start acknowledgment")
  }
  self.ledger.release(task.job.id)
  task.state = if task.state == Stopping { Cancelled } else { Failed }
  true
}

///|
/// Executor must have waited for the actual process to exit. Duplicate completion is harmless.
pub fn Dispatcher::exited(
  self : Dispatcher,
  ticket : Int64,
  exit_code : Int32,
) -> Bool raise {
  let task = self.attempt(ticket)
  if terminal(task.state) {
    return false
  }
  guard task.state == Starting ||
    task.state == Running ||
    task.state == Stopping else {
    raise StaleAttempt
  }
  self.ledger.release(task.job.id)
  task.state = if task.state == Stopping {
    Cancelled
  } else if exit_code == 0 {
    Succeeded
  } else {
    Failed
  }
  task.exit_code = Some(exit_code)
  true
}

///|
pub fn Dispatcher::retry(
  self : Dispatcher,
  id : String,
) -> Unit raise DispatchError {
  let task = self.task(id)
  guard task.state == Failed || task.state == Cancelled else {
    raise Invalid("retry requires failed or cancelled job")
  }
  let order = next(self.last_order)
  task.state = Queued
  task.ticket = None
  task.exit_code = None
  task.order = order
  self.last_order = order
}

///|
pub fn Dispatcher::forget(
  self : Dispatcher,
  id : String,
) -> Unit raise DispatchError {
  guard terminal(self.task(id).state) else {
    raise Invalid("cannot forget a live or queued job")
  }
  self.tasks.remove(id)
}

///|
pub fn Dispatcher::refresh(
  self : Dispatcher,
  scopes : ArrayView[@admission.Scope],
) -> Unit raise {
  self.ledger.refresh(scopes)
}

///|
pub fn Dispatcher::balances(self : Dispatcher) -> Array[@admission.Balance] {
  self.ledger.balances()
}

///|
pub fn Dispatcher::revision(self : Dispatcher) -> Int64 {
  self.ledger.revision()
}

///|
pub fn Dispatcher::status(
  self : Dispatcher,
  id : String,
) -> TaskView raise DispatchError {
  let t = self.task(id)
  { id, state: t.state, ticket: t.ticket, exit_code: t.exit_code, }
}

///|
pub fn Dispatcher::tasks(self : Dispatcher) -> Array[TaskView] {
  [
    for id, t in self.tasks => {
      { id, state: t.state, ticket: t.ticket, exit_code: t.exit_code, }
    }
  ]
}
