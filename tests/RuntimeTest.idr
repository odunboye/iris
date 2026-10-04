module Main

import System
import Data.IORef
import Iris.App
import Iris.Platform.Event
import Iris.Runtime.Common
import Iris.State.TEA
import Iris.Widget

data Msg = Add | Stop

update : Msg -> Nat -> (Nat, Cmd Msg)
update Add model = (S model, none)
update Stop model = (S model, Batch [QuitApp, Task (pure Add)])

app : UIApp Nat Msg
app = MkApp (0, none) update (\n => text (show n)) (\_, _ => Nothing) Nothing

assert : String -> Bool -> IO ()
assert _ True = pure ()
assert label False = do
  putStrLn ("Runtime test failed: " ++ label)
  exitFailure

main : IO ()
main = do
  model <- newIORef 0
  quit <- newIORef False

  dispatch app model quit Add
  first <- readIORef model
  assert "normal dispatch" (first == 1)

  dispatch app model quit Stop
  stopped <- readIORef model
  didQuit <- readIORef quit
  assert "QuitApp marks runtime stopped" didQuit
  assert "batch stops after QuitApp" (stopped == 2)

  dispatch app model quit Add
  afterLateEvent <- readIORef model
  assert "events after shutdown are ignored" (afterLateEvent == 2)

  execCmd (Task (pure Add)) (dispatch app model quit) quit
  afterLateCommand <- readIORef model
  assert "commands after shutdown are ignored" (afterLateCommand == 2)

  managedModel <- newIORef 0
  managedQuit <- newIORef False
  control <- newRuntimeControl managedQuit
  cancelled <- newIORef 0
  callback <- newIORef (\_ => pure ())
  let managed = CancellableTask (\send => do
        writeIORef callback send
        pure (modifyIORef cancelled S))
  execCmdManaged managed (dispatchManaged app managedModel control) control
  suspendRuntime control
  cancelCount <- readIORef cancelled
  assert "suspension cancels active effects" (cancelCount == 1)
  resumeRuntime control
  stale <- readIORef callback
  stale Add
  staleModel <- readIORef managedModel
  assert "pre-pause callback is stale after resume" (staleModel == 0)

  execCmdManaged managed (dispatchManaged app managedModel control) control
  fresh <- readIORef callback
  fresh Add
  freshModel <- readIORef managedModel
  assert "current generation callback dispatches" (freshModel == 1)
  dispatchManaged app managedModel control Stop
  managedDidQuit <- readIORef managedQuit
  assert "managed update can quit" managedDidQuit
  finalCancelCount <- readIORef cancelled
  assert "shutdown cancels active effects" (finalCancelCount == 2)

  earlyQuit <- newIORef False
  earlyControl <- newRuntimeControl earlyQuit
  earlyModel <- newIORef 0
  earlyCancel <- newIORef 0
  execCmdManaged (CancellableTask (\send => do
    send Stop
    pure (modifyIORef earlyCancel S)))
    (dispatchManaged app earlyModel earlyControl) earlyControl
  earlyCount <- readIORef earlyCancel
  earlyRegistered <- readIORef earlyControl.cancellations
  assert "cleanup returned after synchronous quit runs immediately" (earlyCount == 1)
  assert "cleanup returned after quit is not retained" (null earlyRegistered)
  cancelActiveEffects earlyControl
  repeatCount <- readIORef earlyCancel
  assert "early cleanup runs exactly once" (repeatCount == 1)

  finiteQuit <- newIORef False
  finiteControl <- newRuntimeControl finiteQuit
  finiteModel <- newIORef 0
  finiteCancelled <- newIORef 0
  finishRef <- newIORef (pure ())
  sendRef <- newIORef (\_ => pure ())
  let finite = CompletingTask (\send, complete => do
        writeIORef sendRef send
        writeIORef finishRef complete
        pure (modifyIORef finiteCancelled S))
  execCmdManaged finite (dispatchManaged app finiteModel finiteControl) finiteControl
  registered <- readIORef finiteControl.cancellations
  assert "finite effect registered while pending" (length registered == 1)
  finiteSend <- readIORef sendRef
  finiteSend Add
  finish <- readIORef finishRef
  finish
  finish
  finiteSend Add
  remaining <- readIORef finiteControl.cancellations
  delivered <- readIORef finiteModel
  assert "completion retires cleanup" (null remaining)
  assert "completed effects reject further messages" (delivered == 1)
  cancelActiveEffects finiteControl
  finiteCount <- readIORef finiteCancelled
  assert "completed cleanup is not cancelled" (finiteCount == 0)
  traverse_ (\_ => execCmdManaged (CompletingTask (\send, complete => do
    send Add
    complete
    pure (modifyIORef finiteCancelled S)))
    (dispatchManaged app finiteModel finiteControl) finiteControl) (the (List Nat) [1..1000])
  retained <- readIORef finiteControl.cancellations
  assert "synchronous completed requests do not accumulate" (null retained)
  execCmdManaged finite (dispatchManaged app finiteModel finiteControl) finiteControl
  suspendRuntime finiteControl
  finishAfterCancel <- readIORef finishRef
  finishAfterCancel
  cancelActiveEffects finiteControl
  cancelledOnce <- readIORef finiteCancelled
  assert "pending finite effect cancelled exactly once" (cancelledOnce == 1)

  raceQuit <- newIORef False
  raceControl <- newRuntimeControl raceQuit
  raceCancelled <- newIORef 0
  execCmdManaged (CompletingTask (\_, complete => do
    complete
    execCmdManaged QuitApp (the (Msg -> IO ()) (\_ => pure ())) raceControl
    pure (modifyIORef raceCancelled S))) (the (Msg -> IO ()) (\_ => pure ())) raceControl
  raceCount <- readIORef raceCancelled
  assert "completion before synchronous quit does not cancel completed work" (raceCount == 0)

  overlapQuit <- newIORef False
  overlapControl <- newRuntimeControl overlapQuit
  firstFinish <- newIORef (pure ())
  secondFinish <- newIORef (pure ())
  execCmdManaged (CompletingTask (\_, complete => do
    writeIORef firstFinish complete
    pure (pure ()))) (the (Msg -> IO ()) (\_ => pure ())) overlapControl
  execCmdManaged (CompletingTask (\_, complete => do
    writeIORef secondFinish complete
    pure (pure ()))) (the (Msg -> IO ()) (\_ => pure ())) overlapControl
  finishFirst <- readIORef firstFinish
  finishFirst
  onePending <- readIORef overlapControl.cancellations
  assert "completion only retires its own effect" (length onePending == 1)
  finishSecond <- readIORef secondFinish
  finishSecond
  noPending <- readIORef overlapControl.cancellations
  assert "overlapping completions retire independently" (null noPending)

  putStrLn "Runtime tests passed"
