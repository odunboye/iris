# Capture photos

Use Iris's `WCapture` in a DOM application, including a DOM application packaged
inside a Capacitor WebView:

```idris
WCapture (sKey "document-front" (sAccessibleName "Document front" defaultStyle))
  FacingEnvironment FrontPhoto

captureSelfie SelfiePhoto
```

The callback takes a JPEG data URL. Store it in the model and submit it through
an HTTP effect when the user continues. Use stable keys for independent photo
controls. `FacingEnvironment` prefers the rear camera, `FacingUser` the front,
and `FacingAny` omits the preference. `captureDocument` and `captureSelfie` are
convenience constructors. Disabled controls do not register a callback.

The browser decides whether a file control opens its camera or a file picker.
Desktop browsers generally open a picker. This API does not provide a live
camera preview or a native Capacitor Camera plugin. Terminal displays a
placeholder and Canvas has no interactive capture implementation.

The DOM runner accepts JPEG/PNG inputs up to 8 MiB and 24 megapixels, decodes
the image, scales its longest edge to at most 1600 pixels, and re-encodes JPEG
at quality 0.85. Re-encoding removes the original file's metadata. The encoded
payload is limited to about 2 MiB. Invalid or unreadable inputs show native
validation feedback and do not dispatch a photo. Cancelling the picker leaves
the model unchanged; choosing the same file again is supported.

Only the latest selection for a mounted control is delivered. A decode finishing
after the control is removed or the runner stops is discarded, and decoded
bitmap resources are released. These client checks help usability; servers must
validate uploaded image content and enforce their own limits.

The browser regression harness is `tests/capture-dom.ipkg`. Build it with
`pack --cg javascript --no-prompt build tests/capture-dom.ipkg`, then run
`npx playwright test tests/browser/capture.spec.js`.
