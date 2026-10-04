||| Shared HTML control semantics for the DOM and Canvas overlay runners.
module Iris.Backend.Web.Control

import Iris.Widget

public export
escapeControl : String -> String
escapeControl value = concatMap escape (unpack value)
  where
    escape : Char -> String
    escape '&' = "&amp;"
    escape '<' = "&lt;"
    escape '>' = "&gt;"
    escape '"' = "&quot;"
    escape '\'' = "&#39;"
    escape char = pack [char]

public export
controlId : String -> Style -> Nat -> String
controlId kind style index = case style.key of
  Nothing => "iris-" ++ kind ++ "-" ++ show index
  Just key => "iris-key-" ++ concatMap (\c => show (ord c) ++ "-") (unpack key)

public export
controlAttributes : Style -> String -> String
controlAttributes style identity =
  (if style.control.disabled then " disabled aria-disabled='true'" else "") ++
  (case style.control.description of
     Nothing => ""
     Just _ => " aria-describedby='" ++ identity ++ "-description'") ++
  (case style.control.validationError of
     Nothing => ""
     Just _ => " aria-invalid='true' aria-errormessage='" ++ identity ++ "-error'") ++
  (case (style.key, style.control.focusRequest) of
     (Just _, Just token) => " data-iris-focus='" ++ show token ++ "'"
     _ => "")

public export
controlDetails : Style -> String -> String
controlDetails style identity =
  (case style.control.description of
     Nothing => ""
     Just description => "<span class='iris-control-details' id='" ++ identity ++
       "-description'>" ++ escapeControl description ++ "</span>") ++
  (case style.control.validationError of
     Nothing => ""
     Just error => "<span class='iris-control-details iris-control-error' id='" ++ identity ++
       "-error' role='alert'>" ++ escapeControl error ++ "</span>")

-- Requests are scoped to the root and retired when the control leaves the tree.
-- An unchanged token never steals focus back on unrelated model updates.
%foreign "javascript:lambda: (selector,_w) => {const root=document.querySelector(selector);if(!root)return;const requests=root.__irisFocusRequests||(root.__irisFocusRequests=new Map());const present=new Set();for(const el of root.querySelectorAll('[data-iris-focus]')){const key=el.id;if(!key)continue;present.add(key);const token=el.dataset.irisFocus;if(!el.disabled&&requests.get(key)!==token){el.focus({preventScroll:true});if(document.activeElement===el)requests.set(key,token);}}for(const key of requests.keys())if(!present.has(key))requests.delete(key);}"
prim_focusControls : String -> PrimIO ()

public export
focusControls : String -> IO ()
focusControls selector = primIO (prim_focusControls selector)
