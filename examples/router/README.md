# Typed routing

A one-page demo of `Iris.Router.Types`/`Iris.Router.Web`: path parameters,
query strings, base paths, navigation guards and real browser history. This
is a DOM-only example — `Iris.Router.Web`'s navigation primitives are
JavaScript FFI, so there's no terminal or Canvas target here.

From this repo's root:

```sh
pack --no-prompt install iris
pack --no-prompt --cg javascript build examples/router/web.ipkg
python3 -m http.server 8080 --directory examples/router
```

Open `http://127.0.0.1:8080/` — the bare root, not `/index.html`. This app
uses real `pushState`-based routing, and the `Route` type only matches `/`,
not `/index.html`.

## What to try

- **Home / About / User: alice** — each pushes a real URL (`/`, `/about`,
  `/users/alice`) via `runNavigation (Push route)`; `Iris.Router.Types`'s
  `matchPath "/users/:name"` extracts the path parameter on the way back in
  through `LocationChanged`.
- **User: admin (blocked)** — `routeGuard` in `Route.idr` redirects this one
  away from `Home` via `Iris.Router.Types.applyNavigationGuard`, and because
  the guard runs on every resolved location (not just this button), typing
  `/users/admin` into the address bar or reaching it with the browser's own
  Back/Forward does the same thing.
- **Back / Forward** — real `history.back()`/`history.forward()` through
  `NavCmd`'s `Back`/`Forward` constructors, not app-managed state.
- **The text field** — a pure preview: typing builds a `Location` with
  `MkLocation`/`renderLocation` and shows the encoded URL it would produce,
  without calling `runNavigation`. Reload with `?q=something` already in the
  address bar (from a fresh `/`) to see the reverse direction: `queryParam`
  decoding an incoming query string.
- **"If deployed under /app: ..."** — `withBasePath` applied to the current
  route, purely illustrative; this demo's own navigation stays at the server
  root (see caveat below).

## Caveats

A plain static file server has no rewrite rule sending `/about` or
`/users/alice` back to `index.html`, so refreshing the browser (or opening
one of those URLs directly) 404s — `python3 -m http.server` just serves
files by path. Click the nav buttons from a freshly loaded `/` instead of
typing deep paths into the address bar; this example is about the routing
API, not about configuring a server-side SPA rewrite. A real deployment
needs one (most static hosts call this a "catch-all" or "SPA fallback"
rule).

See [Iris.Router.Types](../../src/Iris/Router/Types.idr) and
[Iris.Router.Web](../../src/Iris/Router/Web.idr) for the full API, and
[tests/RouterTest.idr](../../tests/RouterTest.idr) for its pure-function
test coverage (URL encode/decode round-trips, UTF-8, malformed escapes).
