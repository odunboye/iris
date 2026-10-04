||| Pure routing logic: no IO, no Iris application types.
module Route

import Iris.Router.Types

||| The pages this demo understands, matched against the URL path.
public export
data Route = Home | About | User String

public export
Eq Route where
  Home == Home       = True
  About == About     = True
  User a == User b   = a == b
  _ == _             = False

||| Pretend the app is mounted under a sub-path when demonstrating
||| withBasePath/stripBasePath; real navigation in this demo stays at the
||| server root so a plain static file server needs no rewrite rule.
public export
demoBasePath : String
demoBasePath = "/app"

public export
Router Route where
  toUrl Home        = "/"
  toUrl About        = "/about"
  toUrl (User name) = "/users/" ++ name

  fromUrl raw = do
    loc <- parseLocation raw
    case loc.path of
      "/"      => Just Home
      "/about" => Just About
      path     => case matchPath "/users/:name" path of
                    Just [(_, name)] => Just (User name)
                    _                => Nothing

||| Direct navigation to the admin profile is blocked; everyone else is
||| allowed through unchanged. Applied on every resolved location, not just
||| in-app link clicks, so typing the URL or using browser back/forward
||| cannot bypass it either.
public export
routeGuard : Route -> NavigationDecision Route
routeGuard (User "admin") = Redirect Home
routeGuard route          = Allow route
