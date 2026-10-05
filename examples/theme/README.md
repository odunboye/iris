# Design tokens (Iris.Theme)

A light/dark toggle demonstrating `Iris.Theme`'s token records - and being
explicit about what's actually wired up today versus what's just typed
data. Nothing in `src/Iris/` imports `Iris.Theme`: it's a standalone design
token library an application can use, not something Iris applies for you.

From this repo's root:

```sh
pack --no-prompt install iris
pack --no-prompt --cg javascript build examples/theme/web.ipkg
python3 -m http.server 8080 --directory examples/theme
```

Open `http://127.0.0.1:8080/` and click "Toggle light/dark".

## What's real and what's illustrative

- **Colour tokens: real.** The swatches and the toggle button itself are
  styled from `theme.colors.*`, and their background genuinely changes
  across the swap - verified by reading each button's actual computed CSS
  (`getComputedStyle`), not just eyeballing a screenshot, and the RGB values
  matched `lightTheme`/`darkTheme`'s token values exactly (down to the
  0-255 truncation from `Theme`'s 0.0-1.0 channels).
- **Spacing tokens: real on this backend.** `spacing.px4`/`px2` set the
  swatches' real `padH`/`padV`. The DOM backend renders those Nat units
  directly as px (see `Backend.Web.DOM.Render`), so the mapping is exact
  here - Terminal and Canvas treat the same Nat as cells/cell-metrics
  instead, so a theme's px-based spacing wouldn't mean the same thing
  there without its own conversion.
- **Typography, radii, shadows, motion: illustrative only.** `Style` has no
  font-size field, and `BorderKind` is a fixed four-value enum, not
  parameterized by a radius - so these tokens are printed as plain text,
  not applied to anything. There's no shadow or animation-duration hook
  either.
- **Colour-space conversion: this demo's own code, not Iris's.** A theme
  colour (`Color`: 0.0-1.0 sRGB + alpha) and a widget's colour (`UIColor`:
  0-255 channels, no alpha) are different types with no built-in converter.
  `ThemeApp.idr`'s `toUIColor` is a small adapter this demo writes itself,
  dropping alpha since `Style` has no separate opacity channel.

If you're evaluating Iris for a themed application: the token *data* is
genuinely there and reasonably complete (Material-adjacent colour roles,
a 4px spacing grid, a type scale, radii, shadows, motion curves), but
applying most of it to actual widgets is work your application does today,
not something the framework does for you yet.
