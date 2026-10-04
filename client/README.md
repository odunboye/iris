# iris-client

`iris-client` was originally built inside [Flux](https://github.com/odunboye/flux)
(as `flux-client`) and later moved back out to its own sub-package here,
since it has no real Flux dependency - it only ever depended on `iris` and
`json-simple`, not Flux's server runtime, Flux DB or PostgreSQL. The module
prefix changed from `Flux.Platform.Client.*` to `Iris.Client.*` as part of
that move.

A portable typed JSON-RPC-over-HTTP client runtime for Iris applications.
Flux's own [`platform/generate.py`](https://github.com/odunboye/flux/blob/main/platform/README.md)
generates a `Client.idr` on top of this for a given schema, but the runtime
itself is backend-agnostic: it decodes a generic `{"error": {"code",
"message"}}` envelope on failure, POSTs JSON, and supports bearer auth - it
has no Flux-specific wire assumptions baked in.

## API

```idris
import Client            -- generated endpoint functions for your schema
import Iris.Client.Web   -- or Iris.Client.Native

data Msg = TodoCreated (Either RpcError TodoResponse)

-- Return this command from init/update; Iris owns execution/cancellation.
covering
create : String -> Cmd Msg
create title =
  createTodo (webClient "https://api.example.com" (MkFetchOptions 10000 65536))
             (MkCreateTodoRequest title) TodoCreated
```

For a same-origin browser application, use an empty base URL. Native Iris
applications use `nativeClient base` from `Iris.Client.Native` instead. Both
clients use the same generated endpoint functions and wire types.

- Web/Capacitor: `Iris.Effect.Http.Web.requestWith`, retaining `CompletingTask`
  and its abort action; timeout/size options come from Iris's `FetchOptions`.
- Native: in-process libcurl `Task`, with 5s connect/30s total deadlines, a 64KiB
  response cap and mandatory peer verification. No argv credentials, temporary
  request files, redirects, ambient proxies, netrc or cookie store. HTTPS is
  required except loopback development; `nativeClientWithCA` accepts a PEM CA file.
- Custom transport: supply `MkClient base transport`, where the transport
  produces an Iris `Cmd` from an HTTP request and result-to-message callback.

`RpcError` distinguishes `TransportFailure HttpError`,
`RemoteError status code message`, and `InvalidResponse message`. Malformed
response bodies are not copied into public decoder diagnostics. Credentials,
URL trust and transport selection remain application responsibilities. Use
`withBearer token client` for an immutable session client; portable
`Iris.Client.Auth` supplies register/login/logout commands. Never persist
bearers in browser storage or put them in URLs. Native Tasks are synchronous and
bounded, not immediately cancellable background workers. These are libcurl
network timeouts, not hard real-time preemption of platform DNS/trust operations.
No application request worker is detached on timeout. The legacy generic
`Iris.Effect.Http` shell transport is still unsuitable for credentials.
Iris Web currently reads response text before its post-read size check when
no usable Content-Length is supplied.

## Build and test

```sh
pack --no-prompt build client/iris-client.ipkg
pack --no-prompt install iris-client
python3 client/test/native.py
```

When changing `client/c/http.c`, Pack's dependency-freshness check does not
track native C changes - reinstall explicitly if a warm cache seems to ignore
an edit.
