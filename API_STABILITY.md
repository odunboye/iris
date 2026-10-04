# Iris API and compatibility policy

Iris is currently `0.x`: minor releases may contain source-breaking changes,
but changes must include release notes and a migration path. The 0.3 rename is
an explicit breaking cutover with no legacy aliases; see [MIGRATION.md](MIGRATION.md).

## Supported toolchain

- Idris 2: 0.8.x
- Node.js: 20.x for browser tests and Capacitor tooling
- Capacitor: 5.x in the Todo mobile example

CI is the source of truth for supported combinations.

## Stable application surface

`Iris.App.UIApp`, `Iris.Widget`, `Iris.State.TEA.Cmd`, and
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
your entry module. Start with [the counter](examples/counter/README.md).

`State.TEA.App`, `simpleApp` and `Sub` are legacy runtime APIs; `UIApp` has no
subscription field. `Backend.Terminal.App.TUIApp` and `Widget.TUI.*` are
terminal-specific compatibility APIs, not the portable application contract.
The former default agent executable is preserved under `examples/legacy-agent`;
the default executable now uses a credential-free `UIApp` counter.

See [CAPABILITIES.md](CAPABILITIES.md) before relying on runner-specific behavior.
Desktop SDL2, embedded framebuffer and the generic PAL remain experimental.
Their presence in the package manifest does not confer supported status.
Future design proposals are in [FUTURE_DESIGN.md](FUTURE_DESIGN.md).

## Explicit identity and finite effects

Use `sKey "account-name" defaultStyle` on interactive DOM controls whose position
can change. Keys are unique across the page and belong to logical controls, not
list positions. DOM patching preserves keyed siblings; moving a control beneath
a different parent can recreate it. Canvas ignores this DOM-specific key for now.
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
