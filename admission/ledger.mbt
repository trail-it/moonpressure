///|
/// Single-coordinator logical reservations. This does not reserve kernel resources.
pub struct Ledger {
  priv mut tree : Topology
  priv mut revision : Int64
  priv active : Map[String, Candidate]
  priv reserved : Array[Resources]
}

///|
pub fn Ledger::new(scopes : ArrayView[Scope]) -> Ledger raise AdmissionError {
  let tree = topology(scopes)
  {
    tree,
    revision: 0L,
    active: Map([]),
    reserved: Array::make(tree.scopes.length(), zero_resources()),
  }
}

///|
pub fn Ledger::revision(self : Ledger) -> Int64 {
  self.revision
}

///|
/// Shape is fixed for this ledger's lifetime. Pressure and budgets may change.
/// Shrinkage retains existing leases and exposes deficits instead of silently cancelling jobs.
pub fn Ledger::refresh(
  self : Ledger,
  scopes : ArrayView[Scope],
) -> Unit raise AdmissionError {
  let tree = topology(scopes)
  guard tree.scopes.length() == self.tree.scopes.length() else {
    raise Invalid("scope topology changed")
  }
  for i, scope in tree.scopes {
    guard scope.id == self.tree.scopes[i].id &&
      scope.parent == self.tree.scopes[i].parent else {
      raise Invalid("scope topology changed")
    }
  }
  let next = checked_add(self.revision, 1L)
  self.tree = tree
  self.revision = next
}

///|
pub fn Ledger::release(
  self : Ledger,
  job_id : String,
) -> Unit raise AdmissionError {
  guard self.active.get(job_id) is Some(active) else {
    raise UnknownLease(job_id)
  }
  let next = checked_add(self.revision, 1L)
  for i, amount in active.demand {
    self.reserved[i] = subtract_resources(self.reserved[i], amount)
  }
  self.active.remove(job_id)
  self.revision = next
}

///|
pub fn Ledger::balances(self : Ledger) -> Array[Balance] {
  [
    for i, scope in self.tree.scopes => {
      {
        scope: scope.id,
        capacity: scope.capacity,
        reserved: self.reserved[i],
        free: free_resources(scope.capacity, self.reserved[i]),
        deficit: free_resources(self.reserved[i], scope.capacity),
        gate: scope.gate,
      }
    }
  ]
}

///|
/// Private input snapshots cannot be changed through selected()/deferred() display arrays.
pub struct Plan {
  priv owner : Ledger
  priv revision : Int64
  priv chosen : Array[Candidate]
  priv value : Int64
  priv deferred : Array[Deferred]
  priv explored : Int32
}

///|
pub fn Plan::selected(self : Plan) -> Array[String] {
  self.chosen.map(c => c.job.id)
}

///|
pub fn Plan::value(self : Plan) -> Int64 {
  self.value
}

///|
pub fn Plan::revision(self : Plan) -> Int64 {
  self.revision
}

///|
pub fn Plan::explored_states(self : Plan) -> Int32 {
  self.explored
}

///|
pub fn Plan::deferred(self : Plan) -> Array[Deferred] {
  self.deferred.map(d => { job_id: d.job_id, blockers: d.blockers.copy(), })
}

///|
/// All-or-nothing logical reservation on the ledger that created this plan.
/// Any commit/release/refresh after planning invalidates this plan, including repeat commits.
pub fn Plan::commit(self : Plan) -> Array[String] raise AdmissionError {
  let owner = self.owner
  guard owner.revision == self.revision else { raise StalePlan }
  let next = checked_add(owner.revision, 1L)
  // All inputs were validated by plan(); no raising operation occurs after mutation begins.
  for c in self.chosen {
    for i, amount in c.demand {
      owner.reserved[i] = {
        memory_bytes: owner.reserved[i].memory_bytes + amount.memory_bytes,
        cpu_millis: owner.reserved[i].cpu_millis + amount.cpu_millis,
      }
    }
    owner.active[c.job.id] = c
  }
  owner.revision = next
  self.selected()
}
