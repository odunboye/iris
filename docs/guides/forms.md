# Build forms with identity, validation and focus

Start from the [account form example](../../examples/form/README.md). It shares
model/update/view across DOM, Canvas and terminal and has executable browser
acceptance tests.

Use explicit `sKey` values for logical controls, especially when adding,
removing or reordering siblings. Keys are unique across the page; use a stable
record ID, not a list index. DOM patching preserves keyed controls under the
same parent. Canvas's semantic overlay uses keys for control identity and focus;
its update strategy differs from incremental DOM patching.

Construct styled controls with `WInput`, `WButton` and `WCheckbox`, starting
from `defaultStyle` or `styled` on every view. Apply these modifiers:

| Modifier | Purpose |
|---|---|
| `sAccessibleName name` | Give the control a programmatic name |
| `sDescription help` | Connect explanatory text to the control |
| `sDisabled disabled` | Disable activation/editing |
| `sReadOnly readOnly` | Prevent text editing while retaining a readable field |
| `sInvalid message` | Mark invalid input and expose its validation error |
| `sKey key` | Identify a logical control |
| `sFocus token` | Request focus for a keyed control |

An unchanged focus token does not take focus again on a later update. Increase
it when your model needs a new focus request. Disabled controls defer requests.
Build styles afresh so old errors and disabled state disappear when no longer
applicable.

Validate business actions in `update` as well as presenting disabled/invalid
controls. A widget's metadata does not prove that a message is authorized or
that submitted data is valid.

DOM and Canvas overlays map metadata to native control attributes. Terminal
renders disabled state but the application owns keyboard editing and activation.
Implement that behavior explicitly; browser-style focus does not apply there.

Canvas expands minimum touch hit targets without reflowing neighboring widgets.
Leave spacing between adjacent controls; the counter example uses padded
buttons. Test keyboard input, text composition and your intended assistive
technologies as well as pointer clicks.
