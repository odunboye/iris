||| Iris.Backend.Web.DOM.Run
||| Browser entry point: runs an abstract Iris App using DOM rendering.
|||
||| Use this from your browser Main.idr:
|||
|||   main : IO ()
|||   main = runWeb myApp
|||
||| The same `myApp` value can be passed to
|||   Iris.Backend.Terminal.Run.runTUI   (terminal)
||| without changing any application code.
|||
||| Runtime architecture
||| ────────────────────
||| • ONE ordered event queue, `window.__irisEvents` - every input
|||   source (keydown, button/checkbox click, `WInput` text change)
|||   pushes a tagged entry onto it, and `drainAll` (below) processes
|||   them strictly in arrival order every frame. This matters, and
|||   used to be three SEPARATE queues (keys, clicks, inputs), each
|||   fully drained in a fixed key-then-click-then-input order every
|||   tick regardless of what order the events actually happened in - a
|||   real bug, not a hypothetical: edit a field then click "Save"
|||   within the same ~33ms frame, and the old code ran EVERY click
|||   before ANY input-change, so `Save` dispatched against the model's
|||   STALE field value, one frame behind what the user just typed. A
|||   single tagged queue preserves true chronological order across all
|||   three sources instead.
|||     - `K<key>` - a keydown, resolved via `UIApp.handleKey`.
|||     - `C<id>` - a button/checkbox activation, `id` resolved to a
|||       `msg` through the per-render `idMap`.
|||     - `I<id><sep><value>` - a `WInput` change (`sep` = `chr 1`),
|||       `id` resolved to an `onChange : String -> msg` through the
|||       per-render `inputMap`, applied to `value`.
|||     - `F<id><sep><dataURL>` - a `WCapture` change, resolved the same
|||       way through `inputMap` (same `(id, String -> msg)` shape as
|||       `I`); `dataURL` is a base64 `data:image/...` URL read via
|||       image decoding, so unlike every other tag this one is pushed
|||       asynchronously, after the image finishes decoding.
||| • A `setTimeout(33ms)` chain drives the render loop (~30 fps).
||| • A `setTimeout(100ms)` chain drives the animation tick.
|||
||| The loop renders every ~33ms, patching the DOM only when HTML changes.
||| Focus and selection are restored by control ID. Use sKey for controls in
||| dynamic trees; positional IDs are only stable in fixed interactive trees.
module Iris.Backend.Web.DOM.Run

import Data.IORef
import Iris.Effect.Command
import Iris.Platform.Event
import Iris.App
import Iris.Widget
import Iris.Backend.Web.DOM.Render
import Iris.Runtime.Common
import Iris.App.EventWire

-- ─── JS FFI ──────────────────────────────────────────────────────────────────

-- Install static and generated styles through the CSSOM. Constructed
-- stylesheets avoid style elements and style attributes under a strict CSP.
%foreign "javascript:lambda: (css, _w) => { if(!globalThis.__irisStyleSheet){const sheet=new CSSStyleSheet();sheet.replaceSync(css);document.adoptedStyleSheets=[...document.adoptedStyleSheets,sheet];globalThis.__irisStyleSheet=sheet;globalThis.__irisStyleRules=new Map();globalThis.__irisApplyStyles=(root)=>{root.querySelectorAll('[data-iris-style]').forEach(el=>{const value=el.dataset.irisStyle;let cls=globalThis.__irisStyleRules.get(value);if(!cls){cls='iris-dyn-'+globalThis.__irisStyleRules.size;sheet.insertRule('.'+cls+'{'+value+'}',sheet.cssRules.length);globalThis.__irisStyleRules.set(value,cls);}el.classList.add(cls);el.removeAttribute('data-iris-style');});};} }"
prim_injectCSS : String -> PrimIO ()

-- Patch compatible nodes in place. Keyed controls can move among siblings;
-- their native state survives updates. Input values are left alone during
-- composition; focus and selection are restored if a move disturbed them.
%foreign "javascript:lambda: (html, _w) => { const root=document.getElementById('iris-app');if(!root)return; const active=document.activeElement;const id=active&&root.contains(active)?active.id:null; let start,end;try{start=active.selectionStart;end=active.selectionEnd;}catch(e){} const template=document.createElement('template');template.innerHTML=html; const compatible=(a,b)=>a.nodeType===b.nodeType&&(a.nodeType!==1||(a.tagName===b.tagName&&a.id===b.id)); const patch=(old,next)=>{ if(old.nodeType!==1){if(old.nodeValue!==next.nodeValue)old.nodeValue=next.nodeValue;return;} for(const attr of Array.from(old.attributes))if(!next.hasAttribute(attr.name))old.removeAttribute(attr.name); for(const attr of Array.from(next.attributes))if(old.getAttribute(attr.name)!==attr.value)old.setAttribute(attr.name,attr.value); if(old.tagName==='INPUT'){ if(old.value!==next.value&&!old.__irisComposing)old.value=next.value; old.checked=next.checked; } children(old,next); }; const children=(old,next)=>{ let cursor=old.firstChild; for(const desired of Array.from(next.childNodes)){ let found=desired.nodeType===1&&desired.id?Array.from(old.childNodes).find(n=>n.nodeType===1&&n.id===desired.id&&compatible(n,desired)):cursor&&compatible(cursor,desired)?cursor:null; if(found){if(found!==cursor)old.insertBefore(found,cursor);patch(found,desired);cursor=found.nextSibling;} else{old.insertBefore(desired.cloneNode(true),cursor);} } while(cursor){const nextNode=cursor.nextSibling;cursor.remove();cursor=nextNode;} }; children(root,template.content); if(globalThis.__irisApplyStyles)globalThis.__irisApplyStyles(root); if(id){const next=Array.from(root.querySelectorAll('[id]')).find(n=>n.id===id);if(next){if(document.activeElement!==next)next.focus();if(start!=null&&!next.__irisComposing)try{next.setSelectionRange(start,end);}catch(e){}}} }"
prim_setHTML : String -> PrimIO ()

-- Set up ONE ordered event queue, then attach the keyboard listener.
-- Every source pushes a TAGGED entry - "K<key>" (keydown), "C<id>"
-- (button/checkbox click), "I<id><sep><value>" (WInput change, sep =
-- chr 1) - so `drainAll` (below) can process all three in the order
-- they actually happened, not per-type batches (see this module's own
-- doc comment for why that distinction is load-bearing, not cosmetic).
--
-- The `preventDefault()` on Arrow*/Space is only correct when nothing
-- with real native text-editing behavior has focus - it exists so
-- Space/arrow-key APP NAVIGATION (list selection, toggling) doesn't
-- also scroll the page, the same conflict a plain `<button>` already
-- guards against by default. A confirmed real regression from making
-- `WInput` a genuine (non-readonly) field: applied unconditionally,
-- this same `preventDefault()` also blocked the BROWSER's own default
-- behavior for a focused text input - Space could not be typed into it
-- at all, since the keydown was suppressed before the browser ever got
-- to insert the character. Gated on `document.activeElement` now: an
-- `<input>` in focus gets its normal native text-editing behavior;
-- nothing focused (the traditional TUI-nav-on-a-page case) keeps the
-- old scroll-prevention behavior.
%foreign "javascript:lambda: _w => { if(window.__irisQueuesReady) return; window.__irisQueuesReady=true; const q=window.__irisEvents=window.__irisEvents||[]; const controller=new AbortController();window.__irisAbort=controller;const on=(target,name,fn,opts={})=>target.addEventListener(name,fn,{...opts,signal:controller.signal}); const enc=s=>Array.from(String(s)).map(c=>c.codePointAt(0)).join('.'); const b=v=>v?'1':'0'; const mods=e=>[b(e.shiftKey),b(e.ctrlKey),b(e.altKey),b(e.metaKey)].join('|'); const push=s=>{if(!controller.signal.aborted)q.push(s);}; const key=(a,e)=>push('f1|K|'+a+'|'+enc(e.key)+'|'+enc(e.code||e.key)+'|'+mods(e)+'|'+(Array.from(e.key).length===1?e.key.codePointAt(0):'none')); on(document,'keydown',e=>{ const inField=document.activeElement&&document.activeElement.tagName==='INPUT'; if(!inField&&['ArrowUp','ArrowDown','ArrowLeft','ArrowRight',' '].includes(e.key))e.preventDefault(); key(e.repeat?'repeat':'down',e); }); on(document,'keyup',e=>key('up',e)); const pa={pointerdown:'down',pointerup:'up',pointermove:'move',pointerenter:'enter',pointerleave:'leave',pointercancel:'cancel'}; const pb=n=>n===0?'primary':n===1?'middle':n===2?'secondary':n===3?'back':n===4?'forward':'none'; Object.keys(pa).forEach(name=>on(document,name,e=>push('f1|P|'+pa[name]+'|'+(['mouse','touch','pen'].includes(e.pointerType)?e.pointerType:'mouse')+'|'+Math.max(0,e.pointerId||0)+'|'+e.clientX+'|'+e.clientY+'|'+(e.movementX||0)+'|'+(e.movementY||0)+'|'+pb(e.button)+'|'+Math.max(0,Math.min(1,e.pressure||0))+'|'+mods(e)),{passive:true})); on(document,'wheel',e=>push('f1|S|'+e.clientX+'|'+e.clientY+'|'+e.deltaX+'|'+e.deltaY+'|'+e.deltaZ),{passive:true}); on(window,'resize',()=>push('f1|R|'+innerWidth+'|'+innerHeight)); on(window,'focus',()=>push('f1|F|gain')); on(window,'blur',()=>push('f1|F|lost')); on(window,'orientationchange',()=>push('f1|O|'+(innerHeight>=innerWidth?'portrait':'landscape'))); on(document,'visibilitychange',()=>push('f1|L|'+(document.hidden?'hidden':'visible'))); on(window,'pagehide',()=>push('f1|L|pause')); on(window,'pageshow',()=>push('f1|L|resume')); on(window,'popstate',()=>{push('f1|L|back');push('f1|L|location|'+enc(location.pathname+location.search+location.hash));}); on(document,'compositionstart',e=>{e.target.__irisComposing=true;push('f1|M|start|'+enc(e.data||''));}); on(document,'compositionupdate',e=>push('f1|M|update|'+enc(e.data||''))); on(document,'compositionend',e=>{e.target.__irisComposing=false;push('f1|M|end|'+enc(e.data||''));}); on(document,'click',e=>{const target=e.target&&e.target.closest('[data-iris-click]');if(target&&document.getElementById('iris-app')?.contains(target))push('C'+target.dataset.irisClick);}); on(document,'input',e=>{const target=e.target&&e.target.closest('[data-iris-input]');if(target&&document.getElementById('iris-app')?.contains(target))push('I'+target.dataset.irisInput+'\x01'+target.value);}); on(document,'change',e=>{const target=e.target&&e.target.closest('[data-iris-capture]');if(!target||!document.getElementById('iris-app')?.contains(target))return;const file=target.files&&target.files[0];if(!file)return;const id=target.dataset.irisCapture;const generation=(target.__irisCaptureGeneration||0)+1;target.__irisCaptureGeneration=generation;target.value='';target.setCustomValidity('');const current=()=>!controller.signal.aborted&&target.isConnected&&target.dataset.irisCapture===id&&target.__irisCaptureGeneration===generation; (async()=>{let bitmap;try{if(!['image/jpeg','image/png'].includes(file.type)||file.size>8*1024*1024)throw Error('Choose a JPEG or PNG under 8 MB.');bitmap=await createImageBitmap(file);if(!current())return;if(!bitmap.width||!bitmap.height||bitmap.width*bitmap.height>24000000)throw Error('Choose a photo under 24 megapixels.');const scale=Math.min(1,1600/Math.max(bitmap.width,bitmap.height));const canvas=document.createElement('canvas');canvas.width=Math.max(1,Math.round(bitmap.width*scale));canvas.height=Math.max(1,Math.round(bitmap.height*scale));canvas.getContext('2d').drawImage(bitmap,0,0,canvas.width,canvas.height);const photo=canvas.toDataURL('image/jpeg',0.85);if(photo.length>2796230)throw Error('The prepared photo is too large. Choose a smaller image.');if(current())push('F'+id+'\x01'+photo);}catch(error){if(current()){target.setCustomValidity(error.message||'Could not read this photo.');target.reportValidity();}}finally{bitmap?.close();}})();}); push('f1|L|location|'+enc(location.pathname+location.search+location.hash)); if(window.Capacitor&&window.Capacitor.Plugins&&window.Capacitor.Plugins.App){ [['backButton','back'],['pause','pause'],['resume','resume']].forEach(([name,event])=>{Promise.resolve(window.Capacitor.Plugins.App.addListener(name,()=>push('f1|L|'+event))).then(handle=>{if(controller.signal.aborted)handle.remove();else controller.signal.addEventListener('abort',()=>handle.remove(),{once:true});});}); } }"
prim_setupQueues : PrimIO ()

%foreign "javascript:lambda: _w => { if(window.__irisAbort)window.__irisAbort.abort();window.__irisAbort=null;window.__irisQueuesReady=false;window.__irisEvents=[]; }"
prim_teardownQueues : PrimIO ()

-- Poll one tagged event string from the queue ('' if empty)
%foreign "javascript:lambda: _w => (window.__irisEvents&&window.__irisEvents.length>0)?window.__irisEvents.shift():''"
prim_pollEvent : PrimIO String

-- Schedule a one-shot timeout
%foreign "javascript:lambda: (ms, f, _w) => { const delay=document.hidden ? Math.max(ms,250) : ms; const timers=globalThis.__irisTimers||(globalThis.__irisTimers=new Set());const epoch=globalThis.__irisTimerEpoch||0;const id=setTimeout(function(){timers.delete(id);if(epoch===(globalThis.__irisTimerEpoch||0))f(0);},delay);timers.add(id); }"
prim_setTimeout : Int -> IO () -> PrimIO ()

-- ─── IO wrappers ─────────────────────────────────────────────────────────────

injectCSS : String -> IO ()
injectCSS css = primIO (prim_injectCSS css)

setHTML : String -> IO ()
setHTML html = do
  primIO (prim_setHTML html)
  focusControls "#iris-app"

setupQueues : IO ()
setupQueues = primIO prim_setupQueues

teardownQueues : IO ()
teardownQueues = primIO prim_teardownQueues

pollEvent : IO String
pollEvent = primIO prim_pollEvent

scheduleIn : Int -> IO () -> IO ()
scheduleIn ms f = primIO (prim_setTimeout ms f)

-- ─── Key → KeyEvent ──────────────────────────────────────────────────────────

domKey : String -> KeyEvent
domKey k =
  let ch = case unpack k of [c] => Just c; _ => Nothing
  in MkKeyEvent KeyDown k k (MkModifiers False False False False) ch

-- ─── Input draining ──────────────────────────────────────────────────────────

-- Separator between a `WInput` event's id and its value, inside an
-- "I<id><sep><value>" tagged queue entry - see the FFI setup above.
sepChar : Char
sepChar = chr 1

splitOnce : Char -> List Char -> (List Char, List Char)
splitOnce sep = go []
  where
    go : List Char -> List Char -> (List Char, List Char)
    go acc []        = (reverse acc, [])
    go acc (c :: cs) = if c == sep then (reverse acc, cs) else go (c :: acc) cs

lookupNat : Nat -> List (Nat, a) -> Maybe a
lookupNat _ []               = Nothing
lookupNat k ((i, v) :: rest) = if k == i then Just v else lookupNat k rest

applyLifecycle : RuntimeControl -> Event -> IO ()
applyLifecycle control (LifecycleEvt PageHidden) = suspendRuntime control
applyLifecycle control (LifecycleEvt AppPaused) = suspendRuntime control
applyLifecycle control (LifecycleEvt PageVisible) = resumeRuntime control
applyLifecycle control (LifecycleEvt AppResumed) = resumeRuntime control
applyLifecycle _ _ = pure ()

handlePlatformEvent : UIApp mdl msg -> IORef mdl -> RuntimeControl -> Event -> IO ()
handlePlatformEvent app modelRef control event = do
  applyLifecycle control event
  model <- readIORef modelRef
  case app.handleEvent model event of
    Nothing => pure ()
    Just message => dispatchManaged app modelRef control message

-- Drains the ONE ordered event queue, dispatching each entry in the
-- exact order it happened - see this module's doc comment for why that
-- matters (it's the fix for a real edit-then-submit-in-one-frame bug,
-- not just a refactor). Recurses until the queue is empty; `quit`
-- becomes true partway through, later entries in the same batch are
-- correctly skipped rather than dispatched into a model that's about
-- to be torn down.
drainAll : UIApp mdl outMsg -> IORef mdl -> IORef Bool -> RuntimeControl
         -> IORef (List (Nat, outMsg)) -> IORef (List (Nat, String -> outMsg)) -> IO ()
drainAll app modelRef quitRef control idMapRef inputMapRef = do
  raw <- pollEvent
  case unpack raw of
    []                 => pure ()
    ('f' :: _)         => do
      quit <- readIORef quitRef
      when (not quit) $
        case decodeEvent raw of
          Nothing => pure ()
          Just event => handlePlatformEvent app modelRef control event
      continue
    ('C' :: idChars)   => do
      idMap <- readIORef idMapRef
      quit  <- readIORef quitRef
      when (not quit) $
        case lookupNat (cast {to=Nat} (cast {to=Int} (pack idChars))) idMap of
          Nothing  => pure ()
          Just msg => dispatchManaged app modelRef control msg
      continue
    ('I' :: rest)      => do
      let (idChars, valChars) = splitOnce sepChar rest
      case idChars of
        [] => continue
        _  => do
          inputMap <- readIORef inputMapRef
          quit     <- readIORef quitRef
          when (not quit) $
            case lookupNat (cast {to=Nat} (cast {to=Int} (pack idChars))) inputMap of
              Nothing    => pure ()
              Just toMsg => dispatchManaged app modelRef control (toMsg (pack valChars))
          continue
    -- 'F<id><sep><dataURL>' - a WCapture change. Delivered via the same
    -- inputMap WInput uses (both are id -> (String -> msg)); the payload
    -- here is a "data:image/...;base64,..." prepared JPEG data URL
    -- glue in prim_setupQueues, not live DOM state to poll, so this (like
    -- 'I') is pushed once from the event itself rather than drained.
    ('F' :: rest)      => do
      let (idChars, valChars) = splitOnce sepChar rest
      case idChars of
        [] => continue
        _  => do
          inputMap <- readIORef inputMapRef
          quit     <- readIORef quitRef
          when (not quit) $
            case lookupNat (cast {to=Nat} (cast {to=Int} (pack idChars))) inputMap of
              Nothing    => pure ()
              Just toMsg => dispatchManaged app modelRef control (toMsg (pack valChars))
          continue
    _                  => continue -- malformed/unrecognized tag, skip
  where
    continue : IO ()
    continue = drainAll app modelRef quitRef control idMapRef inputMapRef

-- ─── Render loop ─────────────────────────────────────────────────────────────

renderLoop : UIApp mdl outMsg -> IORef mdl -> IORef Bool -> RuntimeControl
           -> IORef String -> IORef (List (Nat, outMsg)) -> IORef (List (Nat, String -> outMsg)) -> IO ()
renderLoop app modelRef quitRef control htmlRef idMapRef inputMapRef = do
  quit <- readIORef quitRef
  if quit
    then do
      teardownQueues
      setHTML "<div data-iris-style='padding:24px;color:#3fb950;font-size:1.2em'>👋 Bye! Refresh to restart.</div>"
    else do
      -- drain input, in true chronological order (see drainAll's doc comment)
      drainAll app modelRef quitRef control idMapRef inputMapRef

      -- render
      quit2 <- readIORef quitRef
      when (not quit2) $ do
        mdl <- readIORef modelRef
        (html, pairs, inputs) <- renderPage (app.view mdl)
        previous <- readIORef htmlRef
        when (html /= previous) $ do
          setHTML html
          writeIORef htmlRef html
        writeIORef idMapRef pairs
        writeIORef inputMapRef inputs
        scheduleIn 33 (renderLoop app modelRef quitRef control htmlRef idMapRef inputMapRef)

-- ─── Tick loop ───────────────────────────────────────────────────────────────

tickLoop : UIApp mdl outMsg -> IORef mdl -> IORef Bool -> RuntimeControl -> Int -> IO ()
tickLoop app modelRef quitRef control ms = do
  quit <- readIORef quitRef
  when (not quit) $ do
    case app.tickMsg of
      Nothing => pure ()
      Just tm => dispatchManaged app modelRef control tm
    scheduleIn ms (tickLoop app modelRef quitRef control ms)

-- ─── Opt-in development hot replacement ──────────────────────────────────────

||| Explicit wire boundary between separately compiled model representations.
||| Bump version when the state schema/semantics are incompatible. Never transfer
||| raw Idris objects or functions. Nothing from save defers a swap (e.g. busy).
||| restore must validate and sanitize, and must not execute effects. Payloads
||| stay in memory; the framework never sends or persists them.
public export
record HotState model where
  constructor MkHotState
  version : String
  save : model -> Maybe String
  restore : String -> Maybe model

%foreign "javascript:lambda: (version, prepare, start, _w) => {const hot=globalThis.__fluxHot;if(!hot)return 0;hot.offer({version,prepare:s=>prepare(s)(0),start:()=>start(0)});return 1;}"
prim_hotOffer : String -> (String -> IO Int) -> IO () -> PrimIO Int

%foreign "javascript:lambda: (snapshot, dispose, _w) => {globalThis.__fluxHot.attach({snapshot:()=>snapshot(0),dispose:()=>dispose(0)});}"
prim_hotAttach : IO String -> IO () -> PrimIO ()

-- A replacement which removed runWebHot must not start a second plain runtime
-- before the development client detects the missing hot registration.
%foreign "javascript:lambda: _w => {const hot=globalThis.__fluxHot;return hot&&hot.loading()?1:0;}"
prim_hotLoading : PrimIO Int

%foreign "javascript:lambda: _w => {globalThis.__irisTimerEpoch=(globalThis.__irisTimerEpoch||0)+1;if(globalThis.__irisTimers){for(const id of globalThis.__irisTimers)clearTimeout(id);globalThis.__irisTimers.clear();}const sheet=globalThis.__irisStyleSheet;if(sheet)document.adoptedStyleSheets=document.adoptedStyleSheets.filter(s=>s!==sheet);delete globalThis.__irisStyleSheet;delete globalThis.__irisStyleRules;delete globalThis.__irisApplyStyles;}"
prim_resetDOM : PrimIO ()

startWeb : UIApp mdl outMsg -> Maybe (HotState mdl) -> IO ()
startWeb app hot = do
  -- inject stylesheet once
  injectCSS irisCSS
  setupQueues

  -- initialise model
  let (initMdl, initCmd) = app.init
  modelRef    <- newIORef initMdl
  quitRef     <- newIORef False
  control     <- newRuntimeControl quitRef
  htmlRef     <- newIORef ""
  idMapRef    <- newIORef (the (List (Nat, outMsg)) [])
  inputMapRef <- newIORef (the (List (Nat, String -> outMsg)) [])

  -- run startup commands
  execCmdManaged initCmd (dispatchManaged app modelRef control) control

  -- initial render
  mdl <- readIORef modelRef
  (html, pairs, inputs) <- renderPage (app.view mdl)
  setHTML html
  writeIORef htmlRef html
  writeIORef idMapRef pairs
  writeIORef inputMapRef inputs

  -- start loops
  scheduleIn 100 (tickLoop app modelRef quitRef control 100)
  scheduleIn 33  (renderLoop app modelRef quitRef control htmlRef idMapRef inputMapRef)

  case hot of
    Nothing => pure ()
    Just codec => do
      let snapshot : IO String = do
            drainAll app modelRef quitRef control idMapRef inputMapRef
            model <- readIORef modelRef
            quit <- readIORef quitRef
            if quit then pure "0" else pure $ case codec.save model of
              Nothing => ""
              Just payload => "1" ++ payload
      let dispose : IO () = do
            writeIORef quitRef True
            cancelActiveEffects control
            teardownQueues
            primIO prim_resetDOM
      primIO (prim_hotAttach snapshot dispose)

||| Run normally. No HMR registration, serialization or state storage.
public export
runWeb : UIApp mdl outMsg -> IO ()
runWeb app = do
  replacing <- primIO prim_hotLoading
  when (replacing == 0) (startWeb app Nothing)

||| Opt-in hot replacement under Flux dev --hot; identical to runWeb otherwise.
||| A restored runtime skips init commands. Re-establish required subscriptions
||| through application-managed events, never by replaying startup writes.
public export
runWebHot : HotState mdl -> UIApp mdl outMsg -> IO ()
runWebHot codec app = do
  candidate <- newIORef (the (Maybe mdl) Nothing)
  let prepare : String -> IO Int = \payload => case codec.restore payload of
        Nothing => pure 0
        Just restored => do
          -- Preflight the new view before tearing down the active generation.
          _ <- renderPage (app.view restored)
          writeIORef candidate (Just restored)
          pure 1
  let start : IO () = do
        restored <- readIORef candidate
        writeIORef candidate Nothing
        case restored of
          Nothing => startWeb app (Just codec)
          Just model => startWeb (MkApp (model, none) app.update app.view app.handleEvent app.tickMsg) (Just codec)
  offered <- primIO (prim_hotOffer codec.version prepare start)
  when (offered == 0) (runWeb app)
