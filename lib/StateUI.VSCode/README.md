# StateUI

Build, run and debug [StateUI](https://github.com/idexus/StateUI) applications
from VS Code: choose a host once, and the editor, **StateUI: Debug** and
**StateUI: Release** all work as that host.

## The host

The status bar shows the host - **AppKit** or **.NET MAUI**. Click it, or run
**StateUI: Select Host**.

- **The editor works as that host.** Code under `#if APPKIT` is compiled and
  completed while AppKit is chosen, and an application's `Platforms/AppKit`
  head belongs to its package only then. Switching restarts the Swift language
  server; the window does not reload and no settings file is written.
- **StateUI: Debug and StateUI: Release run on it.** On AppKit the application's
  head is built - with its bundling script where it has one, with SwiftPM
  otherwise - and started under `lldb-dap`. On .NET MAUI the launch is the MAUI
  extension's: its startup-project and device pickers choose what runs.

Where a workspace holds several applications with an AppKit head, a second
status bar item chooses which one runs.

## Launches

Add them to `.vscode/launch.json`, or pick them from Run and Debug with no
launch file at all:

```json
{ "name": "StateUI: Debug", "type": "stateui", "request": "launch", "configuration": "debug" },
{ "name": "StateUI: Release", "type": "stateui", "request": "launch", "configuration": "release" }
```

## Requirements

- The [Swift extension](https://marketplace.visualstudio.com/items?itemName=swiftlang.swift-vscode).
- For AppKit: macOS 14 or newer and the `lldb-dap` extension.
- For .NET MAUI: the .NET MAUI extension and the .NET 10 SDK.

Do not set `STATEUI_APPKIT` in `swift.swiftEnvironmentVariables`: that setting
is laid over the host chosen here, and the extension offers to remove it.
