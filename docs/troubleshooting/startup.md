# Resolve browser and Android startup problems

Identify which step failed: scaffolding, compilation, packaging, native build
or runtime. Keep the first relevant error and the command that produced it.

## iris is unavailable inside a generated project

`./iris` exists in the framework checkout, not in the generated project. Install
it with the checkout's `./iris install-cli`, put the launcher directory on PATH,
and use `iris` in your project. You can also invoke the checkout launcher by its
absolute path. Moving/removing that checkout breaks the installed launcher.

## Mobile compile rejects the Pack map

`Mobile compile currently requires a local managed Pack map` means a custom
package still has `type = "git"` or another non-local type. The scaffold itself
starts with a git pin. Follow the
[local dependency step](../tutorials/web-to-android.md#4-use-a-local-iris-dependency-for-mobile-compilation),
including Iris's entry; keep the target registrations.

## Build cannot find the application entry

Run `iris compile` first. Confirm `iris.mobile.json` names the intended UI
package and executable path. `iris build` packages an existing entry; it does
not compile changed source. For the ordinary DOM target, use Pack's JavaScript
build command and serve the project root, not just `public/`.

## Sync reports stale or modified assets

Rebuild from source. After editing Idris: `iris compile`, then `iris build`.
After editing public HTML/CSS/configuration: `iris build`. Then sync/run again.
Do not patch `releases/<id>/app.js` or the copied Android assets to make a fix;
those are generated outputs with recorded fingerprints and hashes.

## Device selection exits without deploying

Run `iris run android` in an interactive terminal with an emulator already
started. Automated execution can stop at Capacitor's device-selection prompt.
Use the [host CLI with an explicit target](../tutorials/web-to-android.md#6-know-where-the-outputs-live)
for noninteractive deployment. Run that CLI from `.workspace/mobile/native`,
otherwise Capacitor can report that the Android platform has not been added.

## Canvas disappears after startup

Verify `public/index.html` links `canvas.css`, and that `*.css` or the specific
CSS filename is included in `assets`. The generated stylesheet contains:

```css
html,body{margin:0;width:100%;height:100%;overflow:hidden}
#iris-canvas{display:block;width:100%;height:100%;touch-action:none}
```

Canvas has logical CSS dimensions and a bitmap scaled by device pixel ratio.
Older Iris versions could repeatedly enlarge an unstyled Canvas's intrinsic
layout on high-DPI Android devices. The corrected runtime guards that case;
keep explicit viewport CSS for the intended full-screen layout.

Use WebView inspection to compare `clientWidth`/`clientHeight`, `width`/`height`
and `devicePixelRatio`. Bitmap size should be approximately logical size times
DPR and remain stable across frames. A white screen alone does not establish
that the Android process crashed; check Logcat and whether the process is alive.

## A terminal button does not react

Terminal input is application-defined. Add key mappings in `handleEvent`;
[the counter](../../examples/counter/Counter.idr) supplies an example. DOM/Canvas
control activation and browser focus are not terminal guarantees.

## Native plugins or sessions fail

Confirm packaging registered plugins before the application. Read the
[mobile bindings guide](../../mobile/README.md), and run `iris check` to verify
the adapter separately from your app. Session-vault hosts intentionally disable
bridge logging; do not enable payload logging as a workaround. Adapter tests
and a successful emulator startup do not replace physical-device validation.
