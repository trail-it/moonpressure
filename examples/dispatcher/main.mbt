///|
priv struct Live {
  root : String
  relative : String
  controller : @pressure.Controller
  mut previous : @native.Observation
}

///|
fn live_scopes(
  o : @native.Observation,
  gate : @admission.Gate,
) -> Array[@admission.Scope] raise {
  let ceiling = @admission.Resources::new(
    memory_bytes=67108864L,
    cpu_millis=200L,
  )
  [
    for i, layer in o.layers => {
      let parent = if i + 1 < o.layers.length() {
        Some("scope-\{i+1}")
      } else {
        None
      }
      let complete = layer.cpu is Some(_) &&
        layer.memory_max is Some(_) &&
        layer.memory_current is Some(_)
      let capacity = if complete {
        @admission.Scope::from_layer(layer, ceiling, gate~).capacity
      } else {
        ceiling
      }
      @admission.Scope::new(
        "scope-\{i}",
        capacity,
        parent?,
        gate=if !complete && i + 1 < o.layers.length() { Unknown } else { gate },
      )
    }
  ]
}

///|
fn main raise {
  let args = @env.args()
  let mut dispatcher : @driver.Dispatcher? = None
  let live : Live? = if args.length() == 4 && args[1] == "--live" {
    let first = @native.collect(args[2], args[3])
    @native.sleep_ms(20)
    let current = @native.collect(args[2], args[3])
    let controller = @pressure.Controller::new(@pressure.Policy::new())
    let advice = controller.update(
      @pressure.interval(first.snapshot, current.snapshot),
      current.limits,
    )
    dispatcher = Some(
      @driver.Dispatcher::new(
        live_scopes(current, @admission.Gate::from_advice(advice)),
      ),
    )
    Some({ root: args[2], relative: args[3], controller, previous: current, })
  } else {
    None
  }
  send({
    "ready": Json(true),
    "protocol": Json(1),
    "live": Json(live is Some(_)),
  })
  for ;; {
    let response = try {
      guard read_line() is Some(line) else { break }
      if line == "" {
        continue
      }
      let request = @json.parse(line)
      let op = text(field(request, "op"))
      if op == "init" {
        guard dispatcher is None else { raise InvalidInput }
        dispatcher = Some(
          @driver.Dispatcher::new(scopes(field(request, "scopes"))),
        )
      }
      guard dispatcher is Some(d) else { raise InvalidInput }
      let actions : Array[@driver.Action] = []
      let before_tasks = d.tasks()
      let before_revision = d.revision()
      match op {
        "init" | "status" => ()
        "submit" => d.submit(job(field(request, "job")))
        "dispatch" =>
          for action in d.dispatch() {
            actions.push(action)
          }
        "started" =>
          if d.started(number(field(request, "ticket"))) is Some(a) {
            actions.push(a)
          }
        "spawn_failed" =>
          ignore(d.spawn_failed(number(field(request, "ticket"))))
        "exited" => {
          let code = @json.from_json(field(request, "exit_code"))
          ignore(d.exited(number(field(request, "ticket")), code))
        }
        "cancel" =>
          if d.cancel(text(field(request, "id"))) is Some(a) {
            actions.push(a)
          }
        "retry" => d.retry(text(field(request, "id")))
        "forget" => d.forget(text(field(request, "id")))
        "refresh" => d.refresh(scopes(field(request, "scopes")))
        "observe" => {
          guard live is Some(session) else { raise InvalidInput }
          let current = @native.collect(session.root, session.relative)
          let advice = session.controller.update(
            @pressure.interval(session.previous.snapshot, current.snapshot),
            current.limits,
          )
          d.refresh(live_scopes(current, @admission.Gate::from_advice(advice)))
          session.previous = current
        }
        _ => raise InvalidInput
      }
      snapshot(
        d,
        actions,
        before_tasks != d.tasks() || before_revision != d.revision(),
      )
    } catch {
      error => {
        let state = dispatcher.map(d => snapshot(d, [], false))
        {
          "ok": Json(false),
          "error": Json(error_name(error)),
          "state": match state {
            Some(s) => s
            None => Json::null()
          },
        }
      }
    }
    send(response)
  }
}
