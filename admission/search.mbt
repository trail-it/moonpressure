///|
priv struct Search {
  tree : Topology
  candidates : Array[Candidate]
  suffix : Array[Int64]
  used : Array[Resources]
  selected : Array[Bool]
  mut best : Array[Bool]
  mut best_value : Int64
  mut best_count : Int32
  mut explored : Int32
}

///|
fn fits(
  tree : Topology,
  demand : Array[Resources],
  used : Array[Resources],
) -> Bool {
  for i, need in demand {
    if need.memory_bytes == 0L && need.cpu_millis == 0L {
      continue
    }
    if tree.scopes[i].gate != Open {
      return false
    }
    let free = free_resources(tree.scopes[i].capacity, used[i])
    if need.memory_bytes > free.memory_bytes ||
      need.cpu_millis > free.cpu_millis {
      return false
    }
  }
  true
}

///|
fn Search::visit(
  self : Search,
  at : Int32,
  value : Int64,
  count : Int32,
) -> Unit {
  self.explored += 1
  if value + self.suffix[at] < self.best_value {
    return
  }
  if at == self.candidates.length() {
    if value > self.best_value ||
      (value == self.best_value && count > self.best_count) {
      self.best_value = value
      self.best_count = count
      self.best = self.selected.copy()
    }
    return
  }
  let c = self.candidates[at]
  if fits(self.tree, c.demand, self.used) {
    for i, need in c.demand {
      self.used[i] = {
        memory_bytes: self.used[i].memory_bytes + need.memory_bytes,
        cpu_millis: self.used[i].cpu_millis + need.cpu_millis,
      }
    }
    self.selected[at] = true
    self.visit(at + 1, value + c.job.value, count + 1)
    for i, need in c.demand {
      self.used[i] = subtract_resources(self.used[i], need)
    }
    self.selected[at] = false
  }
  // IDs are sorted and include is visited first. Equal score/count retains the lexicographically first set.
  self.visit(at + 1, value, count)
}

///|
/// Exact bounded-window multi-resource admission, including all ancestors and gang allocations.
/// Objective: maximum total value, then job count, then lexicographically smallest sorted IDs.
pub fn Ledger::plan(
  self : Ledger,
  jobs : ArrayView[Job],
) -> Plan raise AdmissionError {
  guard jobs.length() <= 16 else {
    raise Invalid("at most 16 jobs per exact planning window")
  }
  let sorted = jobs.to_owned()
  sorted.sort_by((a, b) => compare_ids(a.id, b.id))
  let candidates : Array[Candidate] = []
  let seen : Map[String, Bool] = Map([])
  for job in sorted {
    guard !seen.contains(job.id) && !self.active.contains(job.id) else {
      raise Invalid("duplicate or already reserved job ID")
    }
    seen[job.id] = true
    candidates.push(candidate(self.tree, job))
  }
  let n = candidates.length()
  let suffix = Array::make(n + 1, 0L)
  for i = n - 1; i >= 0; i = i - 1 {
    suffix[i] = suffix[i + 1] + candidates[i].job.value
  }
  let search : Search = {
    tree: self.tree,
    candidates,
    suffix,
    used: self.reserved.copy(),
    selected: Array::make(n, false),
    best: Array::make(n, false),
    best_value: 0L,
    best_count: 0,
    explored: 0,
  }
  search.visit(0, 0L, 0)
  let chosen : Array[Candidate] = []
  let used = self.reserved.copy()
  for i, c in candidates {
    if search.best[i] {
      chosen.push(c)
      for j, amount in c.demand {
        used[j] = add_resources(used[j], amount)
      }
    }
  }
  let deferred : Array[Deferred] = []
  for i, c in candidates {
    if !search.best[i] {
      deferred.push({
        job_id: c.job.id,
        blockers: blockers(self.tree, c.demand, used),
      })
    }
  }
  {
    owner: self,
    revision: self.revision,
    chosen,
    value: search.best_value,
    deferred,
    explored: search.explored,
  }
}
