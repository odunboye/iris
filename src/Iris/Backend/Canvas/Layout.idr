||| Pure Canvas interaction layout and hit testing.
module Iris.Backend.Canvas.Layout

import Iris.Widget
import Iris.Backend.Web.Control
import Iris.Backend.Terminal.WidgetRender

public export
data HitTarget msg
  = ButtonTarget Nat WRect String msg
  | CheckboxTarget Nat WRect Bool msg
  | InputTarget Nat WRect String (String -> msg)
  | StyledTarget Style (HitTarget msg)

public export
targetId : HitTarget msg -> Nat
targetId (ButtonTarget value _ _ _) = value
targetId (CheckboxTarget value _ _ _) = value
targetId (InputTarget value _ _ _) = value
targetId (StyledTarget _ target) = targetId target

public export
PointerCaptures : Type
PointerCaptures = List (Int, Nat)

public export
capturePointer : Int -> Nat -> PointerCaptures -> PointerCaptures
capturePointer pointer target captures =
  (pointer, target) :: filter (\entry => fst entry /= pointer) captures

public export
cancelPointer : Int -> PointerCaptures -> PointerCaptures
cancelPointer pointer = filter (\entry => fst entry /= pointer)

public export
releasePointer : Int -> PointerCaptures -> (Maybe Nat, PointerCaptures)
releasePointer pointer captures = (findCapture captures, cancelPointer pointer captures)
  where
    findCapture : PointerCaptures -> Maybe Nat
    findCapture [] = Nothing
    findCapture ((candidate, target) :: rest) =
      if candidate == pointer then Just target else findCapture rest

public export
targetRect : HitTarget msg -> WRect
targetRect (ButtonTarget _ rect _ _) = rect
targetRect (CheckboxTarget _ rect _ _) = rect
targetRect (InputTarget _ rect _ _) = rect
targetRect (StyledTarget _ target) = targetRect target

public export
targetStyle : HitTarget msg -> Style
targetStyle (StyledTarget style _) = style
targetStyle _ = defaultStyle

public export
bareTarget : HitTarget msg -> HitTarget msg
bareTarget (StyledTarget _ target) = bareTarget target
bareTarget target = target

shiftRectInto : WRect -> Nat -> Nat -> WRect -> Maybe WRect
shiftRectInto viewport scrollX scrollY rect =
  let originX = viewport.col + scrollX
      originY = viewport.row + scrollY
      cutX = originX `minus` rect.col
      cutY = originY `minus` rect.row
      shiftedCol = viewport.col + (rect.col `minus` originX)
      shiftedRow = viewport.row + (rect.row `minus` originY)
      visibleW = min (rect.w `minus` cutX) ((viewport.col + viewport.w) `minus` shiftedCol)
      visibleH = min (rect.h `minus` cutY) ((viewport.row + viewport.h) `minus` shiftedRow)
  in if visibleW == 0 || visibleH == 0 then Nothing
     else Just (MkWRect shiftedCol shiftedRow visibleW visibleH)

shiftTargetInto : WRect -> Nat -> Nat -> HitTarget msg -> Maybe (HitTarget msg)
shiftTargetInto viewport x y (StyledTarget style target) =
  map (StyledTarget style) (shiftTargetInto viewport x y target)
shiftTargetInto viewport x y (ButtonTarget id rect label message) =
  map (\visible => ButtonTarget id visible label message) (shiftRectInto viewport x y rect)
shiftTargetInto viewport x y (CheckboxTarget id rect checked message) =
  map (\visible => CheckboxTarget id visible checked message) (shiftRectInto viewport x y rect)
shiftTargetInto viewport x y (InputTarget id rect value handler) =
  map (\visible => InputTarget id visible value handler) (shiftRectInto viewport x y rect)

keepJust : List (Maybe a) -> List a
keepJust [] = []
keepJust (Nothing :: rest) = keepJust rest
keepJust (Just value :: rest) = value :: keepJust rest

inside : Nat -> Nat -> WRect -> Bool
inside col row rect =
  col >= rect.col && row >= rect.row &&
  col < rect.col + rect.w && row < rect.row + rect.h

||| Hit-test in reverse paint order so the visually topmost target wins.
public export
hitAt : Nat -> Nat -> List (HitTarget msg) -> Maybe (HitTarget msg)
hitAt col row targets = findHit (reverse targets)
  where
    findHit : List (HitTarget msg) -> Maybe (HitTarget msg)
    findHit [] = Nothing
    findHit (target :: rest) =
      if not (targetStyle target).control.disabled && inside col row (targetRect target) then Just target else findHit rest

mutual
  collect : Nat -> Widget msg -> WRect -> (Nat, List (HitTarget msg))
  collect next (WButton style label message) rect =
    (S next, [StyledTarget style (ButtonTarget next rect label message)])
  collect next (WCheckbox style checked message) rect =
    (S next, [StyledTarget style (CheckboxTarget next rect checked message)])
  collect next (WInput style value handler) rect =
    (S next, [StyledTarget style (InputTarget next rect value handler)])
  collect next (WVStack style children) rect =
    let inner = innerRect style rect
        sizes = distributeV children inner.w inner.h
    in collectV next children sizes inner.col inner.row inner.w inner.h
  collect next (WScroll style scrollX scrollY child) rect =
    let viewport = innerRect style rect
        contentSize = measure child 10000 10000
        (afterChild, targets) = collect next child
          (MkWRect viewport.col viewport.row contentSize.w contentSize.h)
    in (afterChild, keepJust (map (shiftTargetInto viewport scrollX scrollY) targets))
  collect next (WHStack style children) rect =
    let inner = innerRect style rect
        sizes = distributeH children inner.w inner.h
    in collectH next children sizes inner.col inner.row inner.w inner.h
  collect next _ _ = (next, [])

  collectV : Nat -> List (Widget msg) -> List WSize -> Nat -> Nat -> Nat -> Nat
          -> (Nat, List (HitTarget msg))
  collectV next [] _ _ _ _ _ = (next, [])
  collectV next (child :: children) (size :: sizes) col row maxW maxH =
    let childW = if widgetFillH child then maxW else min size.w maxW
        childH = size.h
        (afterChild, childTargets) = collect next child (MkWRect col row childW childH)
        (afterRest, restTargets) = collectV afterChild children sizes col
          (row + childH) maxW (maxH `minus` childH)
    in (afterRest, childTargets ++ restTargets)
  collectV next (_ :: children) [] col row maxW maxH =
    collectV next children [] col row maxW maxH

  collectH : Nat -> List (Widget msg) -> List WSize -> Nat -> Nat -> Nat -> Nat
          -> (Nat, List (HitTarget msg))
  collectH next [] _ _ _ _ _ = (next, [])
  collectH next (child :: children) (size :: sizes) col row maxW maxH =
    let childW = size.w
        childH = if widgetFillV child then maxH else min size.h maxH
        (afterChild, childTargets) = collect next child (MkWRect col row childW childH)
        (afterRest, restTargets) = collectH afterChild children sizes
          (col + childW) row (maxW `minus` childW) maxH
    in (afterRest, childTargets ++ restTargets)
  collectH next (_ :: children) [] col row maxW maxH =
    collectH next children [] col row maxW maxH

||| Compute interactive rectangles with exactly the same stack distribution
||| used by the Canvas renderer.
public export
layoutTargets : Widget msg -> Nat -> Nat -> List (HitTarget msg)
layoutTargets widget cols rows = snd (collect 0 widget (MkWRect 0 0 cols rows))

expandRect : Nat -> Nat -> WRect -> WRect
expandRect minimumW minimumH rect =
  MkWRect rect.col rect.row (max minimumW rect.w) (max minimumH rect.h)

||| Enforce minimum logical hit dimensions without changing visual layout.
public export
minimumHitTargets : Nat -> Nat -> List (HitTarget msg) -> List (HitTarget msg)
minimumHitTargets minimumW minimumH = map expand
  where
    expand : HitTarget msg -> HitTarget msg
    expand (StyledTarget style target) = StyledTarget style (expand target)
    expand (ButtonTarget id rect label message) =
      ButtonTarget id (expandRect minimumW minimumH rect) label message
    expand (CheckboxTarget id rect checked message) =
      CheckboxTarget id (expandRect minimumW minimumH rect) checked message
    expand (InputTarget id rect value handler) =
      InputTarget id (expandRect minimumW minimumH rect) value handler

semanticStyle : Double -> Double -> WRect -> String
semanticStyle cellW cellH rect =
  "position:absolute;left:" ++ show (cast rect.col * cellW) ++ "px;top:" ++
  show (cast rect.row * cellH) ++ "px;width:" ++ show (cast rect.w * cellW) ++
  "px;height:" ++ show (cast rect.h * cellH) ++ "px;box-sizing:border-box;"

||| Build the transparent native-control layer associated with a Canvas. It
||| supplies keyboard focus, mobile text input, and screen-reader semantics
||| while Canvas remains responsible for visual rendering.
public export
semanticOverlay : Double -> Double -> List (HitTarget msg) -> String
semanticOverlay cellW cellH = concatMap (\target => renderTarget (targetStyle target) (bareTarget target))
  where
    renderTarget : Style -> HitTarget msg -> String
    renderTarget style (ButtonTarget id rect label _) =
      let identity = controlId "canvas-button" style id in
      "<button id='" ++ identity ++ "' class='iris-canvas-control' aria-label='" ++
      escapeControl (controlName style label) ++ "'" ++ controlAttributes style identity ++
      " data-iris-style='" ++ semanticStyle cellW cellH rect ++ "' " ++
      "data-iris-canvas-activate='" ++ show id ++ "'></button>" ++ controlDetails style identity
    renderTarget style (CheckboxTarget id rect checked _) =
      let identity = controlId "canvas-checkbox" style id in
      "<input id='" ++ identity ++ "' class='iris-canvas-control' type='checkbox' aria-label='" ++
      escapeControl (controlName style "Toggle") ++ "'" ++ controlAttributes style identity ++ " " ++
      (if checked then "checked " else "") ++ "data-iris-style='" ++ semanticStyle cellW cellH rect ++
      "' data-iris-canvas-activate='" ++ show id ++ "'/>" ++ controlDetails style identity
    renderTarget style (InputTarget id rect value _) =
      let identity = controlId "canvas-input" style id in
      "<input class='iris-canvas-control iris-canvas-input' type='" ++
      (if style.secret then "password" else "text") ++ "' aria-label='" ++
      escapeControl (controlName style "Canvas text input") ++ "'" ++ controlAttributes style identity ++
      (if style.control.readOnly then " readonly" else "") ++ " autocomplete='off' id='" ++
      identity ++ "' data-iris-style='" ++ semanticStyle cellW cellH rect ++ "' value='" ++
      escapeControl value ++ "' data-iris-canvas-input='" ++ show id ++ "'/>" ++ controlDetails style identity
    renderTarget style (StyledTarget nested target) = renderTarget nested target
