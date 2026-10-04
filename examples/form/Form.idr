module Form

import Iris
import Data.String
import Data.Maybe

public export
record Model where
  constructor MkModel
  name : String
  saved : Maybe String
  focusToken : Nat
  locked : Bool

public export
data Msg = EditName String | Save | Refocus | ToggleLock | Stop

public export
valid : String -> Bool
valid name = length (trim name) >= 3

public export
update : Msg -> Model -> (Model, Cmd Msg)
update (EditName value) model = ({ name := value, saved := Nothing } model, none)
update Save model =
  if valid model.name then ({ saved := Just (trim model.name) } model, none)
    else (model, none)
update Refocus model = ({ focusToken := S model.focusToken } model, none)
update ToggleLock model = ({ locked := not model.locked } model, none)
update Stop model = (model, quit)

public export
view : Model -> Widget Msg
view model =
  let error = if model.name /= "" && not (valid model.name)
                then Just "Enter at least three characters." else Nothing
      nameStyle = sDisabled model.locked $ sFocus model.focusToken $ sAccessibleName "Account name" $
        sDescription "Use at least three characters." $ sKey "account-name" defaultStyle
      validated = case error of Nothing => nameStyle; Just message => sInvalid message nameStyle
  in vstack
    [ text "Iris account form"
    , WInput validated model.name EditName
    , text (fromMaybe "" error)
    , WInput (sAccessibleName "Reference" (sReadOnly True (sKey "reference" defaultStyle))) "REF-001" EditName
    , WInput (sAccessibleName "Locked field" (sDisabled True (sKey "locked" defaultStyle))) "Locked" EditName
    , WCheckbox (sAccessibleName "Managed setting" (sDisabled True defaultStyle)) True Save
    , WButton (sPad 1 (sKey "save" (sDisabled (not (valid model.name)) defaultStyle))) (case model.saved of Nothing => "Save"; Just name => "Saved: " ++ name) Save
    , WButton (sPad 1 (sKey "refocus" defaultStyle)) "Focus name" Refocus
    , WButton (sPad 1 (sKey "lock-name" defaultStyle))
        (if model.locked then "Unlock name" else "Lock name") ToggleLock
    , WButton (sPad 1 defaultStyle) "Quit" Stop
    , text (case model.saved of Nothing => "Nothing saved"; Just name => "Saved: " ++ name)
    ]

public export
app : Bool -> UIApp Model Msg
app terminalEditing = MkApp (MkModel "" Nothing 0 False, none) update view handle Nothing
  where
    handle : Model -> Event -> Maybe Msg
    handle model (KeyboardEvent key) = case key.action of
      KeyDown =>
        if key.key == "F3" then Just Refocus
        else if key.key == "Enter" then Just Save
        else if terminalEditing && key.key == "Escape" then Just Stop
        else if terminalEditing && not model.locked && key.key == "Backspace"
               then Just (EditName (pack (reverse (drop 1 (reverse (unpack model.name))))))
        else if terminalEditing && not model.locked then map (\char => EditName (model.name ++ singleton char)) key.char
        else Nothing
      _ => Nothing
    handle _ _ = Nothing
