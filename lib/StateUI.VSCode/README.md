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
directory, the process, the package identifier and the Swift module
(`<Name>UI`).

## The host

The status bar shows the host - **AppKit**, **Android**, **WinUI** or **GTK**.
Click it, or run **StateUI: Select Host**. AppKit and Android are offered on
macOS, Android where an application has an Android head (`Platforms/Android`);
WinUI on Windows; GTK on Linux. On a machine that runs no host the status bar
says **no host**, a launch says why it runs nothing, and the editor and
**StateUI: Run Tests** work as plain Swift.

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
  otherwise - and started under `lldb-dap`. On Android
  `.scripts/Android/run-app.sh` builds the head, installs it on the device
  chosen below and starts it, and its terminal then follows the application's
  log, in colour, until the task is stopped. StateUI:
  Debug then attaches `lldb-dap` to the application through the NDK's
  `lldb-server`, which the script starts in the application's sandbox: a
  breakpoint is reached from the moment it attaches. StateUI: Release, and Run
  Without Debugging, run it without a debugger. A second launch stops the first
  one's log before it starts again. On WinUI `.scripts/WinUI/run-app.ps1`
  builds the head, lays the Windows App SDK beside it and starts it, its
  terminal passing on what the application writes; no debugger attaches yet.
  On GTK `.scripts/GTK/run-app.sh` builds the head, stopping a running copy
  first, and `lldb-dap` starts it: a breakpoint holds from the first line.

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

## Tests

**StateUI: Run Tests** offers the workspace's suites, every one ticked, and runs
them AS THE HOST, one after another, each in a terminal of its own:

- **AppKit**: the library, `lib/StateUI.AppKit`, and each application as an
  AppKit build (`STATEUI_APPKIT=1`, on `.build-appkit`).
- **Android**: the library and each application as plain Swift - an Android
  build runs only on a device - and the Android host's own tests,
  `lib/StateUI.Android/Tests`, built into a test APK and run on the device
  chosen by `.scripts/Android/test-android.sh`.
- **WinUI**: the library and each application as plain Swift, and the WinUI
  host's own package, `lib/StateUI.WinUI`, by `.scripts/WinUI/test-winui.ps1`,
  which lays the Windows App SDK beside its test runner first.
- **GTK**: the library and each application as plain Swift, and the GTK host's
  own package, `lib/StateUI.GTK`, by `swift test`, its windows on the
  desktop's display.
- **No host**: the library and each application as plain Swift.

A failure does not stop the suites after it; the summary names the ones that
failed.

## The index

The Swift language server indexes each application in a directory of the host's
own, `.build-appkit/index-build`, `.build-android/index-build`,
`.build-winui/index-build` or `.build-gtk/index-build` - with no
host SwiftPM's own `.build/index-build` - set in the application's
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
- For Android: macOS and a StateUI checkout, whose `.scripts/Android` builds
  and runs the head; Swift 6.4 from swift.org with the
  [Swift SDK for Android](https://www.swift.org/documentation/articles/swift-sdk-for-android-getting-started.html)
  of the same release; the Android NDK r30 or newer; JDK 21; and the Android
  SDK, in `ANDROID_HOME` or `~/Library/Android/sdk`. The scripts fetch Gradle
  themselves.
- For WinUI: Windows and a StateUI checkout, whose `.scripts/WinUI` builds and
  runs the head; Swift 6.4 from swift.org; Visual Studio's C++ tools and the
  Windows SDK. The scripts fetch C++/WinRT and the Windows App SDK themselves.
- For GTK: Linux and a StateUI checkout, whose `.scripts/GTK` builds the head;
  Swift 6.4 from swift.org; GTK 4.14 and libadwaita 1.5 or newer with their
  headers (`libgtk-4-dev`, `libadwaita-1-dev` on Ubuntu); and the `lldb-dap`
  extension.

Do not set `STATEUI_APPKIT`, `STATEUI_ANDROID` or `STATEUI_WINUI` in
`swift.swiftEnvironmentVariables`: that setting is laid over the host chosen
here, and the extension offers to remove it.
