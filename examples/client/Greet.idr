||| A hand-written stand-in for the `Client.idr` a schema generator would
||| produce (see ../../client/README.md): one typed function per RPC method,
||| each just a thin wrapper around Iris.Client.call.
module Greet

import Iris.Client

public export
record GreetResponse where
  constructor MkGreetResponse
  message : String

export
FromJSON GreetResponse where
  fromJSON = withObject "GreetResponse" $ \obj =>
    MkGreetResponse <$> field obj "message"

public export
record SecretResponse where
  constructor MkSecretResponse
  secret : String

export
FromJSON SecretResponse where
  fromJSON = withObject "SecretResponse" $ \obj =>
    MkSecretResponse <$> field obj "secret"

export
greet : {msg : Type} -> Client -> String -> (Either RpcError GreetResponse -> msg) -> Cmd msg
greet client name = call client "/rpc/v1/greet" (JObject [("name", JString name)])

||| Requires a bearer token; pass a client built with withBearer.
export
secret : {msg : Type} -> Client -> (Either RpcError SecretResponse -> msg) -> Cmd msg
secret client = call client "/rpc/v1/secret" (JObject [])
