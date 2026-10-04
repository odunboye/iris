# Organize a project and add targets

Keep model, messages, update and view in a shared module that exports a
`UIApp`. Keep each runner import and `main` in its own entry module.

| Generated file | Responsibility |
|---|---|
| `src/Greeter.idr` | Shared application |
| `src/MainWeb.idr` | `runWeb app` |
| `src/MainMobile.idr` | `runMobile app` |
| `src/MainCanvas.idr` | `runCanvas app` |
| `src/Main.idr` | `runTUI app` for the terminal target |
| `<target>.ipkg` | Dependencies, source directory, entry module and executable |
| `pack.toml` | Dependency locations and target registrations |
| `index.html` | Browser DOM host |
| `canvas.html`, `canvas.css` | Browser Canvas host |
| `public/` | Source assets for the packaged mobile host |
| `iris.mobile.json` | Mobile packaging configuration |

Generated targets currently share `build/`. A Pack build can replace earlier
target executables; rebuild the selected target when switching platforms.

Separate entry modules avoid pulling platform-specific runners into every
build. They also give each platform a place for startup configuration later.
A tiny app does not need separate Model, Update and View files.

## Add a target

Run `iris add canvas terminal` from the project root. Adding a target leaves
the shared module and other targets alone. Use `--module Greeter --app-value app`
when your shared module/export differs from the defaults. The current scaffolder
looks for that module in the root or `src`; it does not discover arbitrary
namespaced application modules.

Build the generated targets separately:

```sh
pack --no-prompt --cg javascript build canvas.ipkg
pack --no-prompt build terminal.ipkg
```

Serve `canvas.html` with the same project-root server as the web tutorial.
Run the terminal executable from `build/exec/<project-name>-terminal`.
The starter's button does not supply terminal keyboard interaction: implement
`handleEvent` for key presses. [Counter](../../examples/counter/Counter.idr)
shows `i` to increment and `q` to quit.

The generated terminal package compiles `c/iristui.c` using an absolute path to
the Iris checkout. Keep that checkout available; regenerate or edit the
`prebuild` path when moving a project to another machine.

## Grow into namespaces

When the shared module becomes unwieldy, move it behind modules such as:

```text
src/
  Greeter/
    App.idr
    Model.idr
    Update.idr
    View.idr
    Entry/
      Web.idr
      Mobile.idr
```

Use `module Greeter.Entry.Mobile` in the corresponding file and set
`main = Greeter.Entry.Mobile` in `mobile.ipkg`. Import `Greeter.App` from both
entry modules. This is a manual refactor; the current `add` scaffolder uses the
flat entry names above. Keep a small root `Greeter.idr` facade if you still
want to use its default module discovery.

## Source control

Commit source, package files, `pack.toml`, host HTML/CSS and mobile configuration.
Ignore compiler `build/` directories and `.workspace/`. For native releases,
decide how to preserve deliberate native project edits: the CLI retains native
sources, but generated assets are replaced on sync. See
[ownership and publication](../../design/MOBILE_CAPACITOR.md#ownership-and-publication).

Do not run `iris new greeter` inside the existing `greeter` project to add
platforms. Use `iris add`; `new` creates a fresh directory and refuses existing
projects.
