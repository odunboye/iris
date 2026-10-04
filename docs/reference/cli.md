# CLI commands

Run `iris --help` and `iris <command> --help` for the parser's current options.
The installed `iris` delegates to a checkout's `./iris`; it is not an Idris
package executable. The CLI requires Python 3.11+ and currently supports
macOS/Linux for mobile operations.

## Scaffolding and launcher

| Command | Behavior | Main options |
|---|---|---|
| `iris install-cli` | Install a checkout launcher, default `~/.local/bin` | `--bin-dir`, `--force` (backs up an existing launcher) |
| `iris new NAME` | Create a fresh project directory | `--target web mobile canvas terminal`, `--project`, `--module`, `--app-value`, `--capacitor`, `--app-id`, `--app-name` |
| `iris add TARGET...` | Add targets to the current project | `--module`, `--app-value`, `--capacitor`, `--app-id`, `--app-name`, `--force` |

Without `--target`, `new` attempts web and mobile. It falls back to web if it
cannot obtain mobile tooling. An explicit mobile target reports setup failure
instead of dropping the requested target. Existing projects are refused;
`add --force` overwrites that target's generated files.

Capacitor checkout resolution uses the explicit option, a remembered setup
path, then automatic cache setup. Details live in
[the packaging design](../../design/MOBILE_CAPACITOR.md#starting-a-project).
The default app ID is a printed `com.example.*` development identity.

## Setup and validation

| Command | Behavior |
|---|---|
| `iris setup --capacitor PATH` | Install locked npm dependencies for bindings and packaging; remember PATH |
| `iris check --capacitor PATH` | Compile and run the Idris mobile adapter test against the bridge; remember PATH |

`check` checks the adapter, not your application or physical device. It expects
an initialized library/tooling environment; run setup first.

## Mobile pipeline

All these commands accept `--project PATH` (default: current directory) and
`--config FILE`. Configuration paths remain relative to the project even when
the config file is elsewhere.

| Command | Behavior |
|---|---|
| `iris compile` | Compile the UI package selected in configuration; requires a local Pack map |
| `iris build` | Bundle the existing compiled entry and allowed assets into a release |
| `iris sync android` / `ios` | Verify the release and sync an owned native host; performs host npm install |
| `iris open android` / `ios` | Sync, then open the platform IDE |
| `iris run android` / `ios` | Sync, then delegate native build/deployment to Capacitor |

Compile and build are separate; sync/open/run do neither automatically. Sync
rejects a stale release. After Idris changes: compile, build, then run.
After public asset changes: build, then run.

The wrapper accepts only the platform argument for run; it has no `--target`
forwarding. Use an interactive terminal for device selection, or the
[generated host CLI](../tutorials/web-to-android.md#6-know-where-the-outputs-live)
with an explicit device ID.

Source: [tools/iris.py](../../tools/iris.py). Configuration and ownership:
[configuration reference](configuration.md) and
[packaging design](../../design/MOBILE_CAPACITOR.md).
