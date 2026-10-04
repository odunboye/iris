# Application API and module map

This is a navigation reference for the supported application surface. Follow
links to the source for full signatures, record fields and implementation
comments. It is not generated per-symbol API documentation.

## Application contract

`import Iris` re-exports `Iris.App`, `Iris.Widget`, `Iris.Effect.Command` and
`Iris.Platform.Event`. It does not re-export the legacy App/Sub/PAL contract.

| `UIApp model msg` field | Type |
|---|---|
| `init` | `(model, Cmd msg)` |
| `update` | `msg -> model -> (model, Cmd msg)` |
| `view` | `model -> Widget msg` |
| `handleEvent` | `model -> Event -> Maybe msg` |
| `tickMsg` | `Maybe msg` |

Constructor: `MkApp`. Source: [Iris.App](../../src/Iris/App.idr).

## Widgets and styles

[Iris.Widget](../../src/Iris/Widget.idr) defines the portable tree:

| Family | Helpers | Styled constructors |
|---|---|---|
| Text | `text`, `wrappedText` | `WText`, `WWrapText` |
| Controls | `button`, `input`, `checkbox` | `WButton`, `WInput`, `WCheckbox` |
| Layout | `vstack`, `hstack`, `spacer`, `divider`, `scrollView` | `WVStack`, `WHStack`, `WSpacer`, `WDivider`, `WScroll` |
| Indicators | `progress`, `spinner`, `sparkline` | `WProgress`, `WSpinner`, `WSparkline` |

Controls emit messages. `input` takes the current String and a
`String -> msg` callback; `checkbox` takes a Bool and a toggle message.
`Widget` is a Functor, allowing child messages to map into parent messages.

`Style` starts from `defaultStyle`; `styled` combines modifiers. Color helpers
are `fg`, `bg`, `sfg`, `sbg`; typography helpers are `sBold`, `sItalic`,
`sUnderline`. Layout modifiers include `sFixedW`, `sFixedH`, `sPadH`, `sPadV`,
`sPad`, `sFillH`, `sFillV`, `sFill`, `sBorder` and `sTitle`. `sSecret` masks
input presentation. [Form metadata](../guides/forms.md) covers identity,
disabled/read-only state, accessibility, validation and focus. Prefer modifiers
to positional `MkStyle`/`MkControlOptions` construction.

## Commands

[Iris.Effect.Command](../../src/Iris/Effect/Command.idr) owns `Cmd`:
`None`, `Batch`, `MapCmd`, `Task`, `StreamTask`, `CancellableTask`,
`CompletingTask`, `QuitApp`. Helpers: `none`, `batch`, `quit`; Functor maps
result messages. See [command semantics](../concepts/application-loop.md).

## Runners

| Import | Entry functions |
|---|---|
| [Iris.Backend.Web.DOM.Run](../../src/Iris/Backend/Web/DOM/Run.idr) | `runWeb`, `runWebHot` (requires explicit `HotState` codec) |
| [Iris.Backend.Canvas.Run](../../src/Iris/Backend/Canvas/Run.idr) | `runCanvas`, `runMobile`, `runCanvasOn` |
| [Iris.Backend.Terminal.Run](../../src/Iris/Backend/Terminal/Run.idr) | `runTUI` |

`runWeb`, `runCanvas`, `runMobile`, `runTUI` take `UIApp model msg -> IO ()`.
`runCanvasOn` selects a Canvas and cell metric; legacy size arguments are
retained but the viewport is measured each frame. Desktop SDL2, framebuffer
and generic PAL paths are experimental, not equivalent supported runners.

## Events

[Iris.Platform.Event](../../src/Iris/Platform/Event.idr) defines `KeyboardEvent`,
`PointerEvt`, `ScrollEvt`, `WindowEvt`, `LifecycleEvt`, `CompositionEvt`,
`TextInput`, `Tick` and `Custom`. Availability varies by backend.

Keyboard keys use names such as `Enter`, `ArrowUp` and `i`; action is `KeyDown`,
`KeyUp` or `KeyRepeat`. Lifecycle includes visibility, pause/resume, back requests
and location changes. EventWire is an internal versioned boundary, not a public
network protocol; see [API policy](../../API_STABILITY.md#eventwire-guarantees).

## Additional modules

| Area | Reference |
|---|---|
| Browser HTTP | [Iris.Effect.Http.Web](../../src/Iris/Effect/Http/Web.idr): options, requests and explicit retry policies |
| Routing | [Iris.Router.Types](../../src/Iris/Router/Types.idr), [Iris.Router.Web](../../src/Iris/Router/Web.idr), [router tests](../../tests/RouterTest.idr) |
| Layout metrics | [Iris.Backend.Canvas.Layout](../../src/Iris/Backend/Canvas/Layout.idr) |
| RPC transport and authentication | [iris-client](../../client/README.md) |
| Native commands, listeners and sessions | [iris-mobile](../../mobile/README.md) |
| Compatibility boundary | [API stability](../../API_STABILITY.md), [migration](../../MIGRATION.md) |

For release guarantees and limitations, use the
[capability matrix](../../CAPABILITIES.md), not the package manifest alone.
