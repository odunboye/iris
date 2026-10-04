# The application loop and effect lifetime

An Iris application has three types: the model describing its current state,
messages describing actions/results, and a widget tree parameterized by those
messages. `UIApp model msg` ties them together.

1. The runner starts with `init`, renders the model and starts its commands.
2. A control, platform event, tick or effect delivers a message.
3. `update message model` returns a new model and commands.
4. The runner renders the new view and interprets those commands.

Keep `view` and `update` pure. Represent IO as `Cmd`, with its result converted
into a message. `handleEvent` maps a typed `Event` and the current model to an
optional message; a button's message needs no separate event mapping.
`tickMsg` requests a recurring message at roughly 100 ms intervals. It is not
a precise scheduler.

## Sharing an application

Share the application contract, not assumptions about pixels or interaction.
DOM controls have browser layout and native focus. Canvas paints a cell-based
layout and provides a semantic control overlay. Terminal applications map key
input themselves. See [capabilities](../reference/capabilities.md).

## Starting and completing effects

`none` does nothing; `quit` stops the runner. `batch` starts commands in list
order. It is not a promise of parallel execution or ordered results. Browser
raw `Task` runs inline; terminal raw `Task` runs on a worker. Asynchronous
operations that return promptly can overlap.

Use `CompletingTask` for finite asynchronous work. Its starter receives `send`
and `complete`, arranges the operation, and returns a cancellation action
promptly. Deliver the final message before calling `complete`. Completion
retires the cleanup registration and suppresses further messages; normal
completion does not invoke the cancellation action. Release normally completed
resources yourself. Completion is idempotent and may precede the starter's
return.

Use `CancellableTask` for an ongoing listener. Its starter receives `send` and
returns cleanup promptly. Managed runners invoke cleanup when the operation is
cancelled. Arbitrary `Task`/`StreamTask` IO cannot be forcibly interrupted.

## Pause, resume and shutdown

Browser runners cancel managed effects when suspended and reject stale
callbacks. Resume does not replay commands automatically. Re-establish desired
listeners in response to lifecycle events; do not blindly replay one-shot
operations such as a native dialog or write.

Terminal shutdown/Ctrl+C cancels cooperative effects. Canvas quit removes its
overlay, event listeners and generated stylesheet. This cleanup does not prove
that arbitrary external IO or an already-started native action was undone.

The older `Iris.State.TEA.App` has a subscription contract. `UIApp` has no `Sub`
field; mixing the two application APIs leads to misleading examples.
See [API policy](../reference/api-stability.md).
