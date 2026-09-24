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

`npm run package` compiles the extension and writes `stateui-<version>.vsix`.
**Extensions: Install from VSIX…** installs that file without the `code`
command.

## A new application

**StateUI: New Application in apps/** - in a StateUI checkout, asks for a name
and runs the checkout's own scaffolder, `.scripts/new-app.sh` (or
`new-app.ps1` on Windows), which makes HelloWorld under that name. The
application is then chosen, so **StateUI: Debug** runs it.

A name is letters and digits, starting with a letter: it becomes the
directory, the MAUI project, the process and the Swift module (`<Name>UI`).

## The host

The status bar shows the host - **AppKit**, **.NET MAUI** or **Android**. Click
it, or run **StateUI: Select Host**. AppKit and Android are offered on macOS
alone, Android where an application has an Android head (`Platforms/Android`);
on Windows and Linux the host is .NET MAUI.

- **The editor works as that host.** Code under `#if APPKIT` is compiled and
  completed while AppKit is chosen, and an application's `Platforms/AppKit`
  head belongs to its package only then. Switching restarts the Swift language
  server; the window does not reload and no settings file is written. As
  Android the server compiles for Android - the Swift SDK for Android of the
  toolchain's release, `aarch64-unknown-linux-android28` - so code under
  `#if ANDROID` and `Platforms/Android/Swift` resolve. With no such SDK
  installed it compiles for this Mac, and a warning says so.
- **StateUI: Debug and StateUI: Release run on it.** On AppKit the application's
  head is built - with its bundling script where it has one, with SwiftPM
  otherwise - and started under `lldb-dap`. On .NET MAUI the debugger chosen
  below decides the launch; with C# on macOS and Windows it is the MAUI
  extension's launch of the chosen application, on the device that extension's
  picker chose. On Android `.scripts/Android/run-app.sh` builds the head,
  installs it on the device chosen below and starts it, and its terminal then
  follows the application's log, in colour, until the task is stopped. StateUI:
  Debug then attaches `lldb-dap` to the application through the NDK's
  `lldb-server`, which the script starts in the application's sandbox: a
  breakpoint is reached from the moment it attaches. StateUI: Release, and Run
  Without Debugging, run it without a debugger. A second launch stops the first
  one's log before it starts again.

## The Android device

While the host is Android, a third status bar item shows the device - click it,
or run **StateUI: Select Android Device**. It offers the devices attached and
the emulators set up; picking an emulator starts it and waits until it has
booted. The device is remembered for the workspace, so a launch or a run of the
tests asks only when none is chosen or the one chosen is no longer attached.

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
- **Android**: the library and each application as plain Swift - an Android
  build runs only on a device - and the Android host's own tests,
  `lib/StateUI.Android/Tests`, built into a test APK and run on the device
  chosen by `.scripts/Android/test-android.sh`.

A failure does not stop the suites after it; the summary names the ones that
failed.

## The index

The Swift language server indexes each application in a directory of the host's
own, `.build-appkit/index-build`, `.build-maui/index-build` or
`.build-android/index-build`, set in the application's
`.sourcekit-lsp/config.json`. **StateUI: Clean Index** removes
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
- For AppKit: macOS 26 or newer and the `lldb-dap` extension.
- For .NET MAUI: the .NET MAUI extension and the .NET 10 SDK.
- For Android: macOS and a StateUI checkout, whose `.scripts/Android` builds
  and runs the head; Swift 6.4 from swift.org with the
  [Swift SDK for Android](https://www.swift.org/documentation/articles/swift-sdk-for-android-getting-started.html)
  of the same release; the Android NDK r30 or newer; JDK 21; and the Android
  SDK, in `ANDROID_HOME` or `~/Library/Android/sdk`. The scripts fetch Gradle
  themselves.

Do not set `STATEUI_APPKIT` or `STATEUI_ANDROID` in
`swift.swiftEnvironmentVariables`: that setting is laid over the host chosen
here, and the extension offers to remove it.
