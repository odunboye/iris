# Iris Mobile (optional preview)

`Chequra → Iris.Mobile → capacitor → Capacitor`.

This package adapts the existing typed library; it does not implement a second
JavaScript/native bridge or replace the DOM/Canvas renderer. It is intentionally
outside the default workspace dependency map so server and ordinary browser
builds do not install Capacitor. Requires `capacitor >= 0.3.0` and `iris >= 0.4.0`.

## Use

Import `Iris.Mobile`. The module exposes plugin option/result types and named
Iris commands: `toastCommand`, `alertCommand`, `confirmCommand`, `promptCommand`,
`actionSheetCommand`, `networkStatusCommand`, `deviceInfoCommand`,
`batteryInfoCommand`, and `deviceIdCommand`.

```idris
-- Message constructor: NetworkLoaded : Either MobileError NetworkStatus -> Msg
networkStatusCommand NetworkLoaded
-- One-shot init command with owned ongoing callbacks:
networkChanges NetworkLoaded
-- Alternatively, for TEA App's subscription API:
networkSubscription "mobile-network" NetworkLoaded
```

`perform` adapts a typed `Async JS [JSErr] a` plugin operation into a
`CancellableTask`. Errors are messages. Operations are invoked once, with no
retry/resume replay. Cancellation suppresses late results but **cannot undo an
already-started native operation**. It must never be used to imply that a
payment/dialog/permission request was rolled back.

Network listeners are removed on cancellation, including registration races.
Iris's runtime cancels effects on pause/shutdown and compatible HMR disposal.
Applications must explicitly re-establish desired monitoring on resume; this
must not replay one-shot commands. The adapter also gates error/event delivery
after disposal. The current upstream async-js runner prints a completion message
to the console for each finished command; it does not shut down the Iris app.

The bundled Capacitor registration must load before the application. Installing
the Idris package alone does not register native JavaScript plugins.

## Origin-bound RPC

`Iris.Mobile.Client.mobileClient` constructs a client only when a format-2 mobile
bundle provides an explicit canonical HTTPS `apiOrigin`. It never falls back to
the WebView origin. POSTs are restricted to that origin's `/rpc/v1/` routes;
redirects, cookies, caches, unsupported headers and automatic retries are disabled.
Responses are bounded while streaming, and cancellation suppresses late delivery.
Use this transport for mobile authentication and ledger RPC, not native HTTP
plugins which bypass browser origin policy.

## Native sessions (iris-mobile 0.2 / capacitor 0.3)

`Iris.Mobile.Session` supplies `openSessionCommand`, `readSessionCommand`,
`saveSessionCommand`, `clearSessionCommand` and a strict token/intent codec.
No account metadata is stored. Use the portable read-only `Auth.me` command to
validate identity after reading an active token, then fetch current account data.
A `RevokingSession` is durable logout intent: never use it to authenticate a UI
session and never replay remote revocation without an explicit user action.

Vault writes use native revision CAS. Clearing rotates the revision; cancellation
and timeouts cannot undo a save already in progress. Re-read after uncertain saves
instead of resubmitting credentials. A native storage failure is an error, not
permission to fall back to Preferences or browser storage. Only actual web mode
returns `Nothing` (an explicitly memory-only preview).

`mobile sync` snapshots the library's local native plugin, installs it into an
owned host, and sets Capacitor `loggingBehavior: 'none'`. The vault refuses access
with bridge logging enabled because SDK debug logs can expose payloads. Modified
managed dependency files are rejected rather than silently adopted.

[odunboye/flux](https://github.com/odunboye/flux)'s `packages/mobile/tests/native_probe.py`
runs actual vault operations against this library on new owned iOS
Simulator/Android emulator instances, driven through Flux's own `flux mobile
build/sync` CLI (it needs a real packaged application, not just this
library). It requires installed SDK runtimes, Node 22+, Xcode on macOS for
iOS, and Java 21 for Android. It does not use or wipe existing devices,
contacts no API, and removes its scratch devices/apps afterward.
Physical-device, biometric and full application lifecycle validation remain separate.

## Packaging and CLI

Application packaging/staging/release tooling
(`flux mobile setup/check/compile/build/sync/open/run`) lives in
[odunboye/flux](https://github.com/odunboye/flux) - see its
[mobile integration design](https://github.com/odunboye/flux/blob/main/design/MOBILE_CAPACITOR.md).
That CLI treats this package the same way it treats `capacitor` itself: an
external dependency, not something vendored into an application's workspace
map.

## Verification

From this repo's root, with a sibling `capacitor` checkout (see this repo's
own `pack.toml` for the expected `../capacitor` path, or point `--capacitor`
elsewhere via Flux's `tools/mobile_check.py`):

```sh
pack --no-prompt build mobile/iris-mobile.ipkg
pack --no-prompt install iris-mobile
pack --no-prompt build mobile/tests/test.ipkg
node --unhandled-rejections=strict mobile/tests/runtime.mjs \
  /path/to/capacitor mobile/tests/build/exec/iris-mobile-test.js
```

This builds the **compiled Idris** adapter test and runs it against the
hardened bridge with mocked SDK plugins. It verifies typed errors, JSON
marshalling, no retries, suppression of cancelled results and idempotent
listener disposal. Build outputs remain ignored under `build/`.

Native permissions, biometrics, camera, dedicated app lifecycle/deep-link plugins
and deployment signing remain separate work. Native persistence does not imply
biometric authorization or complete physical-device validation.
