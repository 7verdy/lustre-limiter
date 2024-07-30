import gleam/list
import gleam/result
import lustre/effect.{type Effect}
import lustre_limiter/internals.{Limiter}

// TYPES ----------------------------------------------------------------------

/// The message type for the limiter.
/// This is what the limit uses internally to know what the `glimiter.update` function
/// should do.
pub type Msg(msg) =
  internals.Msg(msg)

/// The limiter type.
/// It holds data about the limiter, such as the tagger function, the mode and the state,
/// so the limiter knows how to behave (.i.e. rate-limit incoming messages).
/// One limiter is required per Lustre `Msg` you want to rate-limit, meaning it needs
/// to be stored within the Lustre `Model`.
pub type Limiter(msg) =
  internals.Limiter(msg)

// API ------------------------------------------------------------------------

/// Create a new debounce limiter.
/// 
/// The way a debounce limiter works is by waiting for a certain amount of time
/// after the last input before processing all the messages that were received.
/// 
/// You can imagine this as a waiter in a restaurant. He waits as long as someone is talking
/// and only when everyone has stopped talking for a certain amount of time,
/// he walks to the kitchen to place the order.
/// 
/// See ['Debounce vs Throttle: Definitive Visual Guide'](https://kettanaito.com/blog/debounce-vs-throttle) by Artem Zakharchenko
/// for a more detailed explanation.
/// 
/// ## Example:
/// ```gleam
/// pub opaque type Model {
///   Model(
///      value: String,
///      debouncer: glimiter.Limiter(Msg),
///   )
/// }
/// 
/// pub fn init(_) -> #(Model, effect.Effect(Msg)) {
///   #(
///     Model(
///       value: "",
///       debouncer: glimiter.debounce(DebounceMsg, 500),
///     ),
///     effect.none(),
///   )
/// }
/// 
/// pub type Msg {
///   ...
///   DebounceMsg(glimiter.Msg(Msg))
/// }
/// ```
/// 
pub fn debounce(tagger: fn(Msg(msg)) -> msg, delay: Int) -> Limiter(msg) {
  Limiter(
    tagger: tagger,
    mode: internals.Debounce(delay, []),
    state: internals.Open,
  )
}

/// Create a new throttle limiter.
/// 
/// Compared to a debouncer, the throttle acts as a valve, letting only one message
/// through every `interval` milliseconds. This means that if you have a burst of messages
/// coming in, the throttle will only let the first one through and then ignore the rest.
/// 
/// See ['Debounce vs Throttle: Definitive Visual Guide'](https://kettanaito.com/blog/debounce-vs-throttle) by Artem Zakharchenko
/// for a more detailed explanation.
/// 
/// ## Example:
/// ```gleam
/// pub opaque type Model {
///   Model(
///     value: String,
///     throttler: glimiter.Limiter(Msg),
///   )
/// }
/// 
/// pub fn init(_) -> #(Model, effect.Effect(Msg)) {
///   #(
///     Model(
///       value: "",
///       throttler: glimiter.throttle(500),
///     ),
///     effect.none(),
///   )
/// }
/// 
/// pub type Msg {
///  ThrottleMsg(glimiter.Msg(Msg))
/// }
/// ```
/// 
pub fn throttle(tagger: fn(Msg(msg)) -> msg, interval: Int) -> Limiter(msg) {
  Limiter(
    tagger: tagger,
    mode: internals.Throttle(interval),
    state: internals.Open,
  )
}

/// Push a message into the limiter.
/// 
/// While we want to limit any action linked to an event - for example, fetching resources
/// on the backend when the user types in a search bar - we don't want to limit the events
/// themselves, otherwise we risk losing the user's input.
/// 
/// To circumvent this, and to not make requests on every keypress, this function is used
/// to manually push a message into the limiter.
/// 
/// ## Example:
/// ```gleam
/// pub fn update(model: Model, msg: Msg) -> #(Model, effect.Effect(Msg)) {
///   case msg {
///     GetInput(value) -> {
///       let #(debouncer, effect) =
///         glimiter.push(SearchFor(value), model.debouncer)
///       #(Model(value, debouncer, model.debounced_value), effect)
///    }
///   SearchFor(value) -> {
///     // Perform whatever action needs to be done once the message is allowed through.
///   }
/// }
/// ```
/// 
pub fn push(msg: msg, limiter: Limiter(msg)) -> #(Limiter(msg), Effect(msg)) {
  case limiter.state, limiter.mode {
    internals.Open, internals.Debounce(cooldown, queue) -> {
      #(
        Limiter(..limiter, mode: internals.Debounce(cooldown, [msg, ..queue])),
        internals.emit_after(
          limiter.tagger(internals.EmitIfSettled(list.length(queue) + 1)),
          cooldown,
        ),
      )
    }
    internals.Open, internals.Throttle(interval) -> #(
      Limiter(..limiter, state: internals.Close),
      effect.batch([
        internals.emit_after(limiter.tagger(internals.Reopen), interval),
        internals.emit(msg),
      ]),
    )
    internals.Close, _ -> #(limiter, effect.none())
  }
}

/// Update the limiter.
/// 
/// The limiter works using its own `Msg` values to update its internal state.
/// When you create a limiter, you need to provide a "tagger" function that wraps these
/// internal messages into a type that the Lustre `update` function can understand.
/// 
/// This function should be called in the Lustre `update` when you get
/// a "wrapper" message from the limiter. (i.e. `DebounceMsg` or `ThrottleMsg`).
/// 
/// ## Example:
/// ```gleam
/// pub fn update(model: Model, msg: Msg) -> #(Model, effect.Effect(Msg)) {
///   case msg {
///    ...
///     DebounceMsg(internal_msg) -> {
///       let #(debouncer, effect) = glimiter.update(internal_msg, model.debouncer) 
///       #(Model(..model, debouncer: debouncer), effect)
///     }
///   }
/// }
/// ```
/// 
pub fn update(
  internal_msg: Msg(msg),
  limiter: Limiter(msg),
) -> #(Limiter(msg), Effect(msg)) {
  case internal_msg, limiter.state, limiter.mode {
    internals.Emit(msg), internals.Open, internals.Throttle(interval) -> #(
      Limiter(..limiter, state: internals.Close),
      effect.batch([
        internals.emit_after(limiter.tagger(internals.Reopen), interval),
        internals.emit(msg),
      ]),
    )
    internals.EmitIfSettled(count),
      internals.Open,
      internals.Debounce(cooldown, queue)
    -> {
      case list.length(queue) == count {
        True -> #(
          Limiter(..limiter, mode: internals.Debounce(cooldown, [])),
          queue
            |> list.first
            |> result.map(fn(msg) { internals.emit(msg) })
            |> result.unwrap(effect.none()),
        )
        False -> #(limiter, effect.none())
      }
    }
    internals.Reopen, _, _ -> #(
      Limiter(..limiter, state: internals.Open),
      effect.none(),
    )
    internals.Push(msg), internals.Open, internals.Debounce(cooldown, queue) -> {
      #(
        Limiter(..limiter, mode: internals.Debounce(cooldown, [msg, ..queue])),
        internals.emit_after(
          limiter.tagger(internals.EmitIfSettled(list.length(queue) + 1)),
          cooldown,
        ),
      )
    }
    _, _, _ -> #(limiter, effect.none())
  }
}
