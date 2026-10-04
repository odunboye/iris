# Native commands (Iris.Mobile)

A one-page demo of every command `Iris.Mobile` exposes: toast, alert,
confirm, prompt, action sheet, device info, battery info, device id, a
one-shot network status check, and a continuous network-change listener.
See [mobile/README.md](../../mobile/README.md) for the full library.

This demo deliberately uses `runWeb`, not `runMobile`/Canvas: `Iris.Mobile`'s
commands only need `globalThis.IdrisCapacitor` (the native bridge global),
not any particular renderer, so DOM rendering makes every result a real,
inspectable text line instead of a canvas-painted pixel. A real application
would normally pick `runMobile` for mobile metrics (safe areas, touch
targets) - nothing here depends on that choice.

From this repo's root, with a sibling `capacitor` checkout (see
[the tutorial](../../docs/tutorials/web-to-android.md) if you don't have
one):

```sh
pack --no-prompt install iris
pack --no-prompt --cg javascript build examples/mobile-commands/web.ipkg
python3 -m http.server 8080 --directory examples/mobile-commands
```

Open `http://127.0.0.1:8080/`.

## Why there's a mock bridge, and what it proves

`globalThis.IdrisCapacitor` only exists inside a real Capacitor-wrapped
WebView (registered by `capacitor/js/register.mjs` when a packaged app
starts) - it's never present in a plain browser tab, let alone in this
repo's own test environment. `index.html` fills it in with a mock for this
demo: a verbatim copy of `capacitor/js/bridge.mjs`'s `createBridge` (same
validation logic a real device goes through, `export` removed so it works as
a plain script) wired to a `mockPlugins` object with fake native responses,
following the same technique [mobile/tests/runtime.mjs](../../mobile/tests/runtime.mjs)
uses to test the Idris adapter itself without a device.

That means this demo proves the typed command plumbing - `Iris.Mobile`'s
options encode correctly, results decode into the right typed record, and
errors surface as `MobileError` - but **not** that any given native SDK call
behaves a particular way on a real device. Native device behavior, physical
back-button handling and permission prompts remain separate, heavier
validation (`./iris run android/ios`, an emulator, a physical device).

## What to try

Click every button - the log at the bottom (newest first) shows each typed
result via its derived `Show` instance:

- **Toast / Alert / Confirm / Prompt / Action sheet** - one-shot
  `CompletingTask` commands (`toastCommand`, `alertCommand`,
  `confirmCommand`, `promptCommand`, `actionSheetCommand`).
- **Device info / Battery info / Device id** - one-shot queries
  (`deviceInfoCommand`, `batteryInfoCommand`, `deviceIdCommand`).
- **Network status** - a single `networkStatusCommand` check.
- **Watch network** - `networkChanges`, a `CancellableTask`: the mock fires a
  random connectivity flip every 4 seconds, and each one lands as its own
  log line for as long as the page stays open. There's no "stop" button -
  cancellation in this framework is runtime-driven (pause/quit/HMR), not
  something application code triggers on demand; reload the page to stop it.
