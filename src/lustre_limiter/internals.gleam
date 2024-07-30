import gleam/erlang/process

import lustre/effect.{type Effect}

pub type State {
  Open
  Close
}

/// The mode of the limiter.
/// The `Debounce` mode will keep track of how many messages have been received
/// in a particular burst. Whenever a message is added to the list, a check is
/// performed some time in the future. If the list hasn't changed by then, the
/// newest message in the list is emitted and the rest are discarded.
/// 
/// The `Throttle` mode only needs to keep track of the interval at which messages
/// are throttled.
/// 
/// Both modes expect the time to be given in _milliseconds_.
pub type Mode(msg) {
  Debounce(Int, List(msg))
  Throttle(Int)
}

pub type Msg(msg) {
  Emit(msg)
  EmitIfSettled(Int)
  None
  Reopen
  Push(msg)
}

pub type Limiter(msg) {
  Limiter(tagger: fn(Msg(msg)) -> msg, mode: Mode(msg), state: State)
}

/// Take a message and dispatch it after a delay.
/// This message will be handle by the `update` function
/// of your Lustre application.
pub fn emit_after(message: msg, delay: Int) -> Effect(msg) {
  use dispatch <- effect.from
  let _ = {
    use <- process.start(_, True)

    process.sleep(delay)
    dispatch(message)
    process.send_exit(process.self())
  }

  Nil
}

/// Dispatch a message immediately.
pub fn emit(message: msg) -> Effect(msg) {
  effect.from(fn(dispatch) { dispatch(message) })
}
