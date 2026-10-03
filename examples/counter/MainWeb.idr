module MainWeb

import Counter
import Iris.Backend.Web.DOM.Run

main : IO ()
main = runWeb counter
