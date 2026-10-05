||| Iris.Theme's ColorTokens/SpacingScale/etc. are plain data with no
||| interpreter: nothing in src/Iris/ imports Iris.Theme, and Style's own
||| colour type (UIColor, 0-255 channels) isn't the same type as a theme
||| colour (Color, 0.0-1.0 sRGB with alpha) - there's no built-in converter
||| either. This demo writes that small bridge itself (toUIColor, toPx)
||| to show what applying a theme actually looks like today: real for
||| colours and spacing (both genuinely affect rendering), display-only for
||| typography/radii/shadows/motion (Style has no hook for any of them yet).
module ThemeApp

import Iris
import Iris.Core.Types
import Iris.Theme.Types
import Iris.Theme.Default

record Model where
  constructor MkModel
  theme : Theme

data Msg = ToggleTheme

update : Msg -> Model -> (Model, Cmd Msg)
update ToggleTheme m = ({ theme := if m.theme.dark then lightTheme else darkTheme } m, none)

||| Style's colour (0-255 channels) vs a theme's colour (0.0-1.0 sRGB+alpha):
||| Iris doesn't convert between them, so an application using Iris.Theme
||| has to. Drops alpha - Style.bg/fg have no separate opacity channel.
toUIColor : Color -> UIColor
toUIColor c = IRGB (channel c.r) (channel c.g) (channel c.b)
  where
    channel : Double -> Nat
    channel v = cast {to = Nat} (cast {to = Integer} (v * 255))

||| Style.padH/padV are plain Nat units; the DOM backend renders them as
||| px directly (see Backend.Web.DOM.Render), so a theme's px-based spacing
||| scale maps onto them exactly on that backend. Terminal/Canvas treat the
||| same Nat as cells/cell-metrics instead - the token value wouldn't mean
||| the same thing there.
toPad : Double -> Nat
toPad v = cast {to = Nat} (cast {to = Integer} v)

swatch : Color -> Color -> String -> Widget Msg
swatch bg fg label =
  WButton (sDisabled True ({ bg := Just (toUIColor bg), fg := Just (toUIColor fg)
                           , padH := toPad 12, padV := toPad 8 } defaultStyle))
          label ToggleTheme

typeLine : String -> Double -> String
typeLine label px = label ++ ": " ++ show px ++ "px (display only - Style has no font-size field)"

radiusLine : String -> Double -> String
radiusLine label px = label ++ ": " ++ show px ++ "px (display only - BorderKind isn't parameterized by radius)"

view : Model -> Widget Msg
view m =
  let t = m.theme
      c = t.colors
      toggleStyle = { bg := Just (toUIColor c.primary), fg := Just (toUIColor c.primaryFg)
                    , padH := toPad t.spacing.px4, padV := toPad t.spacing.px2 } defaultStyle
  in vstack
       [ text ("Theme: " ++ t.name ++ if t.dark then " (dark)" else " (light)")
       , WButton toggleStyle "Toggle light/dark" ToggleTheme
       , divider
       , text "Colour tokens (real: these are actual background colours below)"
       , hstack
           [ swatch c.primary c.primaryFg "primary"
           , swatch c.secondary c.secondaryFg "secondary"
           , swatch c.surface c.onSurface "surface"
           , swatch c.background c.onBackground "background"
           , swatch c.error c.onError "error"
           ]
       , divider
       , text "Spacing scale (real: swatches above use spacing.px4/px2 padding)"
       , text ("px1=" ++ show t.spacing.px1 ++ " px2=" ++ show t.spacing.px2 ++
               " px3=" ++ show t.spacing.px3 ++ " px4=" ++ show t.spacing.px4 ++
               " px6=" ++ show t.spacing.px6 ++ " (px)")
       , divider
       , text "Typography scale (display only - not applied to any widget)"
       , text (typeLine "bodyMed" t.typography.scale.bodyMed)
       , text (typeLine "titleLarge" t.typography.scale.titleLarge)
       , text (typeLine "displayLarge" t.typography.scale.displayLarge)
       , divider
       , text "Radii (display only - not applied; BorderKind is a fixed enum)"
       , text (radiusLine "sm" t.radii.sm)
       , text (radiusLine "lg" t.radii.lg)
       , divider
       , text "Motion (display only - no animation driver reads these yet)"
       , text ("durationBase=" ++ show t.motion.durationBase ++ "ms, easingStandard=" ++
               t.motion.easingStandard)
       , text ("Shadow levels: none=" ++ show (length t.shadows.none) ++
               " sm=" ++ show (length t.shadows.sm) ++
               " lg=" ++ show (length t.shadows.lg) ++ " (display only)")
       ]

handleEvent : Model -> Event -> Maybe Msg
handleEvent _ _ = Nothing

export
themeApp : UIApp Model Msg
themeApp = MkApp (MkModel lightTheme, none) update view handleEvent Nothing
