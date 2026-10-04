||| Iris.State.TEA
||| Compatibility TEA application and subscriptions. New applications use
||| Iris.App.UIApp and Iris.Effect.Command.
|||
||| Pure:   Model, View, Update
||| Impure: Cmd (outbound effects), Sub (inbound subscriptions)
module Iris.State.TEA

-- Private dependency for the compatibility App record below.
-- Supported applications import Iris.App.UIApp and Iris.Widget.
import Iris.Core.Widget

import public Iris.Effect.Command

-- ─── Sub ───────────────────────────────────────────────────────────────────

||| A `Sub msg` is an *ongoing subscription* to an external event source
||| (timer ticks, window resize, WebSocket messages, …).
public export
data Sub : (msg : Type) -> Type where
  NoSub    : Sub msg
  BatchSub : List (Sub msg) -> Sub msg
  MapSub   : (a -> b) -> Sub a -> Sub b
  ||| Register a listener; the IO action is called each time the source fires.
  Listen   : String -> ((msg -> IO ()) -> IO (IO ())) -> Sub msg
  -- The inner IO () is the *unsubscribe* action.

public export
Functor Sub where
  map f NoSub           = NoSub
  map f (BatchSub ss)   = BatchSub (map (map f) ss)
  map f (MapSub g s)    = MapSub (f . g) s
  map f (Listen k reg)  = Listen k (\send => reg (send . f))

public export
noSub : Sub msg
noSub = NoSub

public export
batchSub : List (Sub msg) -> Sub msg
batchSub = BatchSub

-- ─── App ───────────────────────────────────────────────────────────────────

||| Legacy application record for Core.Runtime; not consumed by supported runners.
||| Use Iris.App.UIApp with terminal, DOM or Canvas runners.
|||
||| @model  The application state type.
||| @msg    The message type (user events + effect results).
public export
record App (model : Type) (msg : Type) where
  constructor MkApp
  ||| Initial model and any startup commands.
  init          : (model, Iris.Effect.Command.Cmd msg)
  ||| Pure state transition.
  update        : msg -> model -> (model, Iris.Effect.Command.Cmd msg)
  ||| Pure view — the entire UI derived from the model.
  view          : model -> Widget msg
  ||| Ongoing subscriptions that depend on the current model.
  subscriptions : model -> Sub msg

-- ─── Helpers ───────────────────────────────────────────────────────────────

||| Legacy Core.Runtime helper. New applications use Iris.App.MkApp.
public export
simpleApp : (model, Iris.Effect.Command.Cmd msg)
          -> (msg -> model -> (model, Iris.Effect.Command.Cmd msg))
          -> (model -> Widget msg)
          -> App model msg
simpleApp i u v = MkApp i u v (const noSub)
