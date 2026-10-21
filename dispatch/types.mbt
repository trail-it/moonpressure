///|
pub(all) suberror DispatchError {
  Invalid(String)
  UnknownJob(String)
  StaleAttempt
} derive(Debug, Eq)

///|
pub(all) enum State {
  Queued
  Starting
  Running
  Stopping
  Succeeded
  Failed
  Cancelled
} derive(Debug, Eq)

///|
pub(all) enum Action {
  Start(String, Int64)
  Stop(String, Int64)
} derive(Debug, Eq)

///|
pub struct TaskView {
  id : String
  state : State
  ticket : Int64?
  exit_code : Int32?
} derive(Debug, Eq)

///|
priv struct Task {
  job : @admission.Job
  mut state : State
  mut ticket : Int64?
  mut exit_code : Int32?
  mut order : Int64
}

///|
pub fn State::label(self : State) -> String {
  match self {
    Queued => "queued"
    Starting => "starting"
    Running => "running"
    Stopping => "stopping"
    Succeeded => "succeeded"
    Failed => "failed"
    Cancelled => "cancelled"
  }
}

///|
fn terminal(state : State) -> Bool {
  state == Succeeded || state == Failed || state == Cancelled
}

///|
fn next(value : Int64) -> Int64 raise DispatchError {
  guard value < 9223372036854775807L else {
    raise Invalid("sequence exhausted")
  }
  value + 1L
}

///|
pub fn Action::to_json(self : Action) -> Json {
  match self {
    Start(id, ticket) =>
      {
        "kind": Json("start"),
        "id": Json(id),
        "ticket": Json(ticket.to_string()),
      }
    Stop(id, ticket) =>
      {
        "kind": Json("stop"),
        "id": Json(id),
        "ticket": Json(ticket.to_string()),
      }
  }
}

///|
pub fn TaskView::to_json(self : TaskView) -> Json {
  {
    "id": Json(self.id),
    "state": Json(self.state.label()),
    "ticket": match self.ticket {
      Some(t) => Json(t.to_string())
      None => Json::null()
    },
    "exit_code": match self.exit_code {
      Some(c) => Json(c)
      None => Json::null()
    },
  }
}

///|
pub extend DispatchError with Debug::{to_repr}

///|
pub extend DispatchError with Eq::{equal, not_equal}

///|
pub extend State with Debug::{to_repr}

///|
pub extend State with Eq::{equal, not_equal}

///|
pub extend Action with Debug::{to_repr}

///|
pub extend Action with Eq::{equal, not_equal}

///|
pub extend TaskView with Debug::{to_repr}

///|
pub extend TaskView with Eq::{equal, not_equal}
