module KeyedDOM
import Iris
import Iris.Backend.Web.DOM.Run

data Msg = Toggle | Edit String
record Model where
  constructor MkModel
  inserted : Bool
  value : String
update : Msg -> Model -> (Model, Cmd Msg)
update Toggle model = ({ inserted := not model.inserted } model, none)
update (Edit value) model = ({ value := value } model, none)
view : Model -> Widget Msg
view model = vstack $
  (if model.inserted then [WInput (sKey "extra" defaultStyle) "other" Edit] else []) ++
  [WInput (sKey "name" (sTitle "Name" defaultStyle)) model.value Edit,
   WButton (sKey "toggle" defaultStyle) "Toggle" Toggle]
main : IO ()
main = runWeb (MkApp (MkModel False "hello", none) update view
  (\_, event => case event of
    KeyboardEvent ke => case ke.action of
      KeyDown => if ke.key == "F2" then Just Toggle else Nothing
      _ => Nothing
    _ => Nothing) Nothing)
