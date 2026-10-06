module CaptureDOM
import Iris
import Iris.Backend.Web.DOM.Run

data Msg = Photo String | Toggle
record Model where
  constructor MkModel
  visible : Bool
  result : String
update : Msg -> Model -> (Model, Cmd Msg)
update (Photo value) model = ({ result := value } model, none)
update Toggle model = ({ visible := not model.visible } model, none)
view : Model -> Widget Msg
view model = vstack $
  [text model.result, button "Toggle capture" Toggle] ++
  if model.visible then
    [WCapture (sKey "photo" (sAccessibleName "Photo" defaultStyle)) FacingEnvironment Photo]
  else []
main : IO ()
main = runWeb (MkApp (MkModel True "No photo", none) update view (\_, _ => Nothing) Nothing)
