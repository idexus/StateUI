# Getting started

StateUI applications keep their interface and application state in a
platform-neutral Swift module. A small native executable imports that module
and the selected host package. The same application module can therefore be
started by another host without changing its view tree.

Six hosts are active - AppKit, UIKit, Android Views, WinUI 3, GTK 4 and the
Web - each Swift, in the application's own process. Install StateUI as a
complete checkout: a release tag for a released application, or a local
development checkout. Each host is a sibling Swift package whose manifest uses
a local dependency on the repository root. An application outside the checkout
lives in a [project group](editors/VSCode/README.md#a-project-group): the group clones a
release into its `StateUI/` directory or names an existing checkout. The library,
the selected host, and any backends are built from that same checkout.

## Requirements

- macOS 26.4 or newer, with Xcode 27 and its Swift 6.4, for the AppKit host;
- a checkout of this repository;
- VS Code and Node.js 20 or newer, for the StateUI extension.

[UIKit host](hosts/uikit.md#requirements) lists what the UIKit host needs for
the iOS simulator, [Android Views host](hosts/android.md#requirements) what the
Android Views host needs as well, [WinUI host](hosts/winui.md#requirements) what the
WinUI host needs on Windows, [GTK host](hosts/gtk.md#requirements) what
the GTK host needs on Linux, and [Web host](hosts/web.md#requirements) what the
Web host needs on macOS and Linux.

With the extension installed ([Installing](editors/VSCode/README.md#installing)),
**StateUI: Check Toolchain** in the Command Palette looks on this machine for
what these pages list for its platform's hosts, and says what to install for
whatever is missing. [Tested setups](tested-setups.md) names the versions and
devices StateUI's suites pass on.

## Working in VS Code

VS Code is where StateUI applications are built, run, debugged, and tested,
through the StateUI extension. [StateUI for VS Code](editors/VSCode/README.md)
installs it and covers everything it does: the host and the application
chosen once in the status bar, the launches, the suites, deploying, and a
project group for applications outside the checkout.

### From the command line

Every launch has a command-line equivalent. Build and start HelloWorld's
AppKit head from the repository root:

```bash
.scripts/AppKit/run-app.sh apps/HelloWorld debug
```

The script builds it with `STATEUI_HOST=appkit`, the variable that makes it an
AppKit build: the manifest then declares the
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
HelloWorld has and its example test in `Tests/` - its page shown in a test
window, its button clicked ([Testing an application](interface/testing.md)) -
which `swift test` and **StateUI: Run Tests** run. This makes `apps/Notes`
(`.scripts/new-app.ps1 -Name Notes` on Windows):

```bash
.scripts/new-app.sh Notes
```

Test it, then build and start its AppKit head from the same repository root:

```bash
swift test --package-path apps/Notes
.scripts/AppKit/run-app.sh apps/Notes debug
```

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
        .pageTitle("Notes")
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
- `WindowGroup(.kind) { $id in ... }`, a kind with a value, makes one window per
  value.

A kind is a `WindowKind` the application names in an extension of it, for the
value its windows stand for - `Void` where they stand for none:
`extension WindowKind where Value == Void { static let editor = WindowKind("editor") }`. A view reads the application's session with `@Environment(\.application)`,
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

The UI module exports its application type, which every head registers:
`RegisteredApp.register()` names the application to the host, which makes it
at its first need - so an application has an `init()` taking nothing. It does
not build native controls itself. It runs on the UI thread, where every head
calls it before the host starts - it is `@MainActor`, as everything that
touches the interface is.

```swift
public struct RegisteredApp: Application {
    public init() {}

    public var body: some Scene {
        WindowGroup { RegisteredPage() }
    }
}

struct RegisteredPage: View {
    var body: some View { Text("Hello, StateUI") }
}
```

The AppKit executable registers the application and starts the host - the
starter's `Platforms/AppKit/main.swift` does that and finds its artwork; the
Gallery's head, which also registers its own controls, reads:

```swift listing appkit.md.head
// Platforms/AppKit/main.swift
import GalleryUI
import StateUI
import StateUIAppKit

GalleryApp.register()

// What this host answers for the application, said before it runs: the
// controls it realizes, the acts it performs, and the pushes it reports. Each
// lives in Host/ beside this file.
GalleryControls.register()
GalleryActs.register()
GalleryEventSources.start()

AppKitHost.run()
```

The host finds the artwork beside the program - its bundle's, or the
`Resources` that `.scripts/AppKit/run-app.sh` and `deploy.sh` lay there - so a
head runs from any directory, and on another Mac. Its icon is drawn on
macOS's icon grid; see [AppKit host](hosts/appkit.md).

Registration and `run` happen once per process. All scenes and windows then
belong to one application tree, renderer generation, and native host. Opening a
new scene does not start another host; it asks that host to materialize another
native scene session.

The UIKit, WinUI, GTK and Web heads call the same `register()`
before their host's `run`, and the Android head when Android loads its
library; each host's page describes its head: [UIKit](hosts/uikit.md),
[Android Views](hosts/android.md), [WinUI](hosts/winui.md),
[GTK](hosts/gtk.md), [Web](hosts/web.md).

Between `register()` and `run`, a head registers what this host
answers for the application beyond the library:

- the application's own controls, acts and event sources, through the host's
  `StateUIControls`, `StateUIActs` and `StateUIEvents` - each host's page
  shows them under *Controls, acts, and events registered in Swift*
  ([GTK](hosts/gtk.md#controls-acts-and-events-registered-in-swift)), and
  [Extending StateUI](interface/extending.md) writes their Swift half;
- the backends it shows a library element through. A backend is a package of
  its own, `lib/Backends/<Element>.<Host>`, for an element whose engine is a
  library the platform does not ship: the web view on GTK
  (`lib/Backends/WebView.GTK`, over WebKitGTK) and on WinUI
  (`lib/Backends/WebView.WinUI`, over the WebView2 runtime).

The Gallery's GTK head registers both:

```swift listing gtk.md.head
// Platforms/GTK/main.swift
import GalleryUI
import StateUI
import StateUIGTK
import StateUIWebViewGTK

// Name the gallery to the host, then say what this host answers for it before it runs: the controls it realizes,
// the acts it performs, and the pushes it reports - each in Host/ beside this file.
GalleryApp.register()
// Each control's own register(), at the end of its file: its widget, and any act aimed at it.
GalleryControls.register()
GalleryActs.register()
GalleryEventSources.start()
// The backends the Gallery shows a library element through: the web view, over WebKitGTK.
WebViewGTK.register()
// Then GTK holds this thread until the last window closes.
GTKHost.run(applicationID: "com.stateui.gallery")
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

The application target depends only on the `StateUI` product, its tests on
`StateUITesting` too. The executable target depends on the application
target, `StateUI` and `StateUIHead` (`lib/StateUI.Head`), which brings it the
host the build is for - `StateUIAppKit` on an AppKit build - and on a
backend's product where it registers one. Every target enables
`NonisolatedNonsendingByDefault`; [Concurrency](interface/concurrency.md)
explains why that module-wide setting is part of the application contract.
Every target enables `MemberImportVisibility` too, so each file imports what
it uses by name: a head imports `StateUI` beside its host, a test `StateUI`
beside `StateUITesting`.

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
