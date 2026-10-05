# Test an application and prepare a release

## Verify application behavior

Test pure update transitions independently of rendering. Exercise controls in
the actual target: keyboard and text composition on DOM/Canvas, application key
handling on terminal. Check focus while inserting/reordering controls and check
disabled/read-only/validation states. Test high-DPI sizing and viewport changes.

For mobile, confirm startup, interactions, rotation, background/resume and back
behavior on the intended platform. Test the app's actual native plugins and
persistence separately. An emulator counter test is only startup evidence.

## Framework checks

From an Iris checkout, with Idris 2 and its dependencies installed:

```sh
# Once, with the Capacitor bindings checkout available:
make examples-setup CAPACITOR=/absolute/path/to/capacitor
make check
python3 tests/native_smoke.py
npm ci
npx playwright install chromium
make browser-test
```

`make check` compiles/runs Idris tests, all example targets, release assets, and
the documentation tutorial. The complete example suite requires `iris-client`
and `iris-mobile` in the selected compiler environment. `examples-setup` uses
Pack to install them explicitly; it requires Git/network access on a cold cache,
a full Capacitor bindings checkout, a C compiler, `pkg-config`, and libcurl
7.85+ development files. The repository Pack map expects a sibling
`../capacitor` checkout; adjust that alias if your checkout is elsewhere.
After setup, the build targets do not obtain mobile tooling automatically. Browser tests are a separate invocation.
They cover concrete acceptance cases, not complete browser or accessibility
certification. The pseudo-terminal smoke check needs a working native toolchain.

For documentation-only checks:

```sh
make docs-check
make docs-test
```

`docs-check` validates local links/anchors and tutorial markers with Python
3.11+, without installing a compiler. It also runs the checker tests.
`docs-test` creates a fresh scaffold, verifies the documented modules match it,
compiles its web/mobile targets and the documented request module, and checks
JavaScript syntax. It uses `idris2` and `node` on PATH and an already-installed
Iris package. This default path needs no mobile checkout, Pack invocation,
network access or npm installation. `make check` installs the current Iris build
first. `make examples-check` builds the six routing/RPC/mobile-command/hot-reload/
theme targets independently after their dependencies have been installed.

The emitted tutorial fixture is in `tests/build/docs/greeter`. Serve the Iris
repository root to inspect it, or run the dedicated
[documentation browser test](../../tests/browser/docs.spec.js). The normal
Playwright suite includes that test once `make docs-test` has produced its fixture.

The separate `make docs-integration` target exercises the real `iris compile`
path against a fresh git-pinned scaffold. It requires Pack, Git, a commit
available on the checkout's remote, and a real Capacitor bindings checkout.
It can clone/download dependencies or initialize mobile npm tooling when no
checkout is remembered. `--compiler` selects the raw compiler pass; the real CLI
pass uses Pack's own compiler environment.

For an optional real CLI and packaging check, after `iris setup` has initialized
the bindings and packaging npm dependencies:

```sh
python3 scripts/test-docs.py --capacitor /absolute/path/to/capacitor
```

This compiles and bundles the fresh tutorial's mobile entry through `iris build`; it does not
install an app, start an emulator or certify native behavior.

## Prepare a release

Select app identity before generating a native host. Record compiler, Iris,
Capacitor and application revisions and keep dependency lockfiles. Recompile
and rebundle from source rather than modifying staged assets.

Use [the release checklist](../reference/release-checklist.md),
[API policy](../reference/api-stability.md) and [security guidance](../../SECURITY.md).
Native signing, permissions, platform manifests and store submission are
application responsibilities. Provisioned native checks are described in the
[packaging design](../reference/mobile-capacitor.md#tests).

## Hosted CI

The examples/browser workflow selects Pack collection `nightly-260903`, obtains
pinned Capacitor bindings, installs dependencies explicitly, and runs the core,
example, documentation, Python and Chromium checks. Documentation links and
cache regressions also run in the lightweight documentation workflow. No
emulator or native store signing is part of these jobs.
