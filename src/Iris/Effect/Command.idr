||| Commands shared by supported UIApp runners and legacy TEA applications.
||| This module does not depend on a widget tree or compatibility runtime.
module Iris.Effect.Command

-- ─── Cmd ───────────────────────────────────────────────────────────────────

||| A `Cmd msg` is an *opaque description* of a side-effect that, when
||| executed by the runtime, eventually produces zero or more `msg` values.
||| Cmds are *data*, not IO actions — the runtime decides when to run them.
public export
data Cmd : (msg : Type) -> Type where
  ||| Do nothing.
  None    : Cmd msg
  ||| Start commands in list order. Asynchronous work may overlap; raw tasks
  ||| run inline in browser runners and on workers in the terminal runner.
  Batch   : List (Cmd msg) -> Cmd msg
  ||| Map the resulting message through a function.
  MapCmd  : (a -> b) -> Cmd a -> Cmd b
  ||| A single raw IO action that produces a message.
  ||| Smart constructors in Iris.Effect.* wrap this.
  Task    : IO msg -> Cmd msg
  ||| A streaming task: calls `send` zero or more times.
  ||| Use this for LLM token streaming, file tailing, etc.
  StreamTask : ((msg -> IO ()) -> IO ()) -> Cmd msg
  ||| Start cooperative asynchronous work and return its cancellation action.
  ||| Supported runners invoke this on shutdown; DOM/Canvas also do so on
  ||| lifecycle suspension. Starters must return promptly after arranging work.
  CancellableTask : ((msg -> IO ()) -> IO (IO ())) -> Cmd msg
  ||| Start finite asynchronous work. Call `complete` exactly once when no
  ||| further messages will be sent, after delivering the final result.
  ||| Completion retires the cleanup; cancellation invokes it instead.
  CompletingTask : ((msg -> IO ()) -> IO () -> IO (IO ())) -> Cmd msg
  ||| Tell the runtime to exit cleanly.
  ||| Use `quit` in your update function instead of returning `none`.
  QuitApp : Cmd msg

public export
Functor Cmd where
  map f None               = None
  map f (Batch cs)         = Batch (map (map f) cs)
  map f (MapCmd g c)       = MapCmd (f . g) c
  map f (Task io)          = Task (map f io)
  map f (StreamTask act)   = StreamTask (\send => act (send . f))
  map f (CancellableTask act) = CancellableTask (\send => act (send . f))
  map f (CompletingTask act) = CompletingTask (\send, complete => act (send . f) complete)
  map _ QuitApp            = QuitApp

public export
none : Cmd msg
none = None

public export
batch : List (Cmd msg) -> Cmd msg
batch = Batch

||| Command that exits the application cleanly.
public export
quit : Cmd msg
quit = QuitApp

