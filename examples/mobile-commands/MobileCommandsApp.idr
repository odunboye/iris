||| The shared UIApp value: one button per Iris.Mobile native command.
||| Uses runWeb (not runMobile/Canvas) deliberately - Iris.Mobile's commands
||| only need globalThis.IdrisCapacitor, not any particular renderer, so DOM
||| rendering lets every result show up as real, inspectable text. See the
||| README for why index.html substitutes a mock bridge for a real device.
module MobileCommandsApp

import Iris
import Iris.Mobile

record Model where
  constructor MkModel
  log : List String

data Msg
  = ShowToast
  | ShowAlert
  | AskConfirm
  | AskPrompt
  | ShowActionSheet
  | GetDeviceInfo
  | GetBatteryInfo
  | GetDeviceId
  | GetNetworkStatus
  | WatchNetwork
  | ToastDone (Either MobileError ())
  | AlertDone (Either MobileError ())
  | ConfirmDone (Either MobileError ConfirmResult)
  | PromptDone (Either MobileError PromptResult)
  | ActionSheetDone (Either MobileError ActionSheetResult)
  | DeviceInfoDone (Either MobileError DeviceInfo)
  | BatteryInfoDone (Either MobileError BatteryInfo)
  | DeviceIdDone (Either MobileError String)
  | NetworkStatusDone (Either MobileError NetworkStatus)
  | NetworkChanged (Either MobileError NetworkStatus)

initModel : Model
initModel = MkModel ["Pick a command below."]

logLine : String -> Model -> Model
logLine entry m = { log $= (entry ::) } m

resultText : (a -> String) -> Either MobileError a -> String
resultText _ (Left err)    = "error: " ++ err.message
resultText f (Right value) = f value

update : Msg -> Model -> (Model, Cmd Msg)
update ShowToast m =
  (m, toastCommand (MkToastOptions "Hello from Iris.Mobile!" Short Bottom) ToastDone)
update ShowAlert m =
  (m, alertCommand (MkAlertOptions "Iris" "This is a native alert." "OK") AlertDone)
update AskConfirm m =
  (m, confirmCommand (MkConfirmOptions "Confirm" "Do you want to continue?" "Yes" "No") ConfirmDone)
update AskPrompt m =
  (m, promptCommand (MkPromptOptions "Prompt" "What is your name?" "OK" "Cancel" "Name" "") PromptDone)
update ShowActionSheet m =
  (m, actionSheetCommand
        (MkActionSheetOptions "Pick a color" "" [MkButton "Red", MkButton "Green", MkButton "Blue"])
        ActionSheetDone)
update GetDeviceInfo m    = (m, deviceInfoCommand DeviceInfoDone)
update GetBatteryInfo m   = (m, batteryInfoCommand BatteryInfoDone)
update GetDeviceId m      = (m, deviceIdCommand DeviceIdDone)
update GetNetworkStatus m = (m, networkStatusCommand NetworkStatusDone)
update WatchNetwork m     = (logLine "watching network changes (fires until the page unloads)..." m
                             , networkChanges NetworkChanged)
update (ToastDone r) m       = (logLine ("Toast: " ++ resultText (const "shown") r) m, none)
update (AlertDone r) m       = (logLine ("Alert: " ++ resultText (const "dismissed") r) m, none)
update (ConfirmDone r) m     = (logLine ("Confirm: " ++ resultText show r) m, none)
update (PromptDone r) m      = (logLine ("Prompt: " ++ resultText show r) m, none)
update (ActionSheetDone r) m = (logLine ("ActionSheet: " ++ resultText show r) m, none)
update (DeviceInfoDone r) m  = (logLine ("DeviceInfo: " ++ resultText show r) m, none)
update (BatteryInfoDone r) m = (logLine ("BatteryInfo: " ++ resultText show r) m, none)
update (DeviceIdDone r) m    = (logLine ("DeviceId: " ++ resultText id r) m, none)
update (NetworkStatusDone r) m = (logLine ("NetworkStatus: " ++ resultText show r) m, none)
update (NetworkChanged r) m    = (logLine ("NetworkChanged: " ++ resultText show r) m, none)

view : Model -> Widget Msg
view m = vstack $
  [ text "Iris.Mobile native command demo"
  , divider
  , hstack [ WButton defaultStyle "Toast" ShowToast, WButton defaultStyle "Alert" ShowAlert ]
  , hstack [ WButton defaultStyle "Confirm" AskConfirm, WButton defaultStyle "Prompt" AskPrompt ]
  , hstack [ WButton defaultStyle "Action sheet" ShowActionSheet ]
  , hstack [ WButton defaultStyle "Device info" GetDeviceInfo
           , WButton defaultStyle "Battery info" GetBatteryInfo
           , WButton defaultStyle "Device id" GetDeviceId
           ]
  , hstack [ WButton defaultStyle "Network status" GetNetworkStatus
           , WButton defaultStyle "Watch network" WatchNetwork
           ]
  , divider
  , text "Log (newest first):"
  ] ++ map text m.log

handleEvent : Model -> Event -> Maybe Msg
handleEvent _ _ = Nothing

export
mobileCommandsApp : UIApp Model Msg
mobileCommandsApp = MkApp (initModel, none) update view handleEvent Nothing
