module Main

import System
import Iris.Widget
import Iris.Backend.Web.DOM.Render
import Iris.Backend.Terminal.WidgetRender

startsWith : List Char -> List Char -> Bool
startsWith [] _ = True
startsWith _ [] = False
startsWith (x :: xs) (y :: ys) = x == y && startsWith xs ys

contains : String -> String -> Bool
contains needle haystack = any (startsWith (unpack needle)) (tails (unpack haystack))
  where
    tails : List a -> List (List a)
    tails [] = [[]]
    tails value@(_ :: rest) = value :: tails rest

assert : String -> Bool -> IO ()
assert _ True = pure ()
assert label False = do
  putStrLn ("DOM renderer test failed: " ++ label)
  exitFailure

main : IO ()
main = do
  let inputStyle = sTitle "Task name" defaultStyle
  let checkStyle = sTitle "Task complete" defaultStyle
  (html, _, _) <- renderPage $ vstack
    [ text "<unsafe & text>"
    , WInput inputStyle "a'b" (const 0)
    , WCheckbox checkStyle True 1
    , button "Save & close" 2
    , progress 0.5
    , spinner 1
    ]
  assert "HTML escaping" (contains "&lt;unsafe &amp; text&gt;" html)
  assert "input value escaping" (contains "value='a&#39;b'" html)
  assert "input accessible name" (contains "aria-label='Task name'" html)
  assert "checkbox accessible name" (contains "aria-label='Task complete'" html)
  assert "checked state" (contains " checked" html)
  assert "button accessible name" (contains "aria-label='Save &amp; close'" html)
  assert "delegated button event" (contains "data-iris-click='" html)
  assert "delegated input event" (contains "data-iris-input='" html)
  assert "no inline event handlers" (not (contains "onclick=" html) &&
                                      not (contains "oninput=" html) &&
                                      not (contains "onchange=" html))
  assert "progress semantics" (contains "role='progressbar'" html && contains "aria-valuenow='50'" html)
  assert "live status" (contains "role='status'" html && contains "aria-live='polite'" html)
  assert "group semantics" (contains "role='group'" html)
  assert "focus indicator CSS" (contains ":focus-visible" irisCSS)
  assert "reduced motion CSS" (contains "prefers-reduced-motion" irisCSS)
  let password : Widget Nat = WInput (sSecret (sTitle "Password" defaultStyle)) "secret 🚀" (const 0)
  (masked, _, _) <- renderPage password
  assert "password input semantics" (contains "type='password'" masked)
  let terminal = renderWidget password (MkWRect 0 0 30 1)
  assert "terminal password is masked" (contains "********" terminal && not (contains "secret" terminal))
  assert "shared canvas/terminal mask preserves character count" (inputDisplay (sSecret defaultStyle) "secret 🚀" == "********")
  let stable = sKey "account-name" defaultStyle
  assert "keyed identity ignores traversal order"
    (controlId "input" stable 0 == controlId "input" stable 9)
  assert "key encoding separates arbitrary strings"
    (controlId "input" (sKey "a-b" defaultStyle) 0 /=
     controlId "input" (sKey "ab" defaultStyle) 0)
  (keyed, _, _) <- renderPage (WInput stable "value" (const 0))
  (inserted, _, _) <- renderPage (vstack [button "New control" 1, WInput stable "value" (const 0)])
  let identity = "id='" ++ controlId "input" stable 0 ++ "'"
  assert "key survives insertion before input" (contains identity keyed && contains identity inserted)
  let lockedStyle = sAccessibleName "Locked" (sDisabled True defaultStyle)
  (disabledHTML, disabledClicks, disabledInputs) <- renderPage (vstack
    [WButton lockedStyle "Save" 1, WCheckbox lockedStyle False 2,
     WInput lockedStyle "value" (const 3)])
  assert "disabled controls are native disabled" (contains " disabled" disabledHTML)
  assert "disabled controls have no dispatch handlers" (null disabledClicks && null disabledInputs)
  (readOnlyHTML, _, readOnlyInputs) <- renderPage (WInput (sReadOnly True defaultStyle) "reference" (const 1))
  assert "read-only inputs are native read-only" (contains " readonly" readOnlyHTML && null readOnlyInputs)
  let described = sInvalid "Invalid <value>" (sDescription "Helpful & safe" (sAccessibleName "Name" (sFocus 2 (sKey "name" defaultStyle))))
  (describedHTML, _, _) <- renderPage (WInput described "" (const 1))
  assert "accessible name distinct from title" (contains "aria-label='Name'" describedHTML)
  assert "description is associated and escaped" (contains "aria-describedby='" describedHTML && contains "Helpful &amp; safe" describedHTML)
  assert "validation error is associated and escaped" (contains "aria-invalid='true'" describedHTML && contains "aria-errormessage='" describedHTML && contains "Invalid &lt;value&gt;" describedHTML)
  assert "focus request has explicit token" (contains "data-iris-focus='2'" describedHTML)
  let dimmed = renderWidget (WButton lockedStyle "Save" 1) (MkWRect 0 0 20 1)
  assert "terminal disabled controls are visibly dimmed" (contains "\x1b[2m" dimmed)
  putStrLn "DOM renderer tests passed"
