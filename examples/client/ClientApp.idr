||| The shared UIApp value: a tiny two-endpoint RPC demo against
||| examples/client/server.py. Iris.Client.Web's fetch transport is
||| JavaScript FFI, so this demo targets the DOM runner only.
module ClientApp

import Iris
import Iris.Client
import Iris.Client.Web
import Greet

record Model where
  constructor MkModel
  name   : String
  token  : String
  status : String

data Msg
  = NameChanged String
  | TokenChanged String
  | SendGreeting
  | GreetDone (Either RpcError GreetResponse)
  | CallSecret
  | SecretDone (Either RpcError SecretResponse)

||| Empty base URL: same origin as the page, which is exactly where
||| server.py also serves this app's own static files from.
client : Client
client = webClient "" defaultFetchOptions

transportText : HttpError -> String
transportText (NetworkError msg)      = "network error: " ++ msg
transportText Timeout                 = "timed out"
transportText (BadStatus status body) = "bad status " ++ show status
transportText (BadBody msg)           = "bad body: " ++ msg
transportText Cancelled               = "cancelled"
transportText (ResponseTooLarge n)    = "response too large (" ++ show n ++ " bytes)"

rpcErrorText : RpcError -> String
rpcErrorText (TransportFailure err)         = "Transport error: " ++ transportText err
rpcErrorText (RemoteError status code msg)  =
  "Server error " ++ show status ++ " (" ++ code ++ "): " ++ msg
rpcErrorText (InvalidResponse msg)          = "Invalid response: " ++ msg

initModel : Model
initModel = MkModel "" "" "Type a name and press Greet."

update : Msg -> Model -> (Model, Cmd Msg)
update (NameChanged text) m  = ({ name := text } m, none)
update (TokenChanged text) m = ({ token := text } m, none)
update SendGreeting m        = ({ status := "Calling /rpc/v1/greet..." } m, greet client m.name GreetDone)
update (GreetDone (Right res)) m = ({ status := res.message } m, none)
update (GreetDone (Left err)) m  = ({ status := rpcErrorText err } m, none)
update CallSecret m =
  ( { status := "Calling /rpc/v1/secret..." } m
  , secret (withBearer m.token client) SecretDone )
update (SecretDone (Right res)) m = ({ status := "Secret: " ++ res.secret } m, none)
update (SecretDone (Left err)) m  = ({ status := rpcErrorText err } m, none)

view : Model -> Widget Msg
view m = vstack
  [ text "Iris typed RPC client demo (Iris.Client / Iris.Client.Web)"
  , divider
  , text "Name:"
  , input m.name NameChanged
  , WButton defaultStyle "Greet" SendGreeting
  , divider
  , text "Bearer token (try the wrong one, then the printed demo token):"
  , input m.token TokenChanged
  , WButton defaultStyle "Call protected endpoint" CallSecret
  , divider
  , text m.status
  ]

handleEvent : Model -> Event -> Maybe Msg
handleEvent _ _ = Nothing

export
clientApp : UIApp Model Msg
clientApp = MkApp (initModel, none) update view handleEvent Nothing
