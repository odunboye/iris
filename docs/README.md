# Iris documentation

Iris is a preview UI framework for Idris 2. Share a model, update function and
widget tree across terminal, browser DOM and Canvas/WebView runners. Each runner
has its own input, layout and lifecycle behavior.

## Start here

Follow [your first app: web to Android](tutorials/web-to-android.md). It starts
from an empty directory, explains the generated entry modules, and separates
compiling an app from packaging and running it.

## Guides

- [Organize a project and add targets](guides/project-structure.md)
- [Build forms with identity, validation and focus](guides/forms.md)
- [Run effects and make a browser request](guides/effects.md)
- [Test an application and prepare a release](guides/testing-and-release.md)
- [Resolve browser and Android startup problems](troubleshooting/startup.md)

## Understand Iris

- [The application loop and effect lifetime](concepts/application-loop.md)
- [Backend capabilities](reference/capabilities.md)
- [Implemented architecture and evidence](concepts/architecture.md)
- [API stability and legacy APIs](reference/api-stability.md)

## Reference

- [Application API and module map](reference/api.md)
- [CLI commands](reference/cli.md)
- [Package and mobile configuration](reference/configuration.md)
- [Optional RPC client](../client/README.md)
- [Optional native plugin and session bindings](../mobile/README.md)

## Working examples

[Counter](../examples/counter/README.md) demonstrates three runners.
[Account form](../examples/form/README.md) demonstrates browser control metadata
and terminal input handling. [Todo](../examples/todo/README.md) is a larger app.
[Router](../examples/router/README.md) demonstrates typed routing, path/query
parameters, navigation guards and browser history.
[RPC client](../examples/client/README.md) demonstrates `iris-client`'s typed
JSON-RPC-over-HTTP calls, error decoding and bearer auth against a real
local server. [Native commands](../examples/mobile-commands/README.md)
demonstrates every `Iris.Mobile` command against a mock native bridge.

## Maintain these docs

The source lives in this repository and can be read directly on GitHub. See the
[documentation audit and maintenance plan](AUDIT.md) for coverage, known gaps,
and checks. Native-device testing is separate from portable browser acceptance.
