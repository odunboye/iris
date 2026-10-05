# Documentation audit and maintenance plan

This audit describes the source at the start of the documentation branch
(`c8580f4`, Iris 0.4.0, including the Android Canvas sizing fix). It distinguishes
supported application APIs, compatibility modules and proposed work.

## Findings addressed

| Finding | Resolution |
|---|---|
| Guidance scattered across root files, examples and design notes | Documentation index with tutorials, guides, explanations and reference |
| Entry modules unexplained | Project structure guide and web/mobile tutorial |
| Scaffold git pin conflicts with mobile compiler's local-map requirement | Explicit local-map conversion before mobile compilation |
| `build`, `sync` and `run` can be mistaken for compilation | Pipeline table and repeat-build instructions |
| Installed launcher vs project-local `./iris` is ambiguous | Explain checkout launcher and PATH throughout |
| High-DPI Canvas startup failure has no user-facing diagnosis | Source CSS and stable bitmap troubleshooting |
| Root requirements mix older example tooling with current packaging tooling | Separate core and mobile requirements; link their dependency sources |
| Root introduction says packaging stayed in Flux | Update README to reflect this repository's CLI |
| Existing packaging notes incorrectly imply build requires a local map | Clarify compile's local map vs build's existing entry |
| API policy says Canvas keys are ignored | Clarify semantic-overlay identity/focus vs DOM patching |
| Shared build outputs can lose an earlier target executable | Explain rebuilding the selected target when switching platforms |
| No automated documentation checks | Local-link/anchor checker, extracted tutorial compilation, browser fixture and CI static check |

## Source inventory

| Surface | Implementation | Reader entry |
|---|---|---|
| Public imports and application | `src/Iris.idr`, `src/Iris/App.idr` | Application API reference |
| Widgets/styles/controls | `src/Iris/Widget.idr` | API map and forms guide |
| Commands and retirement | `src/Iris/Effect/Command.idr`, specialized runners | Application-loop explanation and effects guide |
| Events | `src/Iris/Platform/Event.idr`, EventWire | API map and stability policy |
| DOM, Canvas and terminal | Specialized `Run` modules | Tutorial and capability matrix |
| Router | `src/Iris/Router/Types.idr`, `Web.idr` | API map and executable router tests |
| RPC and authentication | `client/` | Existing client guide |
| Native commands/sessions | `mobile/` | Existing mobile guide |
| CLI, configuration and publication | `tools/iris.py`, policy/native helpers | CLI/configuration references and packaging design |
| Legacy runtime/PAL/TUI widgets | Core, State.TEA, terminal compatibility modules | API policy and migration guide |
| Proposed backends and architecture | `FUTURE_DESIGN.md` | Clearly separate from supported scope |

## Remaining coverage

This is a documentation foundation, not an exhaustive per-symbol manual.
Routing, typed RPC, mobile commands, hot reload and themes now have worked
examples. Next additions should include a larger multi-screen app and an indexed
generated API reference. Native store-release guides need validated platform-specific
instructions. A search-enabled website can publish these Markdown sources
without creating a second documentation source of truth.

CI checks links/scaffolding/cache behavior and separately provisions dependencies
for core/example builds and browser acceptance. The offline documentation build
joins `make check`; the real mobile CLI path is an explicit `docs-integration`
target. Native emulator/physical-device jobs remain separate work.

## Keep docs synchronized

- New APIs: update the module map, relevant guide, capability matrix and changelog.
- CLI/config changes: update references and the tutorial; regenerate a fresh app.
- Claims about behavior: link an executable example/test and state its boundary.
- Commands/snippets: mark complete Idris examples for compilation; label fragments
  and illustrative endpoints clearly.
- Links: keep repository-relative paths; validate anchors with `make docs-check`.
- Releases: revalidate commands and supported toolchain versions against lockfiles
  and actual device evidence. Avoid time-sensitive audit claims as permanent guarantees.

The tutorial's marked Idris code blocks are extracted by `scripts/test-docs.py`.
It checks the three generated entry/app files against a fresh scaffold and
compiles the extra request example. `scripts/check-docs.py` checks root docs,
this documentation tree, example/package guides and design notes. External
links are not fetched; CI is not a claim that remote resources are always live.
