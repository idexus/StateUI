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

## The application

A second status bar item shows the application **StateUI: Debug** and
**StateUI: Release** run - click it, or run **StateUI: Select Application**.
It is remembered for the workspace, so a launch asks only when nothing is
chosen yet, or when the chosen application has no head for the host. A launch
configuration naming `"application": "Gallery"` runs that one instead.

## Tests

**StateUI: Run Tests** offers the workspace's suites, every one ticked, and runs
them AS THE HOST, one after another, each in a terminal of its own:

- **AppKit**: the library, `lib/StateUI.AppKit`, and each application as an
  AppKit build (`STATEUI_APPKIT=1`, on `.build-appkit`).
- **.NET MAUI**: the library and each application under `-Xswiftc -DMAUI`, on
  `.build-maui`, and the C# suites.

A failure does not stop the suites after it; the summary names the ones that
failed.

## The index

The Swift language server indexes each application in a directory of the host's
own, `.build-appkit/index-build` or `.build-maui/index-build`, set in the
application's `.sourcekit-lsp/config.json`. **StateUI: Clean Index** removes
them and restarts the server, for an index a failed build left inconsistent.

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
