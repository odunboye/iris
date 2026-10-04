module MainWeb

import Iris.Backend.Web.DOM.Run
import ClientApp

main : IO ()
main = runWeb clientApp
