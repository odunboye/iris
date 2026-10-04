# Optional Capacitor integration

This covers this repo's own application-packaging/build CLI for Capacitor
targets (`./iris setup/check/compile/build/sync/open/run/new/add`) - it
packages whatever UI application you point it at. The `Iris.Mobile` library
itself (Capacitor command/subscription bindings, native session persistence)
has its own [mobile library guide](../mobile/README.md).

## Architecture

```
Application
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

Add `iris.mobile.json` to the application's project directory (or pass an
explicit `--config FILE` for a disposable packaging experiment) - `./iris
new`/`add` write this for you (see below):

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

`ui` names the UI ipkg to compile for this target; `./iris new`/`add` always
set it. Other keys are required; unknown and duplicate keys are rejected.
Paths resolve relative to `--project`, even with an external config file.
`entry` is a compiled,
standalone Idris browser program. `webDir/index.html` must have exactly one
`<script src="app.js"></script>` (or its module equivalent); packaging
replaces it with the bundled module entry. Public assets are an explicit
allowlist of non-recursive globs. JavaScript source, JSON/private metadata,
hidden files, symlinks and escaping paths are not copied as public assets.
The compiled entry is supplied separately. Native identity changes are
refused once a host exists; migration requires deliberate host management.

## Starting a project

`./iris new <name>` is a project starter, the same shape as `pack new bin
<name>`: run from the intended parent directory, it creates `./<name>/` from
nothing - a starter model module (a trivial counter exporting `app : UIApp
Nat Msg`), `pack.toml` (pinning `iris` as a git dependency at this checkout's
current commit), and, with no `--target` given, both the `web` and `mobile`
targets (each with its entry module, ipkg and HTML/config shell). It refuses
to run if `<name>` already exists.

```sh
./iris new greeter                          # web + mobile by default
./iris new greeter --target web             # web only, explicitly
./iris new greeter --target terminal canvas # any explicit target list
```

`mobile` only drops out of that default pair if no capacitor checkout is
known *and* none can be cloned automatically right now (offline, GitHub
unreachable, ...) - scaffolding still succeeds with `web` alone in that case,
with a note explaining why; see below. An explicit `--target mobile` has no
such fallback and fails loudly instead, since you asked for it specifically.

`./iris add <target> [<target> ...]` adds a target to the project in the
**current directory** - run it from inside a project `new` already created.
It never creates a project or touches the existing module, `pack.toml`, or
any previously generated target; it only appends the new target's own files
and its `[custom.all.<name>-<target>]` entry, where `<name>` is the current
directory's name:

```sh
cd greeter && ./iris add mobile   # --app-id optional here too; see below
```

Both commands' `--module` (default: `<Name>`, the project/current directory
name capitalized) only matters for `new`'s starter generation; `add` always
expects the module to already exist, matching whatever `new` generated or
you wrote by hand. The `terminal` target's `prebuild` embeds this checkout's
own `c/iristui.c` by absolute path - that native source isn't resolvable
through Pack's dependency cache, unlike the pure-Idris targets. The `mobile`
target also writes `iris.mobile.json`. `--app-id` defaults to
`com.example.<name>` (non-alphanumeric characters stripped, a leading
`app` added if what's left wouldn't start with a letter) when not given -
printed so it isn't missed, and meant to be changed before a real release,
not shipped as-is. `--app-name` defaults to the project name. `new`/`add`
warn if `pack.toml` doesn't register every
dependency - including `iris` itself - as `type = "local"`, since `./iris
compile`/`build` require that (see Architecture above); a freshly created
project's `pack.toml` never satisfies this on its own, since `iris` is pinned
as a git dependency there. `add` refuses to overwrite an existing target's
files unless `--force` is passed; `new` never needs `--force`, since it
always starts from nothing.

Neither command needs `--capacitor` at all, let alone typed out each time.
Resolution order, cheapest first: an explicit `--capacitor`; the path
remembered from the last `./iris setup --capacitor PATH` (below)
(`$XDG_CONFIG_HOME/iris/capacitor-path`, or `~/.config/iris/capacitor-path`);
failing both, `new`/`add` clone [odunboye/capacitor](https://github.com/odunboye/capacitor)
into `$XDG_CACHE_HOME/iris/capacitor` (or `~/.cache/iris/capacitor`), run its
locked npm install and this tooling's own, and remember that path for next
time - the same setup `./iris setup` does by hand, done automatically the
first time a target actually needs it. This only ever happens once per
machine; every call after the first hits the remembered path directly. Pack's
own git-dependency cache can't stand in for this: it only fetches what Idris
compilation needs (the `.ipkg` and the modules actually imported), not the
full checkout `npm ci`/the native plugin files require. For `new`'s implicit
`web mobile` default specifically, a clone failure is caught and downgrades
to `web` alone with an explanatory note rather than failing the whole
command - scaffolding a project shouldn't require network access to succeed
at all. An explicit `--target mobile` (on `new` or `add`) gets no such
downgrade: that failure is reported and the command exits nonzero, since
mobile was asked for by name.

## Commands

```sh
./iris setup --capacitor /path/to/capacitor
./iris check --capacitor /path/to/capacitor

./iris compile     # --project defaults to the current directory; pass it
./iris build       # explicitly (--project /path/to/app) to run against a
./iris sync ios    # project you aren't standing inside
./iris sync android
./iris open ios
./iris run android

./iris install-cli  # install this launcher onto PATH
```

Setup is explicit and runs locked npm installs for the library and this
tooling, without package lifecycle scripts; it (and `check`) also remember
the given `--capacitor` path for `new`/`add`, as described above. No other
command installs mobile dependencies. Compile only builds the selected UI
target; run the
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
