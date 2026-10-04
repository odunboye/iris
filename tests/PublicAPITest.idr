module Main

import Iris
import System

color : Iris.Widget.UIColor
color = Iris.Widget.IBlue

command : Iris.Effect.Command.Cmd ()
command = none

app : Iris.App.UIApp Nat ()
app = MkApp (0, command)
            (\_, n => (S n, none))
            (\n => text (show n))
            (\_, _ => Nothing)
            Nothing

main : IO ()
main = do
  let (count, _) = app.update () 0
  case color of
    IBlue => if count == 1
                then putStrLn "PASS Iris public API, qualified types and model update"
                else exitFailure
    _ => exitFailure
