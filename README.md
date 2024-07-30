<h1 align="center">Lustre Limiter</h1>

<div align="center">
  Bringing debounce and throttle utilities to Lustre for the erlang target.

[![Package Version](https://img.shields.io/hexpm/v/lustre_limiter)](https://hex.pm/packages/lustre_limiter)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/lustre_limiter/)

</div>

<br />

Lustre Limiter is available on [Hex](https://hexdocs.pm/lustre_limiter). Add it to your project by using the gleam CLI.

```sh
gleam add lustre_limiter
```

# Acknowledgments

This package is a port from [elm-limiter](https://github.com/hayleigh-dot-dev/elm-limiter) written by [Hayleigh](https://github.com/hayleigh-dot-dev), who was also a huge help in written this Gleam implementation.

## How to use

> In the example, the package as been imported as an alias for simplicity's sake.
>
> ```
> import lustre_limiter as limiter
> ```

In order to use a debouncer or throttler in your Lustre application, you will need a few things.
<br />
First, your model needs to store them as following.

```gleam
type Model {
  Model(
    // ...
    debouncer: limiter.Limiter(Msg),
    throttler: limiter.Limiter(Msg),
  )
}
```

Once done, you then have to declare the relevant Lustre `Msg` that will be sent to your update function when a message has been allowed through, and initialise your model using those `Msg`.

```gleam
pub type Msg {
  // Debounce
  GetInput(String)
  DebounceMsg(limiter.Msg(Msg))
  SearchFor(String)

  // Throttle
  GetClick
  ThrottleMsg(limiter.Msg(Msg))
  AcknowledgeClick
}

fn init(_) -> #(Model, effect.Effect(Msg)) {
  #(
    Model(
      // ...
      debouncer: limiter.debounce(DebounceMsg, 500),
      throttler: limiter.throttle(ThrottleMsg, 500),
    ),
    effect.none(),
  )
}
```

Now comes the `update` function. `GetInput(String)` and `GetClick` will be the two `Msg` attached to our html elements, so their job is to tell the limiter that there is a new event to be process. To do this, we use `limiter.push`. The first element passed to `limiter.push` is the `Msg` we want to receive when the limiter has completed its task and we can now modify our application accordingly, and the second argument is our limiter.

```gleam
pub fn update(model: Model, msg: Msg) -> #(Model, effect.Effect(Msg)) {
  case msg {
    // Debounce
    GetInput(value) -> {
      let #(debouncer, effect) =
        limiter.push(SearchFor(value), model.debouncer)
      #(
        Model(
          // ...
        ),
        effect,
      )
    }
    // ...

    // Throttle
    GetClick -> {
      let #(throttler, effect) =
        limiter.push(AcknowledgeClick, model.throttler)
      #(
        Model(
          // ...
        ),
        effect,
      )
    }
  }
}
```

Since we wrapped our Lustre `Msg` in either `DebounceMsg` or `ThrottleMsg` when initialising our model, our `update` function will receive either of these messages when `limiter.push` is done processing them. This _does not_ mean that we can update our application yet, as we first need to check if the message is allowed. To do so, we use `limiter.update` as followed:

```gleam
pub fn update(model: Model, msg: Msg) -> #(Model, effect.Effect(Msg)) {
  case msg {
    // Debounce
    DebounceMsg(internal_msg) -> {
      let #(debouncer, effect) = limiter.update(internal_msg, model.debouncer)
      #(Model(..model, debouncer: debouncer), effect)
    }
    // ...

    // Throttle
    ThrottleMsg(internal_msg) -> {
      let #(throttler, effect) = limiter.update(internal_msg, model.throttler)
      #(Model(..model, throttler: throttler), effect)
    }
    // ...
  }
}
```

If the message received is authorised by `limiter.update`, our Lustre `update` function will finally receive the `Msg` type we gave to `limiter.push`, either `SearchFor(value)`, or `AcknowledgeClick` in our case. These two can be handle any way you like.
<br />
To - for example - debounce an input field using the example above, you only have to declare an input in your `view` function and set its event attribute to be `event.on_input(GetInput)`.

## Example

You can run the provided example by typing the following and head to [localhost:3000](http://localhost:3000), or read its source code in [/example](/example).

```console
cd example && gleam run
```
