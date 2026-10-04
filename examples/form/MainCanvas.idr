module MainCanvas
import Form
import Iris.Backend.Canvas.Run
main : IO ()
main = runCanvas (app False)
