module MainV1

import Iris.Backend.Web.DOM.Run
import Counter

app : UIApp Model Msg
app = MkApp (MkModel 0 0, none) (update 1) (view "v1" 1) handleEvent (Just Pulse)

main : IO ()
main = runWebHot (MkHotState "v1" save restore) app
