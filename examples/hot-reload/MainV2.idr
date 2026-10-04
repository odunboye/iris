module MainV2

import Iris.Backend.Web.DOM.Run
import Counter

app : UIApp Model Msg
app = MkApp (MkModel 0 0, none) (update 10) (view "v2" 10) handleEvent (Just Pulse)

main : IO ()
main = runWebHot (MkHotState "v2" save restore) app
