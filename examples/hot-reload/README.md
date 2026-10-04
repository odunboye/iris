# Opt-in dev-mode hot reload (runWebHot)

A demo of `runWebHot`: two separately compiled programs, swapped into the
same page, with the running model surviving the swap. The only existing
coverage of this was `tests/HotDemo.idr`, a test fixture that isn't a
reader-facing example (and isn't wired into any build/test target - it's
effectively dead code today).

From this repo's root:

```sh
pack --no-prompt install iris
pack --no-prompt --cg javascript build examples/hot-reload/v1.ipkg
pack --no-prompt --cg javascript build examples/hot-reload/v2.ipkg
python3 -m http.server 8080 --directory examples/hot-reload
```

Open `http://127.0.0.1:8080/`, click **Run v1**, click Increment a few
times, then click **Run v2**. Count carries over even though v2 is a
different compiled program (Increment adds 10 instead of 1); Ticks keeps
counting up rather than resetting to zero. Click back to v1 and it still
carries over - this is a real swap in both directions, not a scripted
animation.

## What's simulated, and why

`runWebHot` expects a `globalThis.__fluxHot` client object that a real dev
server injects - that dev server (`flux dev --hot`) lives in the separate
[Flux](https://github.com/odunboye/flux) project, not here, so
`index.html` implements a small stand-in for its `offer`/`attach`/`loading`
contract, reverse-engineered from
[`src/Iris/Backend/Web/DOM/Run.idr`](../../src/Iris/Backend/Web/DOM/Run.idr)'s
`%foreign` glue. Everything that touches real framework behavior is real:
`Iris.App.MkHotState`'s `version`/`save`/`restore`, the actual compiled
output of two real `pack build` invocations, and the actual DOM
teardown/re-render `startWeb` performs. Only the orchestration deciding
*when* to swap is this demo's own.

One genuine wrinkle surfaced while building this, worth knowing if you
build your own hot-reload host: each compiled Idris JS bundle is
self-contained with plain top-level `const`/`function` declarations - the
backend doesn't wrap or namespace them. Loading a second bundle via a plain
`<script src>` while the first is still live throws `SyntaxError: Identifier
... has already been declared`, because both bundles declare the same
runtime helper names in the same global scope. This demo's `swapTo` works
around it by fetching each bundle's source as text and running it through
`new Function(code)()` instead of a `<script>` tag - that scopes the
bundle's declarations to the call instead of the page, and only things it
explicitly assigns onto `globalThis` (the counter's own `__fluxHot` use,
Iris's render queues, etc.) persist across the swap. A real dev client
likely does something equivalent, or reloads the page entirely and relies
on `save`/`restore` round-tripping through a server rather than in-memory.

## Caveats

`MkHotState`'s own doc comment is explicit: `restore` must validate and
sanitize, never execute effects, and never assume the payload is
well-formed - treat it as untrusted input even though in this demo it only
ever came from this same demo's `save`. `Counter.idr`'s `restore` rejects
anything that doesn't parse as two `Nat`s rather than guessing, unlike
`tests/HotDemo.idr`'s unchecked `cast`.
