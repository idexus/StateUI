# StateUI for VS Code

VS Code is where StateUI applications are built, run, debugged, and tested.
The StateUI extension, whose sources stand in `editors/VSCode`, chooses the
host and the application once, and everything after that - the editor's
completion, the launches, and the suites - works as that host.

## Installing

The extension works through the `stateui` tool, built from a StateUI
checkout and put on the search path, or unpacked from its distribution
([The tool](../../development.md#the-tool)). Where it stands elsewhere, the
`stateui.cliPath` setting names the program. A tool of another API than the
extension's is refused with the version each speaks; what the tool says of
itself shows in the **StateUI Tool** output.

The tool then builds the extension, with Node.js 20 or newer, and installs it:

```bash
stateui repo integration install --editor vscode
```

It packages `editors/VSCode` into `artifacts/stateui-<version>.vsix` at the
repository root - by its own `npm ci` and `npm run package` - and has VS Code's
`code` install it, then finds it among VS Code's extensions at that version.
`--editor-path` names VS Code's command line where `code` is not on the
path; **Extensions: Install from VSIX…** in the Command Palette installs the
file by hand. After pulling changes to the extension,
[**StateUI: Reinstall VS Code Extension**](#the-extension-itself) does it again.

The extension installs the **Swift** extension (swiftlang) with it. Install
**LLDB DAP** for the Swift debugger.

## Running an application

Open the repository folder. The status bar shows two StateUI items: the
[host](#the-host) the editor and the launches work as, and the
[application](#the-application) they run. While the host is UIKit, Android or
the Web a third item shows the device: an iPhone, an iPad or a simulator for
UIKit; an attached phone or an emulator, started when it is picked, for
Android; the browser the page opens in, for the Web.

Press **F5** to run **StateUI: Debug**, or choose **StateUI: Release** in Run
and Debug. The application's head is built, installed where the host needs
it, and started under `lldb-dap`, a breakpoint holding from the first line -
on Android `lldb-dap` attaches once the application has started, and a
breakpoint holds from then on; on UIKit and Android **StateUI Run** follows the
application's output, and the notification that follows it stops it. On UIKit, Android and the Web a Release launch runs
without a debugger; on AppKit, WinUI and GTK `lldb-dap` starts the optimized
build. A Web head is built, its page served and opened in the chosen browser;
StateUI: Debug in Chrome, Edge or another of Chromium's browsers opens it
under VS Code's own JavaScript debugger, the page's console in the Debug
Console.

`.vscode/launch.json` holds only those two [launches](#launches). The
extension resolves each one into the chosen host's own debugger. Every launch
has a command-line equivalent:
[From the command line](../../getting-started.md#from-the-command-line).

## Commands

The Command Palette offers the rest under **StateUI:**

| Command | What it does |
| --- | --- |
| [Select Host](#the-host) | the host the editor and the launches work as, as the status bar item does |
| [Select UIKit Device](#the-uikit-device) | the iPhone, iPad or simulator a UIKit head runs on |
| [Select Android Device](#the-android-device) | the device or emulator an Android head runs on |
| [Select Browser](#the-browser) | the browser a Web head's page opens in |
| [Select Application](#the-application) | the application F5 runs |
| [Run Tests](#tests) | the workspace's suites, run as the chosen host |
| [Package](#package) | the chosen application built for release and laid, with what it runs with, in `artifacts/<application>/<platform>` of its workspace - on WinUI per architecture |
| [Conformance - Rebuild all / changed](#the-conformance-marks) | the chosen host's marks run again - every family, or the stale ones - and the documents rendered |
| [New Application](#a-new-application) | a new application in a workspace, beside its applications, made by the `stateui` tool |
| [New Project Group](#a-project-group) | a workspace of applications outside the checkout |
| [Clean Index](#the-index) | removes the language server's index and builds it again |
| [Check Toolchain](#the-toolchain) | what this machine has of what its hosts need, and what to install for the rest |
| [Reinstall VS Code Extension](#the-extension-itself) | packs the extension from the checkout and installs it again |

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
  compiles for the iOS simulator - `arm64-apple-ios26.4-simulator` against
  Xcode's simulator SDK - so code under `#if UIKIT` and `Platforms/UIKit`
  resolve.
- **StateUI: Debug and StateUI: Release run on it.** On AppKit the `stateui`
  tool builds the application's bundle - its progress in a notification that
  cancels it, SwiftPM's words in the **StateUI Build** output - and its
  program is started under `lldb-dap`. On Android the `stateui` tool builds
  the APK for the device chosen below - an emulator not running booted first
  - installs it and starts it; **StateUI Run** follows the application's log,
  and the notification that follows it stops it. StateUI: Debug readies the
  NDK's `lldb-server` in the application's sandbox and attaches `lldb-dap`
  through it: a breakpoint is reached from the moment it attaches, and ending
  the session ends the application. StateUI: Release, and Run Without
  Debugging, run it without a debugger. On UIKit the `stateui` tool builds the
  head, installs it on the iPhone, iPad or simulator chosen below - a
  simulator booted first, a device's build signed for it - and starts it;
  **StateUI Run** follows what the application prints, and the notification
  that follows it stops it. StateUI: Debug starts it held until `lldb-dap`
  attaches - to a simulator's process, one of this Mac's, or through the
  device - and a breakpoint holds from the first line; ending the session
  ends the application. On WinUI the `stateui` tool builds the head, stopping
  a running copy first, and lays the Windows App SDK beside it, and `lldb-dap`
  starts it: a breakpoint holds from the first line.
  On GTK the `stateui` tool builds the head and installs it for the user, a
  running copy is stopped, and `lldb-dap` starts it: a breakpoint holds from
  the first line.
  On the Web the `stateui` tool builds the head, lays its page out and serves
  it; **StateUI Run** follows the server, the notification that follows it
  stops it, and a second launch stops the first one's server. StateUI: Debug
  in Chrome, Edge or another of Chromium's browsers then starts the browser
  chosen below on the page under VS Code's own JavaScript debugger: the page's
  console is in the Debug Console, and ending the session stops the server.
  Any other browser, and StateUI: Release, the tool opens itself.

## The Android device

While the host is Android, a third status bar item shows the device - click it,
or run **StateUI: Select Android Device**. It offers the devices attached and
the emulators set up, as the `stateui` tool lists them; an emulator picked that
is not running is started when a launch or the tests need it. The device is
remembered for the workspace, so a launch or a run of the tests asks only when
none is chosen or the one chosen is no longer listed.

## The UIKit device

While the host is UIKit, the third status bar item shows the iPhone or iPad a
launch runs on - click it, or run **StateUI: Select UIKit Device**. It offers
the devices paired with this Mac, over USB or Wi-Fi, and the simulators, each
of iOS 26.4 or later, the newest runtime first. It is remembered for the
workspace, so a launch asks only when none is chosen or the one chosen is
gone. A device runs with Developer Mode on, and its build is signed with a
development profile of this Mac's that provisions it - Xcode makes one for a
team once the device is added. The host's own suites run on a simulator: the
one chosen where it is one, else one asked for among the simulators alone and
remembered for suites, while a launch keeps the iPhone or iPad chosen.

## The browser

While the host is the Web, the third status bar item shows the browser a
launch opens the page in - click it, or run **StateUI: Select Browser**. It
offers the browsers installed on this machine - what the system opens both a
web address and a web page with - the system's own first, as the `stateui`
tool lists them. It is remembered
for the workspace, so a launch asks only when none is chosen or the one
chosen is no longer installed.

## The application

A second status bar item shows the application **StateUI: Debug** and
**StateUI: Release** run - click it, or run **StateUI: Select Application**.
It is remembered for the workspace, so a launch asks only when nothing is
chosen yet, or when the chosen application has no head for the host. A launch
configuration naming `"application": "Gallery"` runs that one instead.

## A new application

The extension finds applications through the `stateui` tool: in a folder that
is an application - one holding its `stateui.json` - that one; else the ones
its workspace lists - the nearest `stateui-workspace.json` up from the folder,
which names the applications and the StateUI they build with. A StateUI
checkout is a workspace of its own (`apps/Gallery`, `apps/HelloWorld`), and so
is a [project group](#a-project-group). An application added, removed or
listed there is found again by itself.

**StateUI: New Application** - in a workspace, asks for a name, and the
`stateui` tool makes HelloWorld under that name beside the workspace's
applications - at its root where it lists none yet - building with the StateUI
its `stateui-workspace.json` names, and lists it there. Its `stateui.json`
names it `com.example.<name>` until it is given its own identifier. Its example
test in `Tests/` comes with it, which **StateUI: Run Tests** runs. A notification
follows the making and cancels it. The application is then chosen, so
**StateUI: Debug** runs it.

A name is letters and digits, starting with a letter: it becomes the
directory, the process, the package identifier and the Swift module
(`<Name>UI`). The tool checks it as it is typed.

## A project group

An application outside the checkout lives in a project group, a workspace of
its own that **StateUI: New Project Group** has the `stateui` tool make. It
asks where to make the group and its name, which StateUI its applications
build with, and the name of its first application:

- **A release from GitHub** - a release tag, `stateui.minimumRelease` or
  newer, cloned into the group's `StateUI/`.
- **The local checkout** - the StateUI checkout open in the workspace, else
  the one `stateui.checkout` names, else asked for.

```text
MyApps/
  stateui-workspace.json  the applications, and the StateUI they build with
  .gitignore
  .vscode/                StateUI: Debug and StateUI: Release
  StateUI/                the release, left out of git; absent with a local checkout
  Notes/                  HelloWorld renamed; its Package.swift names ../StateUI
```

Its applications are HelloWorld renamed, and each one's `Package.swift` names
its StateUI by path: `../StateUI` for a release, the path from the
application to the checkout for a local one. The `stateui` tool builds and
runs every head from it, and the group copies nothing of it. **StateUI: New
Application** makes the next application beside it, and `stateui project
library` points every application at another StateUI.

`StateUI/` is left out of git. A clone of the group gets it back with the
command its `.gitignore` names:

```bash
stateui project library --release <release>
```

| Setting | What it holds |
| --- | --- |
| `stateui.checkout` | the local checkout a group builds with - set on this machine, so it is not asked for |
| `stateui.minimumRelease` | the oldest release offered, `0.5.0` - the first that builds into `.build/<host>` and reads `STATEUI_HOST`, as the extension does; until it is published, a group builds with the local checkout |

## Tests

The workspace's suites stand in the Testing view, found by the stateui tool
for the chosen host (`stateui test list --host <host>` lists the same) and
found again when the host changes. **StateUI: Run Tests** offers them, every
one ticked, and runs them AS THE HOST, one after another, each through the tool
(`stateui test run --suite <suite>`), its output in Test Results:

- **AppKit**: the library, `lib/StateUI/StateUI.AppKit`, and each application as an
  AppKit build (`STATEUI_HOST=appkit`, on `.build/appkit`).
- **UIKit**: the library and each application as plain Swift, and the UIKit
  host's own tests, `lib/StateUI/StateUI.UIKit/Tests` - an application of tests - run
  on the simulator chosen by `stateui repo test --suite host:uikit`.
- **Android**: the library and each application as plain Swift - an Android
  build runs only on a device - and the Android host's own tests,
  `lib/StateUI/StateUI.Android/Tests`, built into a test APK and run on the device
  chosen by `stateui repo test --suite host:android`.
- **WinUI**: the library and each application as plain Swift, and the WinUI
  host's own tests, `lib/StateUI/StateUI.WinUI/Testing`, by
  `stateui repo test --suite host:winui`, which lays the Windows App SDK
  beside its test runner first.
- **GTK**: the library and each application as plain Swift, and the GTK host's
  own tests, `lib/StateUI/StateUI.GTK/Testing`, by
  `stateui repo test --suite host:gtk`, its windows on the desktop's display.
- **Web**: the library and each application as plain Swift, and the Web host's
  own tests, `lib/StateUI/StateUI.Web/Testing`, by
  `stateui repo test --suite host:web`, which compiles them for WebAssembly
  and runs them in Node, then what needs a browser in Chrome.
- **No host**: the library and each application as plain Swift.

A suite that runs on a device asks for one once. A failure does not stop the
suites after it; the summary names the ones that failed.

## Package

**StateUI: Package** builds the chosen application for release on the chosen
host and lays it in `artifacts/<application>/<platform>` of its workspace - a
project group's, or a checkout's - made anew each time.
The `stateui` tool packages it:

- **WinUI**: a folder that runs on a Windows machine with nothing installed -
  the head, StateUI, the Windows App SDK, the Swift and C++ runtimes of its
  architecture, the pictures. Package asks which architecture: on an ARM64
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

In a StateUI checkout, **StateUI: Conformance - Rebuild all** has the
`stateui` tool run every conformance family as the host chosen, writing its
verdicts into `lib/StateUI/exports/marks/<host>`, then render the control
dictionary and `docs/platform-contract.md` from them again
(`stateui repo conformance run --all --record`). **StateUI: Conformance -
Rebuild changed** does the same for the families whose verdicts stand at
another revision than `lib/StateUI/StateUI.Conformance/revisions.txt` says, or
have none (`--changed`). UIKit runs on the simulator chosen and Android on the
device chosen. The run's output is in **StateUI Build**, and its end names its
phases - the one that failed, where one did. Neither command shows outside a
checkout: an application's workspace holds no marks.

## The index

The Swift language server indexes each application in a directory of the host's
own, `.build/appkit/index-build`, `.build/uikit/index-build`, `.build/android/index-build`,
`.build/winui/index-build`, `.build/gtk/index-build` or `.build/web/index-build` - with no
host SwiftPM's own `.build/index-build` - set in the application's
`.sourcekit-lsp/config.json`. **StateUI: Clean Index** removes
them and restarts the server, for an index a failed build left inconsistent.

A package is indexed as one host at a time. Where another window works on
one of this window's applications as another host, a host chosen here is
refused - the message names the application and the host it is held as -
and the host before stays; a window opening on such an application works as
that host.

## The toolchain

**StateUI: Check Toolchain** asks the `stateui` tool what this machine has of
what it needs to build and run the hosts it runs - what `stateui doctor` prints -
as [Requirements](#requirements) and the handbook's host pages say - Swift 6.4; Xcode 27, an iOS simulator runtime and the Android SDK, NDK,
JDK and Swift SDK on macOS; Visual Studio's C++ tools, the Windows SDK and the
WebView2 runtime on Windows; GTK, libadwaita, WebKitGTK, gdk-pixbuf's SVG
loader and a desktop session on Linux; the Swift SDK for WebAssembly and Python 3 for the Web on macOS and
Linux; `lldb-dap` and the LLDB DAP extension for a Debug launch - on Linux
and Windows an `lldb-dap` that starts with the Python its LLDB loads; Git for a project group's
releases; and Node.js for this extension's own build. The LLDB DAP extension
and whether the `lldb-dap` it is set to starts are the extension's own
findings, added to the tool's. The **StateUI Toolchain** output lists each
with what was found - a version older than the one required marked as too old - and
for each not found what to install. It looks where the tool's builds look
(the NDK as an Android build finds it); it installs nothing.

## The extension itself

In a StateUI checkout, **StateUI: Reinstall VS Code Extension** has the
`stateui` tool package the extension from `editors/VSCode` into
`artifacts/stateui-<version>.vsix` and install it over the running one through
the command line of the VS Code that runs it, as
`stateui repo integration install` does, then offers to reload the window,
where the new build runs.

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
- The `stateui` tool of the same release, on the search path or named by
  `stateui.cliPath` ([Installing](#installing)).
- For AppKit: macOS 26.4 or newer, `resvg` 0.50.0 (`brew install resvg`),
  which draws its icon, and the `lldb-dap` extension.
- For UIKit: macOS with Xcode, `resvg` 0.50.0, the `lldb-dap` extension, and an iOS 26.4 or
  newer simulator or device - a device with Developer Mode on and a
  development profile of this Mac's that provisions it.
- For Android: macOS; Swift 6.4 from swift.org with the
  [Swift SDK for Android](https://www.swift.org/documentation/articles/swift-sdk-for-android-getting-started.html)
  of the same release; the Android NDK r30 or newer; JDK 21; and the Android
  SDK with platform 36 and its build tools, in `ANDROID_HOME` or
  `~/Library/Android/sdk`; and `resvg` 0.50.0. The tool fetches Gradle itself.
- For WinUI: Windows; Swift 6.4 from swift.org; Visual Studio's C++ tools and
  the Windows SDK; the WebView2 runtime for the web view's backend (Windows 11 has it);
  and the `lldb-dap` extension, with the toolchain's `lldb-dap`, which loads
  the Python the Swift installer lays beside the toolchain (Check Toolchain
  asks it, `lldb-dap --check-python`). The tool fetches C++/WinRT and the
  Windows App SDK itself.
- For the Web: macOS or Linux; Swift 6.4 and the Swift SDK for WebAssembly
  of the same release (`swift sdk install`,
  [Getting started with WebAssembly](https://www.swift.org/documentation/articles/wasm-getting-started.html));
  and a browser - Chrome, Edge or another of Chromium's for StateUI: Debug to
  follow the page in VS Code's debugger. The Web host's own tests run in Node
  and in Chrome or Chromium.
- For a project group's releases: Git, which lists and clones them.
- For GTK: Linux; Swift 6.4 from swift.org; GTK 4.14 and libadwaita 1.5 or newer with their
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
