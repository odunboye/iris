module MainWeb

import Iris.Backend.Web.DOM.Run
import ThemeApp

main : IO ()
main = runWeb themeApp
