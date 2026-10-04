||| Shared by both compiled versions in this demo, so a hot swap between
||| them keeps the same Model shape. Only the increment step and displayed
||| label differ, to make a successful swap visually obvious.
module Counter

import public Iris
import Data.String

public export
record Model where
  constructor MkModel
  count : Nat
  ticks : Nat

public export
data Msg = Increment | Pulse

export
update : Nat -> Msg -> Model -> (Model, Cmd Msg)
update step Increment m = ({ count $= (+ step) } m, none)
update _    Pulse     m = ({ ticks $= S } m, none)

export
view : String -> Nat -> Model -> Widget Msg
view versionLabel step m = vstack
  [ text ("Running " ++ versionLabel ++ " (Increment adds " ++ show step ++ ")")
  , text ("Count: " ++ show m.count)
  , text ("Ticks since this instance started: " ++ show m.ticks)
  , WButton defaultStyle "Increment" Increment
  ]

export
handleEvent : Model -> Event -> Maybe Msg
handleEvent _ _ = Nothing

export
save : Model -> Maybe String
save m = Just (show m.count ++ "\n" ++ show m.ticks)

||| Inverse of save. A restore payload came from this same demo's own save,
||| but HotState's contract treats it as untrusted input regardless - reject
||| anything malformed outright rather than guessing.
export
restore : String -> Maybe Model
restore payload = case lines payload of
  [countText, ticksText] => do
    count <- parsePositive countText
    ticks <- parsePositive ticksText
    pure (MkModel count ticks)
  _ => Nothing
