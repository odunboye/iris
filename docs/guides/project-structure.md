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

When the shared module becomes unwieldy, split its pieces into a namespaced
subdirectory, but keep the barrel module and every entry module flat at
`src/` - that's the pattern [Todo](../../examples/todo) actually uses, not a
hypothetical:

```text
src/
  Greeter/
    Model.idr
    Update.idr
    View.idr
  GreeterApp.idr
  Main.idr
  MainWeb.idr
  MainMobile.idr
```

`GreeterApp.idr` imports `Greeter.Model`/`Greeter.Update`/`Greeter.View` and
exports the `UIApp` value (`todoApp`'s role - see
[`TodoApp.idr`](../../examples/todo/src/TodoApp.idr)); each entry module stays
a plain `module MainWeb` importing `GreeterApp`, unchanged from the flat
layout. Don't nest the entry modules themselves under `Greeter.Entry.*`: it
buys nothing over the flat names already here, and it's not what
[Todo's own entry modules](../../examples/todo/src/MainMobile.idr) do. This is
a manual refactor; the current `add` scaffolder generates the flat entry names
above and expects a flat `--module` to import, not a namespaced one.

## Source control

Commit source, package files, `pack.toml`, host HTML/CSS and mobile configuration.
Ignore compiler `build/` directories and `.workspace/`. For native releases,
decide how to preserve deliberate native project edits: the CLI retains native
sources, but generated assets are replaced on sync. See
[ownership and publication](../reference/mobile-capacitor.md#ownership-and-publication).

Do not run `iris new greeter` inside the existing `greeter` project to add
platforms. Use `iris add`; `new` creates a fresh directory and refuses existing
projects.
