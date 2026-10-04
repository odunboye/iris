# Iris

Iris is an experimental cross-platform declarative UI framework for Idris 2.
Applications describe a pure model/update/view loop and render through terminal,
Web DOM, or HTML Canvas/Capacitor backends.

> **Release status:** `0.4.x` preview APIs. The TUI and Web foundations are
> usable previews. Capacitor bundles are portable and tested in browsers, but
> native store releases still require platform-specific device validation.

## Documentation

Start with [your first app: web to Android](docs/tutorials/web-to-android.md).
The [documentation index](docs/README.md) links project structure, effects, forms,
backend explanations, API/CLI references and troubleshooting.

## Minimal application

```idris
module Main

import Iris
import Iris.Backend.Web.DOM.Run

data Msg = Increment

update : Msg -> Nat -> (Nat, Cmd Msg)
update Increment count = (S count, none)

view : Nat -> Widget Msg
view count = vstack
  [ text ("Count: " ++ show count)
  , button "Increment" Increment
  ]

app : UIApp Nat Msg
app = MkApp (0, none) update view (\_, _ => Nothing) Nothing

main : IO ()
main = runWeb app
```

Use `Iris.Backend.Terminal.Run.runTUI` or
`Iris.Backend.Canvas.Run.runCanvas` for another supported backend.

The complete [counter example](examples/counter/README.md) supplies terminal,
DOM and Canvas entry points, package files and browser hosts.

The [account form](examples/form/README.md) demonstrates disabled/read-only
controls, validation, descriptions and explicit focus across DOM, Canvas and TUI.

The [router example](examples/router/README.md) demonstrates typed routing:
path/query parameters, navigation guards and browser history.

The [RPC client example](examples/client/README.md) demonstrates
`iris-client`'s typed JSON-RPC-over-HTTP calls against a real local server.

## Features

- Elm-style typed state updates and effects
- Platform-independent widget tree
- ANSI terminal, semantic DOM, and Canvas renderers
- Versioned keyboard, pointer, scroll, viewport, composition, lifecycle, and
  navigation events
- Responsive Canvas layout, hit testing, multi-pointer capture, safe areas,
  clipping, and a screen-reader/native-input overlay
- Typed routing with UTF-8 URLs, path/query parameters, base paths, guards, and
  browser history
- Cooperative effect cleanup on supported runners; browser pause/resume support
- Browser HTTP cancellation, timeouts, and response limits
- Idris unit tests and Playwright browser integration tests

## Requirements

- Idris 2 `0.8.x`
- `make`
- Node.js `20.x` for the existing browser test baseline; Node.js `22+` for the current mobile packaging CLI
- Python `3.11+` for the CLI and documentation checks
- Pack and Git for scaffolding/dependency management
- A C compiler for the terminal support library

Native validation additionally requires Xcode and/or the Android SDK.

## Install

```bash
pack --no-prompt install iris
```

`iris new` generates a git-pinned dependency registration for an application;
`iris compile` resolves it automatically (cloning the pinned commit into a
local cache the first time), the same as `--capacitor`. See
[the tutorial](docs/tutorials/web-to-android.md) for the full walkthrough.

## Build and test

```bash
make build          # build iris.ipkg
make test           # Idris test suites
make check          # tests, web/mobile bundles, release validation
make -C examples/todo build-terminal
python3 tests/native_smoke.py  # both native TUI entries, FFI and keyboard shutdown

npm ci
npx playwright install chromium
make browser-test   # real Chromium integration tests
```

The Todo example can be run from `examples/todo`:

```bash
make terminal
make web
make mobile-preview
```

## Sub-packages

- [`client/`](client/README.md) (`iris-client`) - a portable typed
  JSON-RPC-over-HTTP client runtime for Iris applications.
- [`mobile/`](mobile/README.md) (`iris-mobile`) - Capacitor command/
  subscription bindings and native session persistence for Iris's `Cmd`/`Sub`
  model.

## Capacitor validation

Portable bundle validation is included in `make check`. On provisioned native
build machines, run from this repo's root with the same compiler environment:

```bash
make native-check
# or
./scripts/validate-native.sh ios
./scripts/validate-native.sh android
```

See [the release checklist](docs/reference/release-checklist.md) for the
complete list.

## Packaging CLI

`./iris` packages a compiled Iris application for a Capacitor WebView (moved
here from Flux's `flux mobile ...`, since it has no dependency on Flux's
server):

Install the checkout launcher once, then use `iris` inside generated projects:

```bash
./iris install-cli
iris new myapp --target web
cd myapp
iris add mobile
# Configure the local dependency map and mobile tooling, then:
iris compile
iris build
iris run android
```

See [the CLI reference](docs/reference/cli.md) and
[the full web-to-Android tutorial](docs/tutorials/web-to-android.md).
[The packaging design](docs/reference/mobile-capacitor.md) covers detailed
ownership and publication mechanics.

## Supported scope

See [the capability matrix](docs/reference/capabilities.md) for controls, layout,
input, focus, accessibility, cancellation and lifecycle differences, and
[the implemented architecture](docs/concepts/architecture.md) for the
application contract.


| Target | Status |
|---|---|
| Terminal/TUI | Functional flagship backend |
| Web DOM | Supported preview |
| Canvas/Capacitor WebView | Supported preview; native certification required |
| SDL2 desktop | Experimental skeleton |
| Embedded framebuffer | Experimental skeleton |
| Native mobile renderer | Deferred; Capacitor uses the Canvas/WebView target |

Wrapped text and clipped scroll-offset widgets are implemented. General native
Canvas scrolling, richer accessibility metadata and native-device validation
remain limited. Terminal cooperative effects are cancelled on quit/Ctrl+C; raw IO cannot be
forcibly stopped. The legacy
`Iris.Core.Widget`/`Iris.Core.Runtime` path is retained for compatibility; new
applications should use `Iris.Widget` and the specialized runners.

See [API stability](docs/reference/api-stability.md), [`SECURITY.md`](SECURITY.md),
and [the changelog](docs/CHANGELOG.md) before deploying.

## License

MIT — see [`LICENSE`](LICENSE).
