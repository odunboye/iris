# Optional Capacitor integration

This covers this repo's own application-packaging/build CLI for Capacitor
targets (`./iris setup/check/compile/build/sync/open/run`), moved here from
[odunboye/flux](https://github.com/odunboye/flux) (as `flux mobile *`) since
it has no dependency on Flux's server - it packages whatever UI application
you point it at. The `Iris.Mobile` library itself (Capacitor command/
subscription bindings, native session persistence) has its own
[mobile library guide](../mobile/README.md).

## Architecture

```
Application (Chequra)
    -> Iris.Mobile commands / owned subscriptions
    -> capacitor 0.3 typed bindings + one registered JS bridge
    -> Capacitor 8.4.3
    -> iOS / Android WebView
```

No second native bridge or new renderer is introduced. The packaged
application's own server (if any) remains independent of Capacitor. The
existing DOM UI and CSS are packaged as local assets; native plugins are
bundled before the compiled application. There is no remote `server.url`,
storage snapshot, watcher injection or automatic RPC replay.

`iris-mobile` and `iris-client` already live in this checkout (`mobile/`,
`client/`), alongside `capacitor` (resolved via `--capacitor` or this repo's
own `pack.toml` sibling alias). `./iris compile` adds all three in a
**temporary** Pack map derived from the application's existing local map;
ordinary `pack.toml` files and server dependency registrations are not
rewritten. Prefer a separate mobile UI ipkg if only the mobile target
imports `Iris.Mobile`.

## Configuration

Add `iris.mobile.json` beside an application's `flux.json` (or pass an explicit
`--config FILE` for a disposable packaging experiment):

```json
{
  "format": 1,
  "appId": "com.example.sandbox",
  "appName": "Sandbox App",
  "capacitor": "/path/to/capacitor",
  "webDir": "public",
  "entry": "build/exec/my-app.js",
  "ui": "mobile.ipkg",
  "assets": ["index.html", "*.css", "assets/*.png", "assets/*.svg"]
}
```

For networked applications, use `"format": 2` and add an explicit
`"apiOrigin": "https://your-api.example.com"`. This is an origin, not a route:
no HTTP, userinfo, path/trailing slash, query, fragment or noncanonical default
port. There is no insecure loopback exception. Format 1 remains a packaging-only
preview and cannot initialize `Iris.Mobile.Client.mobileClient`.

Format 2 requires exactly one CSP meta element with `default-src 'self'`,
`script-src 'self'`, `object-src 'none'`, `base-uri 'none'` and `form-action 'none'`.
The explicit format-2 opt-in binds `connect-src` to only the configured HTTPS API;
other directives are preserved, and duplicate directives/script overrides are
rejected. Runtime configuration is immutable and initializes before the app.

`ui` is optional and otherwise comes from `flux.json` (a full-stack
application's own config file, from whichever framework the application's
server uses - packaging itself does not depend on Flux). Other keys are
required; unknown and duplicate keys are rejected. Paths resolve relative to
`--project`, even with an external config file. `entry` is a compiled,
standalone Idris browser program. `webDir/index.html` must have exactly one
`<script src="app.js"></script>` (or its module equivalent); packaging
replaces it with the bundled module entry. Public assets are an explicit
allowlist of non-recursive globs. JavaScript source, JSON/private metadata,
hidden files, symlinks and escaping paths are not copied as public assets.
The compiled entry is supplied separately. Native identity changes are
refused once a host exists; migration requires deliberate host management.

## Scaffolding a target

`./iris new` generates the boilerplate for one backend target in an existing
project - an entry module, an ipkg, and an HTML/config shell - so the hand
steps in [ARCHITECTURE.md](../ARCHITECTURE.md)/the counter example don't have to
be repeated by hand every time. It does not write your model/update/view: it
expects a module already exporting a `UIApp` value (`--app-value`, default
`app`), e.g. `Counter.idr`'s `export counter : UIApp Nat Msg`.

```sh
./iris new --target web      --project /path/to/app --module Counter
./iris new --target terminal --project /path/to/app --module Counter
./iris new --target canvas   --project /path/to/app --module Counter
./iris new --target mobile   --project /path/to/app --module Counter \
  --capacitor /path/to/capacitor --app-id com.example.app
```

`--module`'s file is found under `--project` or `--project/src`, and the
generated files follow it there. `--name` (default: the project directory's
own name) sets the package/executable name (`<name>-web`, `<name>-terminal`,
...). The `terminal` target's `prebuild` embeds this checkout's own
`c/iristui.c` by absolute path - that native source isn't resolvable through
Pack's dependency cache, unlike the pure-Idris targets. The `mobile` target
also writes `iris.mobile.json` (`--app-id` required; `--app-name` defaults to
`--name`) and warns if `pack.toml` doesn't register every
dependency - including `iris` itself - as `type = "local"`, since `./iris
compile`/`build` require that (see Architecture above). Existing files are
left untouched unless `--force` is passed.

## Commands

```sh
./iris setup --capacitor /path/to/capacitor
./iris check --capacitor /path/to/capacitor

./iris compile --project /path/to/app
./iris build --project /path/to/app
./iris sync ios --project /path/to/app
./iris sync android --project /path/to/app
./iris open ios --project /path/to/app
./iris run android --project /path/to/app

./iris install-cli  # install this launcher onto PATH, like ./flux install-cli
```

Setup is explicit and runs locked npm installs for the library and this
tooling, without package lifecycle scripts. No other command installs mobile
dependencies. Compile only builds the selected UI target; run the
application's own schema generation/server checks separately as needed.
Build only packages assets; it does not install an app or start a database.

Sync creates/updates the owned Capacitor host and performs an explicit locked npm
install there. Open/run first sync, then delegate to the pinned local Capacitor
CLI. Native SDK/network/build effects are not transactional or rolled back by an
asset rollback. Projects and outputs are retained for inspection.

The preview tooling supports macOS/Linux, Node 22+, npm and Pack. iOS requires
macOS/Xcode; Android requires its SDK and a compatible JDK (JDK 21 was validated).
Signing, deployment targets, permissions, privacy manifests, release identities
and store submission are application responsibilities.

## Ownership and publication

- `.workspace/mobile/owner.json` binds output ownership to the project.
- Builds use frozen input snapshots and fresh staging directories. Successful
  bundles publish to immutable `releases/<id>` directories with file hashes and
  a source/configuration fingerprint in `build.json`.
- Failure leaves the previous build pointer intact; temporary stages clean up.
- Sync rejects stale sources/configuration and tampered releases, including
  directory symlinks. Unknown output/native-host directories are never adopted.
- An OS-backed project lock prevents concurrent CLI operations. Compiler/bundler/
  SDK subprocesses have owned process groups; failure, timeout and interruption
  stop those groups before releasing the lock. Shared SDK daemons are not owned.
- Native projects live in `.workspace/mobile/native/{ios,android}`. Their source
  files are not regenerated wholesale. Managed npm files/configuration cannot be
  silently overwritten; the owned web tree is staged before replacement.

Checkouts, compiler output and installed dependencies are trusted build inputs.
Hashes detect local release modification; they are not code signing or a complete
supply-chain attestation. The compiler/dependency caches remain Pack's concern.

## Chequra validation and remaining work

Chequra (an external Flux application) was packaged using an external
temporary config, without changing its source, authentication, ledger schema
or ordinary web/server configuration. Its bundled UI boots in Chromium with
registered plugins, and both native projects sync successfully. Unsigned iOS
Simulator Debug and Android Debug APK builds pass. These are packaging/build
checks, **not device-level behavioral certification**.

The ordinary Chequra web entry uses a relative API origin. Networked mobile apps
must use a separate entry calling `Iris.Mobile.Client.mobileClient`, with explicit
format-2 configuration and server origin/CORS policy - see iris-mobile's own
README for the transport's guarantees (origin binding, no redirects/cookies/
retries, bounded streaming) and native session persistence. Hosted deployment
remains separate work. No hosted backend or payment/card service is created by
this integration.

Camera, biometrics, app lifecycle/back/deep-link plugin bindings,
notifications, permission flows and device accessibility testing are subsequent
capabilities—not implied by the five existing plugins. One-shot cancellation
suppresses delivery but cannot undo a started native action. Monitoring restarts
must be explicit and must not replay writes.

## Tests

```sh
python3 -m unittest discover -s tools -p 'test_iris.py'
python3 -m unittest discover -s tools -p 'test_mobile_policy.py'
python3 -m unittest discover -s tools -p 'test_mobile_native.py'
./iris check --capacitor /path/to/capacitor
```

`./iris check` builds and runs iris-mobile's own compiled-Idris adapter
test against the hardened bridge, entirely from local paths - see
`tools/mobile_check.py`. For a packaged release's bundled web content:

```sh
node mobile/tests/browser.cjs /path/to/mobile/releases/ID
```

For actual native vault behavior, with the SDK runtimes already installed:

```sh
python3 tools/native_probe.py --capacitor /path/to/capacitor
```

This creates new scratch devices/apps, never uses existing user devices, and
removes its fixtures and forwards. The iOS 26.5 Simulator probe uses local ad-hoc
signing (unsigned apps cannot be assumed to access Keychain). Android 14/API 34
uses a disposable emulator with its own system PIN; that OS version requires a
secure screen lock for unlocked-device keys. Tests cover cold persistence,
origin isolation, native revision CAS/clear, reinstall reset, and Android
ciphertext/AAD tampering, corrupt data, and locked-device denial. This is not a
physical-device or biometric certification. SDK caches remain as normal. This
test drives real packaging through `./iris build/sync`, exercising the full
pipeline, not just the library.

Pinned core/native/CLI 8.4.3 deliberately avoids the current 8.5.x CLI's vulnerable
xcode/uuid dependency. Library, example and tooling npm audits all reported
zero vulnerabilities during validation; rerun audits as advisories change.
