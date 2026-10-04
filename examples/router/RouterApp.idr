||| The shared UIApp value: model, messages, update and view.
||| Platform-specific only in that Iris.Router.Web's navigation primitives
||| are JavaScript FFI, so this demo targets the DOM runner only.
module RouterApp

import Iris
import Iris.Router.Types
import Iris.Router.Web
import Route

public export
record Model where
  constructor MkModel
  route    : Route
  notFound : Bool
  query    : Maybe String
  trail    : NavState Route
  notice   : Maybe String
  search   : String

public export
data Msg
  = NavigateTo Route
  | LocationUpdated String
  | GoBack
  | GoForward
  | SearchChanged String
  | Ignore

initModel : Model
initModel = MkModel Home False Nothing (initNav Home) Nothing ""

||| Run a NavCmd as a raw Task; the browser's own popstate dispatch (inside
||| runNavigation) delivers the resulting LocationChanged event back to
||| handleEvent, so this never needs to guess the new state itself.
runNav : NavCmd Route -> Cmd Msg
runNav cmd = Task (do runNavigation cmd; pure Ignore)

routeName : Route -> String
routeName Home        = "Home"
routeName About       = "About"
routeName (User name) = "User: " ++ name

update : Msg -> Model -> (Model, Cmd Msg)
update (NavigateTo route) m  = ({ notice := Nothing } m, runNav (Push route))
update GoBack m               = (m, runNav (Back 1))
update GoForward m            = (m, runNav (Forward 1))
update (SearchChanged text) m = ({ search := text } m, none)
update Ignore m               = (m, none)
update (LocationUpdated raw) m =
  let currentQuery = parseLocation raw >>= queryParam "q" in
  case resolveRoute {route = Route} raw of
    MalformedLocation => ({ notFound := True, query := Nothing } m, none)
    NotFound loc       => ({ notFound := True, query := queryParam "q" loc } m, none)
    Matched resolved    =>
      case applyNavigationGuard routeGuard resolved of
        Nothing      =>
          ({ notice := Just "That page is blocked." } m, runNav (Replace Home))
        Just allowed =>
          if allowed == resolved
            then
              -- Only grow the trail on an actual change of page: the very
              -- first LocationChanged just confirms where we already are.
              let newTrail = if allowed == m.route then m.trail
                             else applyNav (Push allowed) m.trail
              in ( { route := allowed, notFound := False, query := currentQuery
                   , trail := newTrail
                   } m
                 , none )
            else ( { notice := Just "Redirected away from a blocked page." } m
                 , runNav (Replace allowed) )

view : Model -> Widget Msg
view m = vstack
  [ text "Iris typed-routing demo"
  , divider
  , text ("Current page: " ++ (if m.notFound then "not found" else routeName m.route))
  , text (case m.query of
            Nothing => "No ?q= on this page"
            Just q  => "?q= on this page: " ++ q)
  , text (case m.notice of
            Nothing => "No pending notice"
            Just n  => "Notice: " ++ n)
  , text ("Visited this session: " ++ show (S (length m.trail.back)) ++ " page(s)")
  , divider
  , hstack
      [ WButton defaultStyle "Home" (NavigateTo Home)
      , WButton defaultStyle "About" (NavigateTo About)
      , WButton defaultStyle "User: alice" (NavigateTo (User "alice"))
      , WButton defaultStyle "User: admin (blocked)" (NavigateTo (User "admin"))
      ]
  , hstack
      [ WButton defaultStyle "<- Back" GoBack
      , WButton defaultStyle "Forward ->" GoForward
      ]
  , divider
  , text "Query-string preview (pure renderLocation; does not navigate):"
  , input m.search SearchChanged
  , text ("  -> " ++ renderLocation
            (MkLocation "/" (if m.search == "" then [] else [("q", m.search)]) Nothing))
  , divider
  , text ("If deployed under " ++ demoBasePath ++ ": " ++
            withBasePath demoBasePath (toUrl m.route))
  ]

handleEvent : Model -> Event -> Maybe Msg
handleEvent _ (LifecycleEvt (LocationChanged loc)) = Just (LocationUpdated loc)
handleEvent _ _                                    = Nothing

export
routerApp : UIApp Model Msg
routerApp = MkApp (initModel, none) update view handleEvent Nothing
