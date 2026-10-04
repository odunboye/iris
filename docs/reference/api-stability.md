# Iris API and compatibility policy

Iris is currently `0.x`: minor releases may contain source-breaking changes,
but changes must include release notes and a migration path. The 0.3 rename is
an explicit breaking cutover with no legacy aliases; see [MIGRATION.md](../MIGRATION.md).

## Supported toolchain

- Idris 2: 0.8.x
- Node.js: 20.x for the existing browser test baseline; 22+ for the current mobile packaging CLI
- Python: 3.11+ for the CLI and documentation checks
- Capacitor: 5.x in the older Todo example; 8.4.3 in the current packaging tooling

See the [packaging lockfile](../../tooling/package-lock.json),
[Todo manifest](../../examples/todo/mobile/package.json) and
[validation guidance](../guides/testing-and-release.md) for the distinct environments.

## Stable application surface

`Iris.App.UIApp`, `Iris.Widget`, `Iris.Effect.Command.Cmd`, and
`Iris.Platform.Event` are the supported application API. The specialized
terminal, DOM, and Canvas runners are the supported runtimes.

`Iris.Core.Widget`, `Iris.Core.Runtime`, and the PAL adapter in
`Iris.Backend.Web.DOM` are legacy/experimental APIs. New applications should
not depend on them. They remain packaged for compatibility until a future
minor release can deprecate and remove them.

## EventWire guarantees

Wire payloads begin with a version field. Iris guarantees that:

- decoders reject unknown versions and malformed fields;
- existing tags keep their meaning for the lifetime of a protocol version;
- optional additions use new tags rather than changing existing field order;
- incompatible changes require a new version such as `f2`;
- decoders may enforce documented size and numeric limits.

The wire protocol is an internal backend boundary, not a public network
protocol. Persisted events must retain their protocol version.

## Deprecation process

A supported API must be marked deprecated for at least one minor release
before removal. `CHANGELOG.md` records additions, behavior changes,
deprecations, and migration instructions.

## Choosing application APIs

Use `import Iris` for `UIApp`, `Widget`, `Cmd` and platform events. It does not
re-export legacy widget/runtime or PAL modules. Choose a specialized runner in
your entry module. Start with [the counter](../../examples/counter/README.md).

`State.TEA.App`, `simpleApp` and `Sub` are legacy runtime APIs; `UIApp` has no
subscription field. `Backend.Terminal.App.TUIApp` and `Widget.TUI.*` are
terminal-specific compatibility APIs, not the portable application contract.
The former default agent executable is preserved under `examples/legacy-agent`;
the current counter demo lives in `examples/counter` and is credential-free.
`iris.ipkg` itself is a pure library package with no bundled executable, so
depending on `iris` under any backend - including `--cg javascript` - never
tries to build a terminal-only demo.

See [CAPABILITIES.md](capabilities.md) before relying on runner-specific behavior.
Desktop SDL2, embedded framebuffer and the generic PAL remain experimental.
Their presence in the package manifest does not confer supported status.
Future design proposals are in [FUTURE_DESIGN.md](../FUTURE_DESIGN.md).

## Explicit identity and finite effects

Use `sKey "account-name" defaultStyle` on interactive DOM controls whose position
can change. Keys are unique across the page and belong to logical controls, not
list positions. DOM patching preserves keyed siblings; moving a control beneath
a different parent can recreate it. Canvas uses keys in its semantic control overlay for identity and focus, but
does not use the DOM runner's incremental patching strategy.
Unkeyed controls retain positional compatibility behavior.

Use `CompletingTask` for finite asynchronous operations: deliver the result, then
call the provided completion action. Completion retires cleanup and rejects later
messages. `CancellableTask` remains the ongoing-listener contract. Starters return
promptly; their returned action releases resources on cancellation. Completion is
idempotent and may happen before registration returns. Custom command interpreters
must add a CompletingTask case. Style's positional constructor gains a Maybe String
key before secret; prefer modifiers over positional construction.

Batch starts commands in list order. This does not guarantee result order or
parallel execution: browser raw Task runs inline; terminal raw Task runs on a worker.

## Control metadata and compatibility imports

`Style.control : ControlOptions` holds disabled/read-only state, accessible name,
description, validation error and an optional focus request token. Prefer
`sDisabled`, `sReadOnly`, `sAccessibleName`, `sDescription`, `sInvalid` and `sFocus`
over positional constructors. `MkStyle` gains `defaultControl` before `secret`.
Start from `defaultStyle` each view to clear metadata that no longer applies.

DOM and Canvas overlays map these fields to native attributes and reject disabled
activation and disabled/read-only text editing. Read-only applies to text inputs;
use disabled for buttons and checkboxes. Canvas hit testing ignores disabled
controls. Terminal renders disabled controls dimmed; application-defined keyboard
handlers still own editing, focus and validation. Update functions must validate
business actions regardless of widget metadata.

Focus requires `sKey` and `sFocus token`. An unchanged token does not steal focus
on a later update; increment it to request focus again. Disabled controls defer
requests. Removing a keyed control retires its remembered token. Focus requests
apply to browser controls, including the Canvas overlay, not terminal input.

Supported code imports `Iris` or `Iris.Effect.Command`. `Iris.State.TEA` re-exports
commands for old unqualified imports and retains `App`, `Sub` and `simpleApp`.
Fully qualified command names move from `Iris.State.TEA.*` to
`Iris.Effect.Command.*`; update those annotations and qualified constructors.
`import Iris` no longer exposes the legacy App/Sub/simpleApp surface.

Canvas hit targets now retain Style through `StyledTarget`. Use `targetStyle`,
`targetId`, `targetRect` and `bareTarget` instead of assuming every target is a
bare ButtonTarget/CheckboxTarget/InputTarget constructor.
