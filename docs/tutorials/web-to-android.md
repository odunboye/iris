# Your first app: web to Android

Build a counter in a browser, then package the same application for an Android
WebView. The browser target uses semantic DOM controls; Android uses Iris's
Canvas runner with a native-control DOM overlay.

## 1. Prepare the tools

You need Idris 2 0.8.x, Pack, Python 3.11 or newer, and Git for scaffolding and
compilation. Use Node.js 22 or newer and npm for the current mobile packaging
CLI. Android also needs Android Studio, its SDK, a running emulator and a
compatible JDK; JDK 21 was used for the current native validation. The older
Todo example has a separate Capacitor dependency set.

Start with a checkout of this repository. Keep it available: the installed
launcher delegates to that checkout.

```sh
git clone https://github.com/odunboye/iris.git
cd iris
./iris install-cli
```

Ensure the chosen launcher directory (by default `~/.local/bin`) is on PATH.
Run `iris --help` to check it. If you already have a checkout and launcher,
use those instead. `./iris` refers to the repository launcher; it is not copied
into newly generated projects.

## 2. Create a web app

From the directory where you want your projects to live:

```sh
iris new greeter --target web
cd greeter
```

The explicit web target avoids downloading mobile tooling during this first
step. The project contains:

```text
greeter/
  src/
    Greeter.idr
    MainWeb.idr
  web.ipkg
  pack.toml
  index.html
```

`src/Greeter.idr` defines the shared application:

<!-- iris-example: src/Greeter.idr -->
```idris
module Greeter

import Iris

data Msg = Increment

update : Msg -> Nat -> (Nat, Cmd Msg)
update Increment count = (S count, none)

view : Nat -> Widget Msg
view count = vstack
  [ text ("Count: " ++ show count)
  , button "Increment" Increment
  ]

export
app : UIApp Nat Msg
app = MkApp (0, none) update view (\_, _ => Nothing) Nothing
```

`MkApp` supplies initial state and effects, update, view, an event handler, and
an optional tick message. The button already emits `Increment`, so this app
needs no custom event handler. The `export` makes `app` available to entry
modules.

`src/MainWeb.idr` chooses a renderer:

<!-- iris-example: src/MainWeb.idr -->
```idris
module MainWeb

import Greeter
import Iris.Backend.Web.DOM.Run

main : IO ()
main = runWeb app
```

Build and serve the project root:

```sh
pack --no-prompt install iris
pack --no-prompt --cg javascript build web.ipkg
python3 -m http.server 8080 --bind 127.0.0.1
```

Open `http://127.0.0.1:8080/`. You should see `Count: 0`; clicking Increment
changes it to `Count: 1`. Stop the server with Ctrl+C. After editing Idris
source, rebuild `web.ipkg` and reload the page.

`pack.toml` pins Iris to the scaffolding checkout's current commit. That commit
must be available from its git remote. If you scaffold from an unpublished
local commit, use the local dependency configuration in the next step for the
web build as well.

## 3. Add the mobile entry point

From inside `greeter`, run:

```sh
iris add mobile --app-id com.example.greeter --app-name Greeter
```

Iris uses the Capacitor library checkout remembered from setup, or obtains one
in its cache and installs the locked tooling dependencies. You can specify a
full checkout explicitly with `--capacitor /absolute/path/to/capacitor`.
This is the Idris [Capacitor bindings repository](https://github.com/odunboye/capacitor),
not just an npm package directory.

If using an existing checkout, initialize the dependencies explicitly:

```sh
iris setup --capacitor /absolute/path/to/capacitor
```

`add` preserves `Greeter.idr` and the web entry point. It creates
`src/MainMobile.idr`, `mobile.ipkg`, `iris.mobile.json`, `public/index.html`,
and `public/canvas.css`. The mobile entry point is:

<!-- iris-example: src/MainMobile.idr -->
```idris
module MainMobile

import Greeter
import Iris.Backend.Canvas.Run

main : IO ()
main = runMobile app
```

The two entry points share `app` and choose different runners. Mobile is a
Canvas application inside a Capacitor WebView; it does not use Android native
widgets. Keep the generated stylesheet linked in `public/index.html`: it sizes
the Canvas to the viewport independently of its high-DPI bitmap.

## 4. Use a local Iris dependency for mobile compilation

The current `iris compile` command requires every `custom.all` dependency in
`pack.toml` to use `type = "local"`. A freshly scaffolded project pins Iris as
a git dependency, so it needs this one adjustment.

Replace only the `[custom.all.iris]` section with the following. Use the
**absolute path to your real Iris checkout**, replacing the example path:

```toml
[custom.all.iris]
type = "local"
path = "/absolute/path/to/iris"
ipkg = "iris.ipkg"
```

Remove the old `url` and `commit` fields. Leave the generated
`[custom.all.greeter-web]` and `[custom.all.greeter-mobile]` sections intact;
they already use local paths. These paths are machine-specific. Record the
Iris commit used by your release and arrange equivalent checkout paths on
other build machines.

## 5. Compile, package and run

Run these from `greeter`:

```sh
iris compile
iris build
iris run android
```

These commands have separate jobs:

| Command | Result |
|---|---|
| `iris compile` | Compiles the `mobile.ipkg` selected by `iris.mobile.json` to JavaScript |
| `iris build` | Bundles that compiled program, plugins and public assets into a release |
| `iris run android` | Syncs the existing release, builds the native project and launches it |

`build` does **not** compile source. `run` does **not** compile or make a new
web release. Repeat all three after changing Idris source; repeat build and run
after changing public HTML/CSS. Sync refuses an out-of-date release.

Start the Android emulator in Android Studio first. Run `iris run android` in
an interactive terminal and select the running device when prompted. Confirm
that Increment works and the app remains visible for more than a few seconds.
Rotate the emulator to check layout as well.

For the first application with complex native behavior, also test backgrounding,
resume and a physical device. This counter confirms startup and a basic control;
it does not certify all native plugins or release signing.

The generated targets share a build directory. Pack compilation can replace
previous target executables there. When switching back to the DOM app, rebuild
`web.ipkg` before serving it; do not assume both compiled entries remain present.

## 6. Know where the outputs live

```text
build/exec/greeter-mobile           # compiled app
.workspace/mobile/
  build.json                       # current release and its fingerprint
  releases/<id>/                   # bundled app.js, HTML and public assets
  native/
    capacitor.config.json
    android/                       # Gradle project
    ios/                           # created only when syncing iOS
```

Treat releases as generated output. Edit `src/` and `public/`, then rebuild.
Use `iris open android` to sync and open the native project in Android Studio.
For repeatable noninteractive deployment, first run `iris sync android`, then
use the generated host's Capacitor CLI from its own working directory:

```sh
cd .workspace/mobile/native
node node_modules/@capacitor/cli/bin/capacitor run android --target emulator-5554
```

Replace `emulator-5554` with your actual running device ID. The Iris wrapper
currently does not forward `--target`; using the host CLI avoids its selection
prompt. Return to the project root before running Iris packaging commands again.

## Next steps

Read [project structure](../guides/project-structure.md),
[forms](../guides/forms.md), and [effects](../guides/effects.md).
If startup fails, follow [the startup troubleshooting guide](../troubleshooting/startup.md).
