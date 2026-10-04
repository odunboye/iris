module MainWeb

import Iris.Backend.Web.DOM.Run
import RouterApp

main : IO ()
main = runWeb routerApp
