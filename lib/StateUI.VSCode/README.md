# StateUI

Build, run and debug [StateUI](https://github.com/idexus/StateUI) applications
from VS Code: choose a host once, and the editor, **StateUI: Debug** and
**StateUI: Release** all work as that host.

## Installing

From a StateUI checkout, with Node.js 20 or newer:

```bash
cd lib/StateUI.VSCode
npm ci
npm run package
code --install-extension stateui-*.vsix
```

`npm run package` compiles the extension, copies in the template it carries,
and writes `stateui-<version>.vsix`. **Extensions: Install from VSIX…** installs
that file without the `code` command.

## A new application

- **StateUI: New Application in apps/** - in a StateUI checkout, asks for a
  name and runs the checkout's own scaffolder, `.scripts/new-app.sh` (or
  `new-app.ps1` on Windows). The application is then chosen, so **StateUI:
  Debug** runs it.
- **StateUI: New Application from Template** - an application in a directory
  of its own. It asks where, for the name, and what StateUI it is built
  against:
  - **a StateUI checkout** - both halves by path, from the checkout's own
    template, so the application matches the library on disk. On macOS it
    also offers an AppKit head. The checkout's directory is named `StateUI`:
    SwiftPM names a package on disk after its directory.
  - **a release** - `StateUI.Maui` from NuGet and the Swift half by the
    repository's tag of the same version. Only a version with both is offered.

The application is written by this extension from the StateUIStarter template
- a checkout's, or the copy the extension carries - and is what `dotnet new
stateui-maui` writes with the same options. Nothing needs to be installed
first, and no template package of another release is picked up.

A name is letters and digits, starting with a letter: it becomes the
directory, the MAUI project, the process and the Swift module (`<Name>UI`).

## The host

The status bar shows the host - **AppKit** or **.NET MAUI**. Click it, or run
**StateUI: Select Host**. AppKit is offered on macOS alone; on Windows and Linux
the host is .NET MAUI.

- **The editor works as that host.** Code under `#if APPKIT` is compiled and
  completed while AppKit is chosen, and an application's `Platforms/AppKit`
  head belongs to its package only then. Switching restarts the Swift language
  server; the window does not reload and no settings file is written.
- **StateUI: Debug and StateUI: Release run on it.** On AppKit the application's
  head is built - with its bundling script where it has one, with SwiftPM
  otherwise - and started under `lldb-dap`. On .NET MAUI the debugger chosen
  below decides the launch; with C# on macOS and Windows it is the MAUI
  extension's launch of the chosen application, on the device that extension's
  picker chose.

## The application

A second status bar item shows the application **StateUI: Debug** and
**StateUI: Release** run - click it, or run **StateUI: Select Application**.
It is remembered for the workspace, so a launch asks only when nothing is
chosen yet, or when the chosen application has no head for the host. A launch
configuration naming `"application": "Gallery"` runs that one instead.

## The debugger

For a .NET MAUI head, **StateUI: Select Debugger** chooses how it is debugged,
and the host item in the status bar shows the choice:

| Debugger | What a launch does | On |
| --- | --- | --- |
| C# | the MAUI extension's launch, on the device its picker chose | macOS, Windows |
| C# | `dotnet build`, then `coreclr` on the Linux head | Linux |
| Swift · iOS Simulator | `run-app.sh ios`, then lldb-dap attaches | macOS |
| Swift · Mac Catalyst | `run-app.sh maccatalyst`, then lldb-dap attaches | macOS |
| C# + Swift · Mac Catalyst | the C# launch, and lldb-dap attaches beside it once the app runs | macOS |
| Swift | `run-app.ps1`, then lldb-dap attaches | Windows |
| Swift | `dotnet build`, then lldb-dap launches the head | Linux |

`run-app.sh` and `run-app.ps1` are part of the StateUI build the application's
project imports - a checkout's `.scripts/Maui`, or the StateUI.Maui package's
`buildTransitive/Maui` - found by asking MSBuild for the launched framework, so
they always belong to the library the application builds.

C# on iOS, Android and Mac Catalyst needs the MAUI extension's debugger: those
heads run on Mono. Swift attaches only to a process this machine runs, and on the
iOS Simulator only after the app has started, because the simulator's watchdog
kills an app a debugger holds stopped.

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
