# Getting started

StateUI applications keep their interface and application state in a
platform-neutral Swift module. A small native executable imports that module
and the selected host package. The same application module can therefore be
started by another host without changing its view tree.

Six hosts are active - AppKit, UIKit, Android Views, WinUI 3, GTK 4 and the
Web - each Swift, in the application's own process. The supported setup is a
StateUI checkout: each host is a sibling Swift package whose manifest uses a
local dependency on the repository root. No host has a published package route
yet, so an application outside the checkout sits in a
[project group](#a-project-group) that builds with a checkout on disk.

## Requirements

- macOS 26 or newer, with Xcode 27 and its Swift 6.4, for the AppKit host;
- a checkout of this repository;
- VS Code and Node.js 20 or newer, for the StateUI extension.

[UIKit host](hosts/uikit.md#requirements) lists what the UIKit host needs for
the iOS simulator, [Android Views host](hosts/android.md#requirements) what the
Android Views host needs as well, [WinUI host](hosts/winui.md#requirements) what the
WinUI host needs on Windows, [GTK host](hosts/gtk.md#requirements) what
the GTK host needs on Linux, and [Web host](hosts/web.md#requirements) what the
Web host needs on macOS and Linux.

With the extension installed ([Installing the extension](#installing-the-extension)),
**StateUI: Check Toolchain** in the Command Palette looks on this machine for
what these pages list for its platform's hosts, and says what to install for
whatever is missing. [Tested setups](tested-setups.md) names the versions and
devices StateUI's suites pass on.

## Working in VS Code

VS Code is where StateUI applications are built, run, debugged, and tested. The
StateUI extension in `lib/StateUI.VSCode` chooses the host and the application
once, and everything after that - the editor's completion, the launches, and
the suites - works as that host.

### Installing the extension

The extension is built from the checkout. From the repository root:

```bash
cd lib/StateUI.VSCode
npm ci
npm run package
code --install-extension ../../artifacts/stateui-*.vsix
```

`npm run package` writes `stateui-<version>.vsix` into `artifacts/` at the repository root.
Without the `code` command on the path, use **Extensions: Install from VSIX…**
in the Command Palette and pick that file. Build and install it again after
pulling changes to the extension.

The extension installs the **Swift** extension (swiftlang) with it. Install
**LLDB DAP** for the Swift debugger.

### Running an application

Open the repository folder. The status bar shows two StateUI items:

- **the host** - AppKit, UIKit or Android on macOS, WinUI on Windows, GTK on
  Linux, and the Web on macOS and Linux; UIKit, Android and the Web only for
  an application with that head. The editor
  works as that host: code under `#if APPKIT` is completed only while AppKit
  is chosen, as UIKit the language server compiles for the iOS simulator, and
  as Android for Android with the Swift SDK for Android. Switching restarts
  the Swift language server without reloading the window.
- **the application** - Gallery, HelloWorld, or any other under `apps/`. It is
  remembered for the workspace.

While the host is UIKit, Android or the Web a third item shows the device: an
iPhone, an iPad or a simulator for UIKit; an attached phone or an emulator,
started when it is picked, for Android; the browser the page opens in, for
the Web.

Press **F5** to run **StateUI: Debug**, or choose **StateUI: Release** in Run
and Debug. The application's head is built, installed where the host needs
it, and started under `lldb-dap`, a breakpoint holding from the first line -
on Android `lldb-dap` attaches once the application has started, and a
breakpoint holds from then on; on UIKit and Android its terminal follows the
application's log. On UIKit, Android and the Web a Release launch runs
without a debugger; on AppKit, WinUI and GTK `lldb-dap` starts the optimized
build. A Web head is built, its page served and opened in the chosen browser;
StateUI: Debug in Chrome, Edge or another of Chromium's browsers opens it
under VS Code's own JavaScript debugger, the page's console in the Debug
Console.

`.vscode/launch.json` holds only those two launches. The extension resolves
each one into the chosen host's own debugger.

### Commands

The Command Palette offers the rest under **StateUI:**

| Command | What it does |
| --- | --- |
| Select Host | the host the editor and the launches work as, as the status bar item does |
| Select UIKit Device | the iPhone, iPad or simulator a UIKit head runs on |
| Select Android Device | the device or emulator an Android head runs on |
| Select Browser | the browser a Web head's page opens in |
| Select Application | the application F5 runs |
| Run Tests | the workspace's suites, run as the chosen host |
| Deploy | the chosen application built for release and laid, with what it runs with, in `artifacts/<application>/<platform>` - on WinUI per architecture - beside its `apps/` |
| Conformance - Rebuild all / changed | the chosen host's marks run again - every family, or the stale ones - and the documents rendered |
| New Application in apps/ | a new application in a checkout's or a project group's `apps/`, made by `.scripts/new-app.sh` (`.scripts/new-app.ps1` on Windows) |
| New Project Group | a folder of applications outside the checkout - see [A project group](#a-project-group) |
| Clean Index | removes the language server's index and builds it again |
| Check Toolchain | what this machine has of what its hosts need, and what to install for the rest |
| Reinstall VS Code Extension | packs the extension from the checkout and installs it again |

The extension's own README, `lib/StateUI.VSCode/README.md`, describes each of
them in detail.

### From the command line

Every launch has a command-line equivalent. Build HelloWorld's AppKit head from
the repository root:

```bash
STATEUI_HOST=appkit swift build --package-path apps/HelloWorld \
  --scratch-path apps/HelloWorld/.build/appkit --product HelloWorldAppKit
```

The variable is what makes it an AppKit build: the manifest then declares the
AppKit head and defines `APPKIT`, and without it `swift test` compiles no part
of one host's half; see
[Project structure and development](development.md). Each host builds an
application in a directory of its own inside the application's `.build` -
`.build/appkit`, `.build/uikit`, `.build/android`, `.build/winui`,
`.build/gtk`, `.build/web` - beside SwiftPM's plain build, so switching hosts
rebuilds nothing. `swift package clean` empties all of them.

Run HelloWorld's Android head on a device - `.scripts/Android/devices.sh list`
names the devices:

```bash
.scripts/Android/run-app.sh apps/HelloWorld debug emulator-5554
```

Run its UIKit head on an iOS simulator, booted first where it is not - the
one named, else the one booted, else an iPhone:

```bash
.scripts/UIKit/run-app.sh apps/HelloWorld debug "iPhone 18 Pro"
```

The WinUI, GTK and Web heads have a script of their own too, under
[Build](development.md#build). So has each host's suite -
`.scripts/AppKit/test-appkit.sh`, `.scripts/UIKit/test-uikit.sh`,
`.scripts/Android/test-android.sh`, `.scripts/GTK/test-gtk.sh`,
`.scripts/Web/test-web.sh`, and `.scripts\WinUI\test-winui.ps1` on Windows -
which [Test](development.md#test) lists with the arguments each takes.

Build the signed Gallery bundle with its resources and icon:

```bash
.scripts/AppKit/build-gallery-appkit.sh debug
```

A new application is HelloWorld under another name, with every head
HelloWorld has and its example test in `Tests/`, which `swift test` and
**StateUI: Run Tests** run. This makes `apps/Notes`
(`.scripts/new-app.ps1 -Name Notes` on Windows):

```bash
.scripts/new-app.sh Notes
```

### A project group

An application outside the checkout lives in a project group, a folder of its
own that **StateUI: New Project Group** makes. Its applications build with a
StateUI release cloned into the group's `StateUI/`, or with a local checkout.
Each names that StateUI by path in its `Package.swift`, and that StateUI's
`.scripts/` build and run its heads:

```text
MyApps/
  .gitignore
  .vscode/            StateUI: Debug and StateUI: Release
  StateUI/            the release, left out of git; absent with a local checkout
  apps/
    Notes/            HelloWorld renamed; its Package.swift names ../../StateUI
```

**StateUI: New Application in apps/** makes the next application there. The
extension's README, `lib/StateUI.VSCode/README.md`, describes the choices and
the settings that save them.

## Application shape

Every application follows one structural path:

```text
Application -> Scene -> windows -> a view
```

Each declares what it is made of in its `body`. Runtime properties such as
styles, window title and geometry belong to session objects in the
environment; what the page is - its title - the view it shows says by
modifier.

```swift
struct NotesApp: Application {
    var body: some Scene {
        WindowGroup { MainPage() }
    }
}

struct MainPage: View {
    @State private var note = ""

    var body: some View {
        VStack {
            Text(note.isEmpty ? "A new note" : note)
            TextField($note).placeholder("Write something")
        }
        .spacing(12)
        .padding(24)
        .title("Notes")
    }
}
```

An application's `body` lists its scenes. A window written there, as above,
is a scene of its own. A `Scene` - a protocol with one `var body: some Scene`,
as `Application` has - groups the windows that share its `@State`; it stands
from its first window to its last. A scene's body declares its windows:

- `WindowGroup { MainPage() }`, one in the application, is what launch and
  *File ▸ New Window* make a window of;
- `WindowGroup(.kind) { ... }` makes as many windows of a kind as are opened,
  and `Window(.kind) { ... }` makes one;
- `WindowGroup(.kind, for: ID.self) { $id in ... }` makes one window per
  value.

A kind is a `WindowType` the application names in an extension of it:
`static let editor = WindowType("editor")`. A view reads the application's session with `@Environment(\.application)`,
and `application.openWindow(.kind)` opens a window of that kind in the scene
declaring it, opening the scene with it where it is not open.

`Application`, `Scene`, `WindowGroup` and `Window` are declarations, not native
objects, and so is the view a window shows, which stands on a page. Their
sessions carry the identity and mutable runtime state.
[Applications and sessions](interface/application-and-sessions.md) describes that model
in full: [scenes](interface/application-and-sessions.md#scenes), the kinds of
window, and [opening and closing](interface/application-and-sessions.md#opening-and-closing)
them.

## Two modules and one registration point

An application has two concerns:

```text
NotesUI                     NotesAppKit
------------------------    ---------------------------
imports StateUI             imports NotesUI
Application and scenes      imports StateUIAppKit
windows and pages           locates native resources
state and styles            starts the AppKit host
no toolkit imports          contains no application UI
```

The UI module exports one stable registration function. Registration names the
application type to the host; it does not build native controls itself. It
runs on the UI thread, where every head calls it before the host starts - it is
`@MainActor`, as everything that touches the interface is.

```swift
struct RegisteredApp: Application {
    var body: some Scene {
        WindowGroup { RegisteredPage() }
    }
}

struct RegisteredPage: View {
    var body: some View { Text("Hello, StateUI") }
}

@_cdecl("stateui_app_register")
@MainActor
public func stateui_app_register() {
    stateUIUseApp(RegisteredApp())
}
```

The AppKit executable registers the module and starts the host:

```swift quote
import Foundation
import NotesUI
import StateUIAppKit

stateui_app_register()

let application = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .deletingLastPathComponent()
let resources = application.appendingPathComponent("Resources/Images", isDirectory: true)

StateUIAppKit.run(
    resourceDirectory: resources,
    applicationIcon: application.appendingPathComponent("Resources/AppIcon/appicon_macos.svg"))
```

The head finds its artwork from its own source file, so it runs from any
directory. Its icon is drawn on macOS's icon grid; see
[AppKit host](hosts/appkit.md).

Registration and `run` happen once per process. All scenes and windows then
belong to one application tree, renderer generation, and native host. Opening a
new scene does not start another host; it asks that host to materialize another
native scene session.

The UIKit, WinUI, GTK and Web heads call the same `stateui_app_register`
before their host's `run`, and the Android head when Android loads its
library; each host's page describes its head: [UIKit](hosts/uikit.md),
[Android Views](hosts/android.md), [WinUI](hosts/winui.md),
[GTK](hosts/gtk.md), [Web](hosts/web.md).

Between `stateui_app_register()` and `run`, a head registers what this host
answers for the application beyond the library:

- the application's own controls, acts and event sources, through the host's
  `StateUIControls`, `StateUIActs` and `StateUIEvents` - each host's page
  shows them under *Controls, acts, and events registered in Swift*
  ([GTK](hosts/gtk.md#controls-acts-and-events-registered-in-swift));
- the backends it shows a library element through. A backend is a package of
  its own, `lib/Backends/<Element>.<Host>`, for an element whose engine is a
  library the platform does not ship: the web view on GTK
  (`lib/Backends/WebView.GTK`, over WebKitGTK) and on WinUI
  (`lib/Backends/WebView.WinUI`, over the WebView2 runtime).

The Gallery's GTK head registers both:

```swift quote
import GalleryUI
import StateUIGTK
import StateUIWebViewGTK

stateui_app_register()
GalleryControls.register()
GalleryActs.register()
GalleryEventSources.start()
StateUIWebViewGTK.register()
StateUIGTK.run(applicationID: "com.stateui.gallery")
```

`GalleryControls`, `GalleryActs` and `GalleryEventSources` are the Gallery's
own, in `Platforms/GTK/Host/` beside the head. A head that registers a
backend also depends on its package, which the application's manifest adds on
that host's build alone - `apps/Gallery/Package.swift` on a GTK or WinUI
build:

```text
Package.swift, on a GTK build
  dependencies:  .package(name: "StateUIWebViewGTK", path: "../../lib/Backends/WebView.GTK")
  the GTK head:  .product(name: "StateUIWebViewGTK", package: "StateUIWebViewGTK")
```

An application showing no web page names no backend and links no engine.

A new application has this directory shape (`.scripts/new-app.sh Notes`):

```text
apps/Notes/
  Package.swift
  Sources/
    NotesApp.swift
    MainPage.swift
    Styles/
      AppStyles.swift
  Platforms/
    AppKit/
      main.swift
    UIKit/
      main.swift
    Android/
      build.gradle.kts
      settings.gradle.kts
      AndroidManifest.xml
      Swift/
        NotesAndroid.swift
    WinUI/
      main.swift
    GTK/
      main.swift
    Web/
      main.swift
  Resources/
    AppIcon/
    Images/
  Tests/
    MainPageTests.swift
```

The application target depends only on the `StateUI` product. The executable
target depends on the application target and `StateUIHead`
(`lib/StateUI.Head`), which brings it the host the build is for -
`StateUIAppKit` on an AppKit build - and on a backend's product where it
registers one. Both targets
enable `NonisolatedNonsendingByDefault`; [Concurrency](interface/concurrency.md) explains
why that module-wide setting is part of the application contract.

## Controls and modifiers

A control's purpose value belongs in its initializer. Optional capabilities
are modifiers:

```swift
@State var accepted = false
@State var volume = 0.5

VStack {
    Text("Playback")
        .fontSize(24)

    Slider($volume)
        .minimum(0)
        .maximum(1)

    CheckBox($accepted)
}
```

A binding form is two-way where the control owns an editable value. Passing a
plain value describes it in one direction. A handler reports a user or
platform action; an application write does not synthesize that event.

The active surface and per-host evidence live in
[Platform contract](platform-contract.md). Public API documentation beside a
declaration explains its focused semantics.

## Adding source and resources

SwiftPM discovers every `.swift` file below a target's `path`; a source list is
unnecessary. Add application files below `Sources/` and keep native entry
points below `Platforms/<Host>/`.

Image names are application data. Put image files under the resource directory
passed to the host and refer to them through `ImageSource` or a string-literal
file name:

```swift
Image("stateui_tile.png")
    .height(120)
    .horizontalAlignment(.center)
```

The AppKit head reads `Resources/` beside its own sources, and the Android
head's build draws `Resources/Images` into the application's assets and its
icon from `Resources/AppIcon`. StateUI's core does not read a filesystem or
choose a platform image class.

## Next steps

Read [State and reactivity](concepts/state-and-reactivity.md) before building data flow,
then [Applications and sessions](interface/application-and-sessions.md) for navigation
and multiple windows. Run the Gallery whenever a feature's behavior is easier
to understand by using it than by reading about it.
