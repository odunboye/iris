module Main
import Iris.State.TEA
import Iris.Core.Widget
import System

legacyCommand : Cmd Nat
legacyCommand = none
legacyApp : App Nat Nat
legacyApp = simpleApp (0, legacyCommand) (\_, n => (S n, none))
  (\_ => Leaf defaultMeta)
main : IO ()
main = putStrLn "Legacy TEA imports remain supported"
