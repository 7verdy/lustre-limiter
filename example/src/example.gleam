import gleam/int
import lustre/ui/button

import lustre_limiter as limiter

import lustre
import lustre/attribute
import lustre/effect
import lustre/element.{type Element}
import lustre/element/html
import lustre/event
import lustre/ui

// MAIN ------------------------------------------------------------------------

pub fn app() {
  lustre.application(init, update, view)
}

// MODEL -----------------------------------------------------------------------

pub opaque type Model {
  Model(
    value: String,
    debouncer: limiter.Limiter(Msg),
    debounced_value: String,
    throttler: limiter.Limiter(Msg),
    total_clicks: Int,
    throttled_count: Int,
  )
}

pub fn init(_) -> #(Model, effect.Effect(Msg)) {
  #(
    Model(
      value: "",
      debouncer: limiter.debounce(DebounceMsg, 500),
      debounced_value: "",
      throttler: limiter.throttle(ThrottleMsg, 500),
      throttled_count: 0,
      total_clicks: 0,
    ),
    effect.none(),
  )
}

// UPDATE ----------------------------------------------------------------------

pub type Msg {
  GetInput(String)
  GetClick
  SearchFor(String)
  AcknowledgeClick
  DebounceMsg(limiter.Msg(Msg))
  ThrottleMsg(limiter.Msg(Msg))
}

pub fn update(model: Model, msg: Msg) -> #(Model, effect.Effect(Msg)) {
  case msg {
    // Debounce
    GetInput(value) -> {
      let #(debouncer, effect) = limiter.push(SearchFor(value), model.debouncer)
      #(Model(..model, value: value, debouncer: debouncer), effect)
    }
    SearchFor(value) -> {
      #(Model(..model, debounced_value: value), effect.none())
    }
    DebounceMsg(internal_msg) -> {
      let #(debouncer, effect) = limiter.update(internal_msg, model.debouncer)
      #(Model(..model, debouncer: debouncer), effect)
    }

    // Throttle
    GetClick -> {
      let #(throttler, effect) = limiter.push(AcknowledgeClick, model.throttler)
      #(
        Model(
          ..model,
          throttler: throttler,
          total_clicks: model.total_clicks + 1,
        ),
        effect,
      )
    }
    ThrottleMsg(internal_msg) -> {
      let #(throttler, effect) = limiter.update(internal_msg, model.throttler)
      #(Model(..model, throttler: throttler), effect)
    }
    AcknowledgeClick -> {
      #(
        Model(..model, throttled_count: model.throttled_count + 1),
        effect.none(),
      )
    }
  }
}

// VIEW ------------------------------------------------------------------------

pub fn view(model: Model) -> Element(Msg) {
  let styles = [#("width", "100vw"), #("height", "100vh"), #("padding", "1rem")]

  ui.centre(
    [attribute.style(styles)],
    html.div(
      [
        attribute.style([
          #("display", "flex"),
          #("flex-direction", "column"),
          #("justify-content", "center"),
          #("gap", "3rem"),
        ]),
      ],
      [
        html.div([], [
          ui.field(
            [],
            [element.text("Write a message:")],
            ui.input([attribute.value(model.value), event.on_input(GetInput)]),
            [],
          ),
          html.p([], [
            element.text("debounced value: " <> model.debounced_value),
          ]),
        ]),
        html.div(
          [
            attribute.style([
              #("display", "flex"),
              #("flex-direction", "row"),
              #("align-items", "center"),
              #("gap", "3rem"),
            ]),
          ],
          [
            button.button([event.on_click(GetClick)], [
              element.text("Click me!"),
            ]),
            html.div(
              [
                attribute.style([
                  #("display", "flex"),
                  #("flex-direction", "row"),
                  #("gap", "1rem"),
                ]),
              ],
              [
                html.div([], [
                  html.p([], [element.text("Total clicks: ")]),
                  html.p([], [element.text("Clicks acknowledged: ")]),
                ]),
                html.div([], [
                  html.p([], [element.text(int.to_string(model.total_clicks))]),
                  html.p([], [
                    element.text(int.to_string(model.throttled_count)),
                  ]),
                ]),
              ],
            ),
          ],
        ),
      ],
    ),
  )
}
