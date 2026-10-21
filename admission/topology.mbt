///|
priv struct Topology {
  scopes : Array[Scope]
  index : Map[String, Int32]
  paths : Array[Array[Int32]]
}

///|
fn topology(scopes : ArrayView[Scope]) -> Topology raise AdmissionError {
  guard scopes.length() > 0 && scopes.length() <= 64 else {
    raise Invalid("expected 1..64 scopes")
  }
  let sorted = scopes.to_owned()
  sorted.sort_by((a, b) => compare_ids(a.id, b.id))
  let index : Map[String, Int32] = Map([])
  for i, scope in sorted {
    guard !index.contains(scope.id) else { raise Invalid("duplicate scope ID") }
    index[scope.id] = i
  }
  let paths : Array[Array[Int32]] = []
  for i in 0..<sorted.length() {
    let path : Array[Int32] = []
    let mut at = i
    for ;; {
      guard !path.contains(at) else { raise Invalid("cycle in scope parents") }
      path.push(at)
      match sorted[at].parent {
        None => break
        Some(parent) => {
          guard index.get(parent) is Some(next) else {
            raise Invalid("unknown parent scope")
          }
          at = next
        }
      }
    }
    paths.push(path)
  }
  { scopes: sorted, index, paths, }
}

///|
priv struct Candidate {
  job : Job
  demand : Array[Resources]
}

///|
fn candidate(tree : Topology, job : Job) -> Candidate raise AdmissionError {
  // Revalidate/copy: Job.allocations is public and its source array may have changed.
  let snapshot = Job::new(job.id, value=job.value, job.allocations)
  let demand = Array::make(tree.scopes.length(), zero_resources())
  for allocation in snapshot.allocations {
    guard tree.index.get(allocation.scope) is Some(i) else {
      raise Invalid("unknown allocation scope")
    }
    for ancestor in tree.paths[i] {
      demand[ancestor] = add_resources(demand[ancestor], allocation.resources)
    }
  }
  { job: snapshot, demand, }
}

///|
fn blockers(
  tree : Topology,
  request : Array[Resources],
  used : Array[Resources],
) -> Array[Blocker] {
  let result : Array[Blocker] = []
  for i, scope in tree.scopes {
    let need = request[i]
    if need.memory_bytes == 0L && need.cpu_millis == 0L {
      continue
    }
    match scope.gate {
      Open => ()
      Pressure => result.push(Pressure(scope.id))
      Unknown => result.push(UnknownPressure(scope.id))
    }
    let free = free_resources(scope.capacity, used[i])
    if need.memory_bytes > free.memory_bytes {
      result.push(Memory(scope.id, need.memory_bytes, free.memory_bytes))
    }
    if need.cpu_millis > free.cpu_millis {
      result.push(Cpu(scope.id, need.cpu_millis, free.cpu_millis))
    }
  }
  result
}
