///|
fn resources(memory : Int64, cpu : Int64) -> @planner.Resources raise {
  @planner.Resources::new(memory_bytes=memory, cpu_millis=cpu)
}

///|
fn node(
  id : String,
  memory : Int64,
  cpu : Int64,
  parent? : String,
  gate~ : @planner.Gate = Open,
) -> @planner.Scope raise {
  @planner.Scope::new(id, resources(memory, cpu), parent?, gate~)
}

///|
fn request(
  id : String,
  scope : String,
  memory : Int64,
  cpu : Int64,
  value : Int64,
) -> @planner.Job raise {
  @planner.Job::new(id, value~, [
    @planner.Allocation::new(scope, resources(memory, cpu)),
  ])
}

///|
fn measure(
  name : String,
  scopes : Array[@planner.Scope],
  jobs : Array[@planner.Job],
) -> Unit raise {
  let ledger = @planner.Ledger::new(scopes)
  ignore(ledger.plan(jobs)) // warm up before timing; no commits or host I/O in timed interval
  let times : Array[String] = []
  let mut plan = ledger.plan(jobs)
  for _ in 0..<3 {
    let start = @native.monotonic_us()
    plan = ledger.plan(jobs)
    let elapsed = @native.monotonic_us() - start
    times.push(elapsed.to_string())
  }
  let row : Json = {
    "case": Json(name),
    "synthetic": Json(true),
    "scopes": Json(scopes.map(s => s.to_json())),
    "jobs": Json(jobs.map(j => j.to_json())),
    "plan": plan.to_json(),
    "planning_time_us": Json(times),
  }
  println(row.stringify())
}

///|
fn main raise {
  for padding in [0, 4] {
    let jobs : Array[@planner.Job] = []
    for i in 0..<4 {
      jobs.push(request("a-\{i}", "root", 10L, 10L, 9L))
      jobs.push(request("b-\{i}", "root", 6L, 4L, 6L))
      jobs.push(request("c-\{i}", "root", 4L, 6L, 6L))
    }
    for i in 0..<padding {
      jobs.push(request("z-\{i}", "root", 1L, 1L, 1L))
    }
    measure("complement-\{12+padding}", [node("root", 40L, 40L)], jobs)
  }
  let unit_jobs = [
    for i in 0..<16 => request("job-\{i}", "scope-63", 1L, 1L, 1L)
  ]
  let chain = [
    for i in 0..<64 => {
      node(
        "scope-\{i}",
        8L,
        8L,
        parent?=if i == 0 { None } else { Some("scope-\{i-1}") },
      )
    }
  ]
  measure("dense-64-scopes-16-jobs", chain, unit_jobs)
  measure("all-fit-16", [node("scope-63", 16L, 16L)], unit_jobs)
  let mut seed = 20261021L
  fn draw(bound : Int64) -> Int64 {
    seed = seed * 48271L % 2147483647L
    seed % bound
  }
  for k in 0..<16 {
    let gate : @planner.Gate = if k % 4 == 0 { Pressure } else { Open }
    let scopes = [
      node("root", 32L, 32L),
      node("left", 24L, 24L, parent="root"),
      node("right", 24L, 24L, parent="root", gate~),
    ]
    let jobs = [
      for i in 0..<16 => {
        let allocations = [
          @planner.Allocation::new(
            if draw(2L) == 0L {
              "left"
            } else {
              "right"
            },
            resources(1L + draw(9L), 1L + draw(9L)),
          ),
        ]
        if draw(5L) == 0L {
          allocations.push(
            @planner.Allocation::new(
              "right",
              resources(1L + draw(4L), 1L + draw(4L)),
            ),
          )
        }
        @planner.Job::new("job-\{i}", value=1L + draw(15L), allocations)
      }
    ]
    measure("mixed-\{k}", scopes, jobs)
  }
}
