module Main

import Counter
import Iris.Backend.Terminal.Run

main : IO ()
main = runTUI counter
