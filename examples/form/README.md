# Account form

One model, update function and view run through DOM, Canvas and terminal.
The form demonstrates names/descriptions, validation, disabled/read-only controls
and explicit focus. Save validates in the update function as well as disabling the
button; presentation state is not a substitute for application validation.

Build with `idris2 --cg javascript --build examples/form/web.ipkg` or
`examples/form/canvas.ipkg`, then serve the repository root. For terminal,
build `examples/form/terminal.ipkg` and run `examples/form/build/exec/form-terminal`.

Enter a name of at least three characters and save. F3 or Focus name requests
browser focus again. Lock name disables editing; a focus request made while
locked is deferred until Unlock name enables the control. Terminal editing is application-defined: type, use Backspace,
Enter to save and Escape to quit. Control metadata does not intercept terminal
application shortcuts. Native focus applies to DOM/Canvas overlay controls.
