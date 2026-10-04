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
make check
python3 tests/native_smoke.py
npm ci
npx playwright install chromium
make browser-test
```

`make check` compiles/runs Idris tests and examples, checks release assets, and
builds the documentation tutorial. Browser tests are a separate invocation.
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
Iris package. `make check` installs the current Iris build first.

The emitted tutorial fixture is in `tests/build/docs/greeter`. Serve the Iris
repository root to inspect it, or run the dedicated
[documentation browser test](../../tests/browser/docs.spec.js). The normal
Playwright suite includes that test once `make docs-test` has produced its fixture.

For an optional real packaging check, after initializing mobile dependencies:

```sh
python3 scripts/test-docs.py --capacitor /absolute/path/to/capacitor
```

This bundles the fresh tutorial's mobile entry through `iris build`; it does not
install an app, start an emulator or certify native behavior.

## Prepare a release

Select app identity before generating a native host. Record compiler, Iris,
Capacitor and application revisions and keep dependency lockfiles. Recompile
and rebundle from source rather than modifying staged assets.

Use [the release checklist](../../WEB_MOBILE_COMPLETION.md),
[API policy](../../API_STABILITY.md) and [security guidance](../../SECURITY.md).
Native signing, permissions, platform manifests and store submission are
application responsibilities. Provisioned native checks are described in the
[packaging design](../../design/MOBILE_CAPACITOR.md#tests).
