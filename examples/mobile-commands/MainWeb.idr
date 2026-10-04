module MainWeb

import Iris.Backend.Web.DOM.Run
import MobileCommandsApp

main : IO ()
main = runWeb mobileCommandsApp
