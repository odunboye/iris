module MainTerminal
import Form
import Iris.Backend.Terminal.Run
main : IO ()
main = runTUI (app True)
