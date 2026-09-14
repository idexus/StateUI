# Getting started

StateUI applications keep their interface and application state in a
platform-neutral Swift module. A small native executable imports that module
and the selected host package. The same application module can therefore be
started by another host without changing its view tree.

AppKit is the active native host. The supported setup today is a StateUI
checkout: the AppKit host is a sibling Swift package whose manifest currently
uses a local dependency on the repository root. A remote package declaration
for the complete library-plus-host pair is not published yet.

## Requirements

- macOS 14 or newer;
- a Swift 6 toolchain supplied by Xcode;
- a checkout of this repository.

Build the small application from the repository root:

```bash
swift build --package-path apps/HelloWorld --product HelloWorldAppKit
```

Build the signed Gallery bundle with its resources and icon:

```bash
.scripts/build-gallery-appkit.sh debug
```

VS Code also exposes Debug and Release F5 configurations for both
applications.

## Application shape

Every application follows one structural path:

```text
Application -> Scene -> Window -> Page -> View
```

Each type declares exactly one composition property. Runtime properties such
as styles, window title, geometry, and page title belong to session objects in
the environment.

```swift
struct NotesApp: Application {
    var scene: any Scene { NotesWindow() }
}

struct NotesWindow: Window {
    var page: any Page { NotesPage() }
}

struct NotesPage: ContentView {
    @Environment private var page: PageSession
    @State private var note = ""

    var content: any View {
        VStack {
            Label(note.isEmpty ? "A new note" : note)
            TextField($note).placeholder("Write something")
        }
        .spacing(12)
        .padding(24)
        .onCreated { page.title = "Notes" }
    }
}
```

`Application`, `Scene` and `Window` are declarations, not native objects, and
so is the view a window shows as its page. Their sessions carry the identity
and mutable runtime state.
[Applications and sessions](application-and-sessions.md) describes that model
in full.

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
application type to the host; it does not build native controls itself.

```swift
struct RegisteredApp: Application {
    var scene: any Scene { RegisteredWindow() }
}

struct RegisteredWindow: Window {
    var page: any Page { RegisteredPage() }
}

struct RegisteredPage: ContentView {
    var content: any View { Label("Hello, StateUI") }
}

@_cdecl("stateui_app_register")
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

let resources = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    .appendingPathComponent("apps/Notes/Resources/Images", isDirectory: true)

StateUIAppKit.run(resourceDirectory: resources)
```

Registration and `run` happen once per process. All scenes and windows then
belong to one application tree, renderer generation, and native host. Opening a
new scene does not start another host; it asks that host to materialize another
native scene session.

The repository examples use this directory shape:

```text
apps/Notes/
  Package.swift
  Sources/
    NotesApp.swift
    NotesPage.swift
    Styles/
  Platforms/
    AppKit/
      main.swift
  Resources/
    Images/
  Tests/
```

The application target depends only on the `StateUI` product. The executable
target depends on the application target and `StateUIAppKit`. Both targets
enable `NonisolatedNonsendingByDefault`; [Concurrency](concurrency.md) explains
why that module-wide setting is part of the application contract.

## Controls and modifiers

A control's purpose value belongs in its initializer. Optional capabilities
are modifiers:

```swift
@State var accepted = false
@State var volume = 0.5

VStack {
    Label("Playback")
        .fontSize(24)

    Slider($volume)
        .minimum(0)
        .maximum(1)

    CheckBox($accepted)
}
```

A binding form is two-way where the control owns an editable value. Passing a
plain value describes it in one direction. A handler reports a reader or
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

The native bundling script is responsible for copying those files and the app
icon into the application bundle. StateUI's core does not read a filesystem or
choose a platform image class.

## Next steps

Read [State and reactivity](state-and-reactivity.md) before building data flow,
then [Applications and sessions](application-and-sessions.md) for navigation
and multiple windows. Run the Gallery whenever a feature's behavior is easier
to understand by using it than by reading about it.
