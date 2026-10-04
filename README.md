# Iris

`iris` was originally built inside [Flux](https://github.com/odunboye/flux)
(as `flux-ui`, itself an outright rename of this framework's own earlier,
pre-Flux name, `iris`) and later moved back out to its own repo under that
original name, since it has no Flux-specific dependencies (its `ipkg`
depends only on `contrib`). The module prefix changed from `Flux.UI.*` back
to `Iris.*` as part of that move. Flux's generated RPC client (`flux-client`)
and Capacitor glue (`flux-mobile`) turned out to have the same property - no
real dependency on Flux - and later joined this repo too, as the
[`iris-client`](client/README.md) and [`iris-mobile`](mobile/README.md)
sub-packages. Flux's own mobile CLI packaging/bundling tooling stayed in
Flux regardless, the same way its application build/dev CLI stays put
regardless of which UI framework an app imports.

Iris is an experimental cross-platform declarative UI framework for Idris 2.
Applications describe a pure model/update/view loop and render through terminal,
Web DOM, or HTML Canvas/Capacitor backends.

> **Release status:** `0.4.x` preview APIs. The TUI and Web foundations are
> usable previews. Capacitor bundles are portable and tested in browsers, but
> native store releases still require platform-specific device validation.

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
- Node.js `20.x` for browser tests and Capacitor tooling
- A C compiler for the terminal support library

Native validation additionally requires Xcode and/or the Android SDK.

## Install

```bash
pack --no-prompt install iris
```

To use this as a pinned git dependency from another project's `pack.toml`
(the way Flux itself now does), see `workspace.json`'s `external_packages` in
the [Flux repo](https://github.com/odunboye/flux) for the current pattern.

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

See [`WEB_MOBILE_COMPLETION.md`](WEB_MOBILE_COMPLETION.md) for the complete
release checklist.

## Packaging CLI

`./iris` packages a compiled Iris application for a Capacitor WebView (moved
here from Flux's `flux mobile ...`, since it has no dependency on Flux's
server):

```bash
./iris setup --capacitor /path/to/capacitor
./iris build --project /path/to/app
./iris sync ios --project /path/to/app
./iris install-cli   # install this launcher onto PATH
```

See [`design/MOBILE_CAPACITOR.md`](design/MOBILE_CAPACITOR.md) for
configuration, the full command reference, and ownership/publication
mechanics.

## Supported scope

See [the capability matrix](CAPABILITIES.md) for controls, layout, input, focus,
accessibility, cancellation and lifecycle differences, and
[the implemented architecture](ARCHITECTURE.md) for the application contract.


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

See [`API_STABILITY.md`](API_STABILITY.md), [`SECURITY.md`](SECURITY.md), and
[`CHANGELOG.md`](CHANGELOG.md) before deploying.

## License

MIT — see [`LICENSE`](LICENSE).
