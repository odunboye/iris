# Run effects and make a browser request

Return commands from `init` or `update`; runners execute them and deliver results
as messages. Prefer a supported adapter over writing foreign callbacks yourself.
Read [effect lifetime](../concepts/application-loop.md) before implementing a
custom `CompletingTask` or `CancellableTask`.

## A browser HTTP command

The following complete module describes a request without executing it at
module load. Import it into your web application and return `loadGreeting` from
an update branch. Handle `GreetingLoaded` in that application's update function.
The endpoint is illustrative: your server must provide `/greeting`.

<!-- iris-example: src/RequestExample.idr -->
```idris
module RequestExample

import Iris
import Iris.Effect.Http
import Iris.Effect.Http.Web

public export
data Msg = GreetingLoaded (Either HttpError HttpResponse)

export
loadGreeting : Cmd Msg
loadGreeting = Iris.Effect.Http.Web.get "/greeting" GreetingLoaded
```

Import `Iris.Effect.Http` for the shared request/response/error types; qualify
the browser helper to select its asynchronous transport.

`Left` contains a transport failure; `Right` contains the HTTP response. Check
its status and decode the body before treating it as application success.
`requestWith` accepts explicit timeout and response-size options. Retries require
an explicit `requestWithRetry` policy; decide whether the operation is safe to
retry. This browser module is not a portable terminal transport.

For schema-generated JSON-RPC clients, use [iris-client](../../client/README.md).
For mobile RPC with an explicit HTTPS API origin, see
[iris-mobile](../../mobile/README.md#origin-bound-rpc) and
[configuration](../reference/configuration.md). For native plugin commands and
listeners, use `Iris.Mobile`; installing its Idris package alone does not register
JavaScript plugins. The packaging CLI bundles that registration before the app.

## Prevent stale results

Track a request generation or operation identity in your model when multiple
requests may finish out of order. Ignore results that no longer match the
current operation. Runtime cancellation suppresses delivery after disposal;
it does not automatically decide which of two still-active requests represents
current application intent.

Keep asynchronous work bounded and cooperative. A long synchronous `Task` in a
browser blocks rendering. A custom finite effect must send its final message
and then call `complete`, so finished cleanup closures do not accumulate.
