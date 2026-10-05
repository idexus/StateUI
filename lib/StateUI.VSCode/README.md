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
code --install-extension ../../artifacts/stateui-*.vsix
```

`npm run package` compiles the extension and writes `stateui-<version>.vsix` into
`artifacts/` at the repository root.
**Extensions: Install from VSIX…** installs that file without the `code`
command.

## A new application

**StateUI: New Application in apps/** - in a StateUI checkout or a project
group, asks for a name and runs the scaffolder of the checkout the folder's
applications build with, `.scripts/new-app.sh` (or `new-app.ps1` on Windows),
which makes HelloWorld under that name - its example test in `Tests/`
included, which **StateUI: Run Tests** runs. The application is then chosen,
so **StateUI: Debug** runs it.

A name is letters and digits, starting with a letter: it becomes the
directory, the process, the package identifier and the Swift module
(`<Name>UI`).

## A project group

**StateUI: New Project Group** makes a folder of applications outside a
checkout. It asks where to make the group and its name, which StateUI its
applications build with, and the name of its first application:

- **A release from GitHub** - a release tag, `stateui.minimumRelease` or
  newer, cloned into the group's `StateUI/`.
- **The local checkout** - the StateUI checkout open in the workspace, else
  the one `stateui.checkout` names, else asked for.

The group holds `apps/`, a `.gitignore`, and `.vscode/` with **StateUI: Debug**
and **StateUI: Release**. Its applications are HelloWorld renamed, and each
one's `Package.swift` names its StateUI by path: `../../StateUI` for a release,
the path from the application to the checkout for a local one. That path is how
the extension finds the scripts that build and run the application's heads, in
that StateUI's `.scripts/`; the group copies none of them.

`StateUI/` is left out of git. A clone of the group gets it back with the
command its `.gitignore` names:

```bash
git clone --depth 1 --branch <release> https://github.com/idexus/StateUI.git StateUI
```

| Setting | What it holds |
| --- | --- |
| `stateui.checkout` | the local checkout a group builds with - set on this machine, so it is not asked for |
| `stateui.minimumRelease` | the oldest release offered, `0.5.0` - the first that builds into `.build/<host>` and reads `STATEUI_HOST`, as the extension does; until it is published, a group builds with the local checkout |

## The host

The status bar shows the host - **AppKit**, **UIKit**, **Android**, **WinUI**,
**GTK** or **Web**. Click it, or run **StateUI: Select Host**. AppKit, UIKit and Android are
offered on macOS, UIKit and Android where an application has their head
(`Platforms/UIKit`, `Platforms/Android`); WinUI on Windows; GTK on Linux; the
Web on macOS and Linux, where an application has its head (`Platforms/Web`). On a machine that runs no host the status bar
says **no host**, a launch says why it runs nothing, and the editor and
**StateUI: Run Tests** work as plain Swift.

- **The editor works as that host.** Code under `#if APPKIT` is compiled and
  completed while AppKit is chosen, and an application's `Platforms/AppKit`
  head belongs to its package only then. Switching restarts the Swift language
  server; the window does not reload. From the editor's next start the Swift
  extension loads no other host's packages - `lib/StateUI/StateUI.<Host>` and
  `lib/Backends/*.<Host>`, set in the user's `swift.excludePathsFromActivation`
  - so it starts sooner. As
  Android the server compiles for Android - the Swift SDK for Android of the
  toolchain's release, `aarch64-unknown-linux-android28` - so code under
  `#if ANDROID` and `Platforms/Android/Swift` resolve. With no such SDK
  installed it compiles for this Mac, and a warning says so. As the Web it
  compiles for WebAssembly - the Swift SDK for WebAssembly of the toolchain's
  release, `wasm32-unknown-wasip1` - so code under `#if WEB` and
  `Platforms/Web` resolve. As UIKit it
  compiles for the iOS simulator - `arm64-apple-ios26.0-simulator` against
  Xcode's simulator SDK - so code under `#if UIKIT` and `Platforms/UIKit`
  resolve.
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
  one's log before it starts again. On UIKit `.scripts/UIKit/run-app.sh`
  builds the head, installs it on the iPhone, iPad or simulator chosen below -
  a simulator booted first, a device's build signed for it - and starts it, and
  its terminal follows what the application prints. StateUI: Debug starts it
  held until `lldb-dap` attaches - to a simulator's process, one of this Mac's,
  or through the device - and a breakpoint holds from the first line. On WinUI `.scripts/WinUI/run-app.ps1`
  builds the head, stopping a running copy first, and lays the Windows App SDK
  beside it, and `lldb-dap` starts it: a breakpoint holds from the first line.
  On GTK `.scripts/GTK/run-app.sh` builds the head, stopping a running copy
  first, and `lldb-dap` starts it: a breakpoint holds from the first line.
  On the Web `.scripts/Web/run-app.sh` builds the head, lays its page out and
  serves it, in a task whose terminal follows the server; a second launch
  stops the first one's server. StateUI: Debug in Chrome, Edge or another of
  Chromium's browsers then starts the browser chosen below on the page under
  VS Code's own JavaScript debugger: the page's console is in the Debug
  Console. Any other browser, and StateUI: Release, the script opens itself.

## The Android device

While the host is Android, a third status bar item shows the device - click it,
or run **StateUI: Select Android Device**. It offers the devices attached and
the emulators set up; picking an emulator starts it and waits until it has
booted. The device is remembered for the workspace, so a launch or a run of the
tests asks only when none is chosen or the one chosen is no longer attached.

## The UIKit device

While the host is UIKit, the third status bar item shows the iPhone or iPad a
launch runs on - click it, or run **StateUI: Select UIKit Device**. It offers
the devices paired with this Mac, over USB or Wi-Fi, and the simulators, each
of iOS 26 or later, the newest runtime first. It is remembered for the
workspace, so a launch or a run of the tests asks only when none is chosen or
the one chosen is gone. A device runs with Developer Mode on, and its build is
signed with a development profile of this Mac's that provisions it - Xcode
makes one for a team once the device is added. The host's own tests run on a
simulator.

## The browser

While the host is the Web, the third status bar item shows the browser a
launch opens the page in - click it, or run **StateUI: Select Browser**. It
offers the browsers installed on this machine - what the system opens both a
web address and a web page with - the system's own first. It is remembered
for the workspace, so a launch asks only when none is chosen or the one
chosen is no longer installed.

## The application

A second status bar item shows the application **StateUI: Debug** and
**StateUI: Release** run - click it, or run **StateUI: Select Application**.
It is remembered for the workspace, so a launch asks only when nothing is
chosen yet, or when the chosen application has no head for the host. A launch
configuration naming `"application": "Gallery"` runs that one instead.

## Tests

**StateUI: Run Tests** offers the workspace's suites, every one ticked, and runs
them AS THE HOST, one after another, each in a terminal of its own:

- **AppKit**: the library, `lib/StateUI/StateUI.AppKit`, and each application as an
  AppKit build (`STATEUI_HOST=appkit`, on `.build/appkit`).
- **UIKit**: the library and each application as plain Swift, and the UIKit
  host's own tests, `lib/StateUI/StateUI.UIKit/Tests` - an application of tests - run
  on the simulator chosen by `.scripts/UIKit/test-uikit.sh`.
- **Android**: the library and each application as plain Swift - an Android
  build runs only on a device - and the Android host's own tests,
  `lib/StateUI/StateUI.Android/Tests`, built into a test APK and run on the device
  chosen by `.scripts/Android/test-android.sh`.
- **WinUI**: the library and each application as plain Swift, and the WinUI
  host's own tests, `lib/StateUI/StateUI.WinUI/Testing`, by `.scripts/WinUI/test-winui.ps1`,
  which lays the Windows App SDK beside its test runner first.
- **GTK**: the library and each application as plain Swift, and the GTK host's
  own tests, `lib/StateUI/StateUI.GTK/Testing`, by `swift test`, its windows on the
  desktop's display.
- **Web**: the library and each application as plain Swift, and the Web host's
  own tests, `lib/StateUI/StateUI.Web/Testing`, by `.scripts/Web/test-web.sh`,
  which compiles them for WebAssembly and runs them in Node.
- **No host**: the library and each application as plain Swift.

A failure does not stop the suites after it; the summary names the ones that
failed.

## Deploy

**StateUI: Deploy** builds the chosen application for release on the chosen
host and lays it in `artifacts/<application>/<platform>` of the folder that
keeps its `apps/` - a project group's, or a checkout's - made anew each time.
The host's own `deploy` script of the application's checkout does it:

- **WinUI**: a folder that runs on a Windows machine with nothing installed -
  the head, StateUI, the Windows App SDK, the Swift and C++ runtimes of its
  architecture, the pictures. Deploy asks which architecture: on an ARM64
  machine arm64 or x64, which Windows runs emulated, into
  `artifacts/<application>/WinUI/arm64` or `.../x64`; an x64 machine builds x64
  without asking.
- **GTK**: the head, the StateUI libraries it links and the pictures.
- **AppKit**: the application bundle where the checkout bundles the
  application, else the head and the StateUI libraries it links.
- **UIKit**: the application bundle, for the simulator or device chosen.
- **Android**: the APK, for the ABI of the device chosen.
- **Web**: the page - `index.html`, the relay, the module and the pictures -
  a folder any web server serves as it is.

## The conformance marks

In a StateUI checkout, **StateUI: Conformance - Rebuild all** runs every
conformance family as the host chosen, writing its verdicts into
`lib/StateUI/exports/marks/<host>`, then renders the control dictionary and
`docs/platform-contract.md` from them again. **StateUI: Conformance - Rebuild
changed** does the same for the families whose verdicts stand at another
revision than `lib/StateUI/StateUI.Conformance/revisions.txt` says, or have none;
every other family's run ends at once. UIKit runs on the simulator chosen and Android on
the device chosen, where Android rebuilds all only, its device reading no
repository. Neither command shows outside a checkout: an application's
workspace holds no marks.

## The index

The Swift language server indexes each application in a directory of the host's
own, `.build/appkit/index-build`, `.build/uikit/index-build`, `.build/android/index-build`,
`.build/winui/index-build`, `.build/gtk/index-build` or `.build/web/index-build` - with no
host SwiftPM's own `.build/index-build` - set in the application's
`.sourcekit-lsp/config.json`. **StateUI: Clean Index** removes
them and restarts the server, for an index a failed build left inconsistent.

## The toolchain

**StateUI: Check Toolchain** looks for what this machine needs to build and run
the hosts it runs, as [Requirements](#requirements) and the handbook's host pages
say - Swift 6.4; Xcode 27, an iOS simulator runtime and the Android SDK, NDK,
JDK and Swift SDK on macOS; Visual Studio's C++ tools, the Windows SDK and the
WebView2 runtime on Windows; GTK, libadwaita, WebKitGTK, gdk-pixbuf's SVG
loader and a desktop session on Linux; the Swift SDK for WebAssembly and Python 3 for the Web on macOS and
Linux; `lldb-dap` and the LLDB DAP extension for a Debug launch - on Linux
and Windows an `lldb-dap` that starts with the Python its LLDB loads; Git for a project group's
releases; and Node.js for this extension's own build. The **StateUI Toolchain** output lists each
with what was found - a version older than the one required marked as too old - and
for each not found what to install. It looks where the build scripts look
(the NDK as `build-swift.sh` finds it); it installs nothing.

## The extension itself

In a StateUI checkout, **StateUI: Reinstall VS Code Extension** builds the
extension from `lib/StateUI.VSCode` - compiled and packed into
`artifacts/stateui-<version>.vsix` by `npm run package` - and installs it with
`--force` through the command line of the VS Code that runs it, then offers to
reload the window, where the new build runs.

## Launches

Add them to `.vscode/launch.json`, or pick them from Run and Debug with no
launch file at all:

```json
{ "name": "StateUI: Debug", "type": "stateui", "request": "launch", "configuration": "debug" },
{ "name": "StateUI: Release", "type": "stateui", "request": "launch", "configuration": "release" }
```

## Requirements

- The [Swift extension](https://marketplace.visualstudio.com/items?itemName=swiftlang.swift-vscode),
  installed with StateUI.
- For AppKit: macOS 26 or newer and the `lldb-dap` extension.
- For UIKit: macOS with Xcode, a StateUI checkout, whose `.scripts/UIKit`
  builds and runs the head, the `lldb-dap` extension, and an iOS 26 or newer
  simulator or device - a device with Developer Mode on and a development
  profile of this Mac's that provisions it.
- For Android: macOS and a StateUI checkout, whose `.scripts/Android` builds
  and runs the head; Swift 6.4 from swift.org with the
  [Swift SDK for Android](https://www.swift.org/documentation/articles/swift-sdk-for-android-getting-started.html)
  of the same release; the Android NDK r30 or newer; JDK 21; and the Android
  SDK with platform 36 and its build tools, in `ANDROID_HOME` or
  `~/Library/Android/sdk`. The scripts fetch Gradle themselves.
- For WinUI: Windows and a StateUI checkout, whose `.scripts/WinUI` builds the
  head; Swift 6.4 from swift.org; Visual Studio's C++ tools and the Windows
  SDK; the WebView2 runtime for the web view's backend (Windows 11 has it);
  and the `lldb-dap` extension, with the toolchain's `lldb-dap`, which loads
  the Python the Swift installer lays beside the toolchain (Check Toolchain
  asks it, `lldb-dap --check-python`). The scripts fetch C++/WinRT and the
  Windows App SDK themselves.
- For the Web: macOS or Linux and a StateUI checkout, whose `.scripts/Web`
  builds, serves and opens the head; Swift 6.4 and the Swift SDK for
  WebAssembly of the same release (`swift sdk install`,
  [Getting started with WebAssembly](https://www.swift.org/documentation/articles/wasm-getting-started.html));
  Python 3, which serves the page; and a browser - Chrome, Edge or another of
  Chromium's for StateUI: Debug to follow the page in VS Code's debugger.
- For a project group's releases: Git, which lists and clones them.
- For GTK: Linux and a StateUI checkout, whose `.scripts/GTK` builds the head;
  Swift 6.4 from swift.org; GTK 4.14 and libadwaita 1.5 or newer with their
  headers (`libgtk-4-dev`, `libadwaita-1-dev` on Ubuntu); WebKitGTK 6.0 with
  its headers for the web view's backend and the host's tests
  (`libwebkitgtk-6.0-dev` on Ubuntu, `webkitgtk-6.0` on Arch); gdk-pixbuf's SVG
  loader (`librsvg2-common`, or glycin's loaders where gdk-pixbuf 2.44 and
  newer read through glycin, as on Arch); and the `lldb-dap` extension, with
  a toolchain `lldb-dap` that starts - on a distribution other than the one
  the toolchain was built for, its Python library installed (Check
  Toolchain names the one missing, and F5 stops before the build).

Do not set `STATEUI_HOST` in `swift.swiftEnvironmentVariables`: that setting
is laid over the host chosen here, and the extension offers to remove it.
