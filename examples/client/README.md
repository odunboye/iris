# Typed RPC client

A two-endpoint demo of `iris-client`'s typed JSON-RPC-over-HTTP client, the
supported path [client/README.md](../../client/README.md) documents - as
opposed to `examples/legacy-agent`, which deliberately uses the unsupported
raw shell HTTP effect and is not a credentials/production reference.

A schema generator (`Flux`'s `platform/generate.py`) would normally produce
`Greet.idr`'s request/response types and per-method functions from a schema;
this example writes that one small file by hand instead, so it has no
external dependency beyond this repo.

From this repo's root:

```sh
pack --no-prompt install iris
pack --no-prompt --cg javascript build examples/client/web.ipkg
python3 examples/client/server.py
```

Open `http://127.0.0.1:8090/`. `server.py` serves both this page and the two
RPC endpoints on the same origin and port, so `webClient ""` (empty base URL
== current origin) needs no CORS configuration.

## What to try

- **Greet** — `Greet.greet` wraps `Iris.Client.call`; the server echoes the
  name back in a typed `GreetResponse`.
- **Greet with an empty name** — the server returns HTTP 400 with
  `{"error": {"code", "message"}}`; `Iris.Client.decodeResponse` turns that
  into `RemoteError 400 "empty_name" "Name must not be empty"`.
- **Call protected endpoint with the wrong token** — HTTP 401, decoded the
  same way into a `RemoteError`.
- **Call protected endpoint with the printed token** (`demo-token`, printed
  by `server.py` on startup) — `withBearer` attaches
  `Authorization: Bearer demo-token`, replacing rather than duplicating any
  existing header, and the call succeeds.

## Caveats

`server.py` is a toy backend for this demo only: no persistence, no real
authentication, a single hardcoded token. It exists to give the client
something real to call over HTTP, not as a server-side reference.

See [client/README.md](../../client/README.md) for the full `iris-client`
API, including `Iris.Client.Native` (in-process libcurl, used outside the
browser) and `Iris.Client.Auth` (register/login/logout/me commands this demo
doesn't need).
