# Package and mobile configuration

## Target package files

A generated mobile target for Greeter has:

```text
package iris-greeter-mobile
depends = iris
sourcedir = "src"
main = MainMobile
executable = greeter-mobile
```

Web uses `main = MainWeb` and `executable = greeter-web`. Build both with the
JavaScript code generator. A terminal target uses `Main`, the native compiler
backend and a C support-library prebuild step.

`pack.toml` locates dependencies and registers target packages. `new` initially
pins Iris as a git dependency. Mobile CLI compilation currently requires all
custom dependencies to be local; see
[the tutorial's local-map step](../tutorials/web-to-android.md#4-use-a-local-iris-dependency-for-mobile-compilation).

## iris.mobile.json

The generated configuration for Greeter is equivalent to:

```json
{
  "format": 1,
  "appId": "com.example.greeter",
  "appName": "Greeter",
  "capacitor": "/absolute/path/to/capacitor",
  "webDir": "public",
  "entry": "build/exec/greeter-mobile",
  "ui": "mobile.ipkg",
  "assets": ["index.html", "*.css"]
}
```

| Field | Meaning |
|---|---|
| `format` | `1` for packaging-only preview; `2` for origin-bound mobile RPC |
| `appId` | Reverse-domain native identity; choose before creating a release host |
| `appName` | Native display name |
| `capacitor` | Full Idris Capacitor library checkout; absolute or project-relative |
| `webDir` | Project-relative source public-assets directory |
| `entry` | Project-relative compiled standalone JavaScript program |
| `ui` | UI package for compile; scaffold writes it explicitly |
| `assets` | Explicit nonrecursive public-asset globs |
| `apiOrigin` | Format 2 only: explicit canonical HTTPS API origin |

Unknown/duplicate fields are rejected. Public assets allow HTML, CSS, images,
icons and fonts; JavaScript comes from `entry`, not an asset glob. No recursive
`**`, hidden files, JSON/private metadata, symlinks or escaping paths. Include
`index.html` and exactly one `<script src="app.js"></script>` in that host;
packaging converts it to the bundled module entry.

Keep Canvas dimensions independent of its bitmap with the generated linked
stylesheet. Its viewport sizing is described in
[startup troubleshooting](../troubleshooting/startup.md#canvas-disappears-after-startup).

## Networked mobile bundles

Format 2 requires a canonical HTTPS `apiOrigin` and exactly one CSP meta element
with the required directives. It binds `connect-src` to the configured API and
initializes immutable runtime configuration before the app. Format 1 cannot
initialize `Iris.Mobile.Client.mobileClient`. Follow the complete
[configuration contract](mobile-capacitor.md#configuration) before
switching formats.

Native identity changes are refused after a host exists. Releases and native
hosts are owned outputs, not interchangeable folders to reuse between apps.
See [ownership](mobile-capacitor.md#ownership-and-publication).
