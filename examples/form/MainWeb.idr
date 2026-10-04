module MainWeb
import Form
import Iris.Backend.Web.DOM.Run
main : IO ()
main = runWeb (app False)
