///|
fn resource(memory : Int64, cpu : Int64) -> @scheduler.Resources raise {
  @scheduler.Resources::new(memory_bytes=memory, cpu_millis=cpu)
}

///|
fn node(
  id : String,
  memory : Int64,
  cpu : Int64,
  parent? : String,
  gate~ : @scheduler.Gate = Open,
) -> @scheduler.Scope raise {
  @scheduler.Scope::new(id, resource(memory, cpu), parent?, gate~)
}

///|
fn request(
  scope : String,
  memory : Int64,
  cpu : Int64,
) -> @scheduler.Allocation raise {
  @scheduler.Allocation::new(scope, resource(memory, cpu))
}

///|
fn work(
  id : String,
  scope : String,
  memory : Int64,
  cpu : Int64,
  value~ : Int64 = 1L,
) -> @scheduler.Job raise {
  @scheduler.Job::new(id, value~, [request(scope, memory, cpu)])
}

///|
fn emit(
  name : String,
  scopes : Array[@scheduler.Scope],
  jobs : Array[@scheduler.Job],
) -> Unit raise {
  let ledger = @scheduler.Ledger::new(scopes)
  let plan = ledger.plan(jobs)
  let result : Json = {
    "kind": Json("selection"),
    "case": Json(name),
    "synthetic": Json(true),
    "scopes": Json(scopes.map(s => s.to_json())),
    "jobs": Json(jobs.map(j => j.to_json())),
    "plan": plan.to_json(),
  }
  println(result.stringify())
}

///|
fn main raise {
  let paired = [work("a", "left", 60L, 1L), work("b", "right", 60L, 1L)]
  emit(
    "shared-parent",
    [
      node("root", 100L, 100L),
      node("left", 100L, 100L, parent="root"),
      node("right", 100L, 100L, parent="root"),
    ],
    paired,
  )
  emit(
    "separate-parents",
    [
      node("one", 100L, 100L),
      node("two", 100L, 100L),
      node("left", 100L, 100L, parent="one"),
      node("right", 100L, 100L, parent="two"),
    ],
    paired,
  )
  let root = [node("root", 10L, 10L)]
  let a = work("a", "root", 10L, 10L, value=9L)
  let b = work("b", "root", 6L, 4L, value=6L)
  emit("complementary", root, [a, b, work("c", "root", 4L, 6L, value=6L)])
  emit("changed-demand", root, [a, b, work("c", "root", 7L, 6L, value=6L)])
  let gang = @scheduler.Job::new("gang", value=20L, [
    request("left", 4L, 4L),
    request("right", 4L, 4L),
  ])
  emit(
    "gang-one-branch-held",
    [
      node("root", 12L, 12L),
      node("left", 10L, 10L, parent="root"),
      node("right", 10L, 10L, parent="root", gate=Pressure),
    ],
    [gang, work("local", "left", 6L, 6L)],
  )
  emit(
    "gang-open",
    [
      node("root", 12L, 12L),
      node("left", 10L, 10L, parent="root"),
      node("right", 10L, 10L, parent="root"),
    ],
    [gang, work("local", "left", 6L, 6L)],
  )
  let ledger = @scheduler.Ledger::new([node("root", 100L, 100L)])
  let first = ledger.plan([work("a", "root", 60L, 60L)])
  let other = ledger.plan([work("b", "root", 60L, 60L)])
  let selected = first.commit()
  let stale_rejected = try {
    ignore(other.commit())
    false
  } catch {
    StalePlan => true
    _ => false
  }
  ledger.refresh([node("root", 50L, 50L)])
  let shrunk = ledger.balances().map(b => b.to_json())
  ledger.release("a")
  let restarted = ledger.plan([work("b", "root", 50L, 50L)]).commit()
  let lifecycle : Json = {
    "kind": Json("lifecycle"),
    "case": Json("commit-stale-shrink-release"),
    "synthetic": Json(true),
    "first_selected": Json(selected),
    "stale_rejected": Json(stale_rejected),
    "after_shrink": Json(shrunk),
    "after_release_selected": Json(restarted),
  }
  println(lifecycle.stringify())
  if @env.args().contains("--oracle") {
    // Deterministic input generation only. Python independently enumerates every subset.
    let mut seed = 1729L
    fn draw(bound : Int64) -> Int64 {
      seed = seed * 48271L % 2147483647L
      seed % bound
    }
    for k in 0..<60 {
      let gate : @scheduler.Gate = if k % 7 == 0 {
        Unknown
      } else if k % 5 == 0 {
        Pressure
      } else {
        Open
      }
      let scopes = [
        node("root", 8L + draw(13L), 8L + draw(13L)),
        node("left", 5L + draw(10L), 5L + draw(10L), parent="root"),
        node("right", 5L + draw(10L), 5L + draw(10L), parent="root", gate~),
      ]
      let jobs : Array[@scheduler.Job] = []
      let n = 2 + draw(7L).to_int()
      for i in 0..<n {
        let requests = [
          request(
            if draw(2L) == 0L {
              "left"
            } else {
              "right"
            },
            draw(8L),
            1L + draw(7L),
          ),
        ]
        if draw(3L) == 0L {
          requests.push(request("right", 1L + draw(5L), draw(5L)))
        }
        jobs.push(
          @scheduler.Job::new("job-\{i}", value=1L + draw(12L), requests),
        )
      }
      emit("oracle-\{k}", scopes, jobs)
    }
  }
}
