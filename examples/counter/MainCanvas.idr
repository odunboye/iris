module MainCanvas

import Counter
import Iris.Backend.Canvas.Run

main : IO ()
main = runCanvas counter
