# AppKit host

The AppKit host renders a StateUI application with AppKit controls on macOS. It
runs in the same process as the application module and the library, and applies
the typed sparse patches of the [host contract](../internals/host-contract.md) directly.

It presents StateUI's controls, arrangements and pages over the runtime every
host shares - the [platform contract](../platform-contract.md#control-creation) says
which, member by member - and shows any other control's name in red where the
control belongs, so a gap is visible rather than silent.

```text
lib/StateUI/StateUI.AppKit/
  Sources/    StateUIAppKit: the renderer, windows, sessions and the registry
  Tests/      the host's suite
.scripts/AppKit/
  build-gallery-appkit.sh      the Gallery's bundle, in apps/Gallery/.build/appkit
  deploy.sh                    an application's head built for release, laid in a folder of its own
  test-appkit.sh               runs the host's suite
apps/<App>/Platforms/AppKit/
  main.swift                   the application's AppKit head
  Host/                        what this host answers for the application
```

## Requirements

The host builds on macOS 26 or newer, with Xcode 27 or newer and its Swift
6.4. macOS 26 is the floor of the host's package and of the library, which an
application's manifest cannot go below. A Debug launch runs Xcode's
`lldb-dap`. Nothing else is installed: the `Map` and the `WebView` stand on
MapKit and WebKit, which macOS ships. [Tested setups](../tested-setups.md)
names the versions the host's suite passes on.

## The head

An application's AppKit head is `Platforms/AppKit/main.swift`. It registers the
application, says what this host answers for it, then starts the host:

```swift quote
import NotesUI
import StateUIAppKit

stateui_app_register()

// The controls this host realizes, the acts it performs, and the pushes it
// reports. Each lives in Host/ beside this file.
NotesControls.register()
NotesActs.register()
NotesEventSources.start()

StateUIAppKit.run(resourceDirectory: resources, applicationIcon: icon)
```

The head finds its artwork from its own source file, `#filePath`, so it runs
the same whether a debugger, a task or a terminal starts it. The icon it hands
the host is `Resources/AppIcon/appicon_macos.svg`, drawn on macOS's icon grid:
a 1024-point canvas whose body is an 824-point rounded square 100 points in.
Artwork drawn edge to edge stands larger in the Dock than every icon beside
it.

Every AppKit build of an application defines the `APPKIT` compilation
condition; Swift written for this host alone stands under `#if APPKIT`. See
[Project structure and development](../development.md).

## Controls, acts, and events registered in Swift

An application extends the host from its AppKit head. Registrations run before
`StateUIAppKit.run`, on the main thread. Registering a contract or an act again
replaces the earlier registration.

**A host in the same process registers BY TYPE.** Every registration is written
against the same `ElementContract` the application's own views are written
against, so the compiler refuses a property of the wrong type, an event of a
contract the element does not wear, and a performer whose arguments are not the
act's.

Because the registration names the contract's types, the application's
contracts are `public`: the host lives in a module of its own and must see
them. The Swift half itself is the same for every host - one contract, one
`View`. The AppKit halves are in `apps/Gallery/Platforms/AppKit/Host/`.

### A control

`StateUIControls.add` says what an application's own element IS on screen:

```swift quote
public static func add<Realized: ElementContract, Made: NSView>(
    _ contract: Realized.Type,
    create: @escaping (AppKitReports<Realized>) -> Made,
    members: (AppKitRegistration<Realized, Made>) -> Void = { _ in })
```

- **`create`** makes the view once per element, and wires what the view
  reports: `reports.raise(Contract.member, values)` for an event of the
  element's own, and `reports.report(property, value, as: event)` for a value
  the USER changed - which lands on the state the value is carried in and
  raises the event with it.
- **`members`** registers what the view takes: `property(_:_:)` hands a value
  over as the type its contract declares, `nil` where it is no longer
  described, and `raises(_:)` records an event the view raises.

Name the view's own class where the closure makes it - `create: { reports ->
TrafficLightView in … }` - so every applier is handed that class rather than a
bare `NSView`.

```swift quote
StateUIControls.add(TrafficLightContract.self, create: { reports -> TrafficLightView in
    let light = TrafficLightView()
    light.onLampTapped = { index in
        reports.raise(TrafficLightContract.lampTapped, index)
    }
    return light
}) { light in
    light.property(TrafficLightContract.signal) { view, signal in
        view.signal = (signal ?? .stop).rawValue
    }
    light.raises(TrafficLightContract.lampTapped)
}
```

Write a control's registration beside the view it registers: a `static func
register()` in an extension at the end of the view's own file. Everything
about the control - the view, what it reports, what it takes and the acts aimed
at it - is then read in one place, and the application's list of its controls
is only a list:

```swift quote
extension TrafficLightView {
    @MainActor
    static func register() {
        StateUIControls.add(TrafficLightContract.self, create: { reports -> TrafficLightView in
            …
        }) { light in
            …
        }
    }
}

enum NotesControls {
    @MainActor
    static func register() {
        TrafficLightView.register()
        RatingBarView.register()
    }
}
```

The host keeps a registered view between renders by identity, and applies the
shared view properties around it: margins, alignment, opacity, sizing,
gestures, focus, and frame reports. A node type with no registration draws the
unsupported-control marker.

A Swift `Style` can target the control once its Swift struct conforms to
`StyleTarget`. Styles resolve on the Swift side, so the control arrives with
the style's values already among its own; the registration needs nothing for
it. A value handed over as a state - `.rating($stars)` over
`setValue(_:on:mode:kind:)` - reaches the same applier on the host's own
frames; see [Motion and journeys](../concepts/motion-and-journeys.md).

**A registered view draws however it likes, the GPU included.** An `MTKView` is
an `NSView`, so its registration says no more than any other one: the Gallery's
`Cube3D`, drawn here with Metal, takes a size, a colour and whether it turns, and the corners, the
matrix and the frames stay the host's. Two things belong to a view that runs a
loop of its own. It stops that loop when the tree drops it - the Gallery's
pauses in `viewDidMoveToWindow`, so nothing turns behind a page the user has
left. And a stopped loop still owes one frame to a value that changed, or a
size moved while it is paused arrives only when the user starts it again.

An element only some hosts can honestly realize is declared only for them.
`Cube3D`'s contract and its `View` stand under
`#if APPKIT || UIKIT || GTK || WINUI || ANDROID` - one declaration, drawn with
Metal here and on UIKit, with OpenGL on GTK, Direct3D on WinUI and OpenGL ES on
Android - so a test reading an application's elements against another host's
registrations never demands of that host a control it cannot draw.

**A registered control has no slot on this host.** This host arranges
children by the container classes it makes itself, so a registered view is
handed none - a registered element's children reach nothing. An application's
own element is a leaf here: it draws the children of a contract it names
itself, as the next section says, and no other child is shown.

### Children a control draws

A view may draw the children of one contract itself - a map draws its markers.
`children` names their contract and what of each the view realizes, and hands
it every such child, in the tree's order, whenever the element's children
change: one added, moved, taken away, or given another value. A child is a
`AppKitChild` - its values read as the types its contract declares, and its own
`reports` to raise its events on it - and stays the same child for as long as
it lives, so the view keeps what it drew for one by it. Such a child has no
view of its own.

```swift quote
StateUIControls.add(MapContract.self, create: { reports -> MyMap in … }) { map in
    map.property(MapContract.region) { view, region in … }
    map.children(MarkerContract.self, members: [MarkerContract.location, MarkerContract.selected]) { view, markers in
        view.show(markers.map { marker in (marker, marker.value(MarkerContract.location)) })
        // the user taps one: marker.reports.raise(MarkerContract.selected)
    }
}
```

This host draws a `Map` with MapKit itself. A library element a host does
not realize - a `Map` on a platform with no map of its own - is registered
the same way, with the provider and the key it needs.

### An act

`StateUIActs.add` registers a function the application calls by its act:

```swift quote
public static func add<
    Owner: ApplicationTier, each Argument: HostRepresentable, each Answer: HostRepresentable
>(
    _ act: ElementAct<Owner, (repeat each Argument), (repeat each Answer)>,
    _ perform: @escaping @MainActor (repeat each Argument) async throws -> (repeat each Answer)
)
```

```swift quote
StateUIActs.add(NotesContract.setClipboard) { text in
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(text, forType: .string)
}

StateUIActs.add(NotesContract.batteryLevel) {
    battery()
}
```

An act AIMED at one of the application's own elements takes the view instead:
the aim puts the element's identity in argument 0, and this host turns it back
into the view its registration made.

```swift quote
StateUIActs.add(RatingBarContract.flash, on: RatingBarView.self) { bar in
    bar.flash()
}
```

- **Where it runs.** A performer runs on the main thread, where AppKit draws,
  and may await: the call is answered once it returns.
- **Its values.** The arguments and the answer are the act's own types. A call
  carrying anything else fails with the reason rather than running on a guess.
- **Failure.** A thrown error fails the act: the awaiting Swift handler throws
  `StateUIError` with the reason. An aim at nothing, or at an element no longer
  on screen, fails the same way.
- **Scope.** An act nobody registered fails with that reason, named.

The Swift half is under
[Host-extension actions](../interface/interaction-and-actions.md#host-extension-actions).

### An event without a control

`StateUIEvents.raise` pushes an event of the application's that belongs to no
element, such as a power or network change:

```swift quote
public nonisolated static func raise<Owner: ApplicationTier, each Value: HostRepresentable>(
    _ event: ElementEvent<Owner, (repeat each Value)>,
    _ value: repeat each Value)
```

```swift quote
NotificationCenter.default.addObserver(
    forName: .NSProcessInfoPowerStateDidChange, object: nil, queue: nil
) { _ in
    StateUIEvents.raise(
        NotesContract.lowPowerChanged, ProcessInfo.processInfo.isLowPowerModeEnabled)
}
```

`raise` is one door in from any thread, as a post is: a source calls it where
the platform reports, and the subscriptions hear it on the UI thread soon
after, in the order raised. A raise nobody hears is an ordinary one rather
than a failure, so an application wires its sources unconditionally. The Swift side subscribes with `HostEvents.on`; see
[Host-extension events](../interface/interaction-and-actions.md#host-extension-events).

The head declares each event it raises where it wires the source, before
`StateUIAppKit.run(resourceDirectory:applicationIcon:)`:

```swift quote
StateUIEvents.raises(NotesContract.lowPowerChanged)
```

The host tells the core what it realizes when it starts: every element of the
library's it shows, the controls the application added, and the events
declared. A `HostEvents.on` for an event nothing declared is then said once -
*the host raises no `Notes.LowPowerChanged`: the handler will not hear it* -
with the declared names nearest to it; so is an element the host shows none
of, the first time it is described.

## Running

```bash
.scripts/AppKit/build-gallery-appkit.sh debug
open apps/Gallery/.build/appkit/debug/GalleryAppKit.app
```

`build-gallery-appkit.sh` builds the Gallery's head, `debug` or `release`, and
makes it an application bundle, `apps/Gallery/.build/appkit/<configuration>/GalleryAppKit.app`:
the head, the StateUI libraries it links, the Gallery's pictures, its icon
drawn from `Resources/AppIcon/appicon_macos.svg`, an `Info.plist` and an
ad-hoc signature. It prints where the bundle is. An application with no
bundling script of its own is built by SwiftPM, and runs as the executable it
makes:

```bash
STATEUI_HOST=appkit swift build --package-path apps/HelloWorld \
  --scratch-path apps/HelloWorld/.build/appkit --product HelloWorldAppKit
apps/HelloWorld/.build/appkit/debug/HelloWorldAppKit
```

Everything an AppKit build writes stays in the application's `.build/appkit/`.

In VS Code, choose **AppKit** as the host and press **F5**. **StateUI: Debug**
builds the head - with the application's bundling script,
`.scripts/AppKit/build-<application>-appkit.sh`, where it has one, else with
SwiftPM - and starts it under `lldb-dap`, so a breakpoint in the application,
in StateUI or in the host holds from the first line. **StateUI: Release**
builds and starts the optimized head the same way.

## Deploying

```bash
.scripts/AppKit/deploy.sh apps/Gallery artifacts/Gallery/AppKit
```

`deploy.sh` builds an application's head for release and lays it in the
folder named, made anew: its application bundle, where `.scripts/AppKit`
holds a bundling script of the application's, else the head, the StateUI
libraries it links and the application's pictures in `Images/`.
**StateUI: Deploy** in the editor runs it for the application chosen, and
lays the head in `artifacts/<application>/AppKit` of the folder that holds
the application's `apps/` - a checkout's, or a project group's.

## Testing

```bash
.scripts/AppKit/test-appkit.sh
.scripts/AppKit/test-appkit.sh --filter AppKitConformanceTests/testButton
```

`test-appkit.sh` runs `swift test` in `lib/StateUI/StateUI.AppKit`, handing
it its arguments. The suite is XCTest. It runs the conformance families too,
one test a family - `AppKitConformanceTests/testButton` - and the longest in
parts, each a test of its own, which `--parallel` runs side by side.

A run holds what it says to `lib/StateUI/exports/`: what the host declares to
`appkit.txt`, and each family's verdicts to `marks/appkit/<Family>.txt`; a
run that says otherwise fails. `STATEUI_UPDATE_EXPORTS=1` writes them
instead, each verdict file under the revision its family stands at in
`lib/StateUI/StateUI.Conformance/revisions.txt`, and `STATEUI_STALE_ONLY=1`
runs only the families whose verdicts stand at another revision, or at none:
each other family's test ends at once. With the verdicts written, the
[platform contract](../platform-contract.md#reading-the-matrix) and
[the control dictionary](../controls/README.md) are rendered from them at the
repository's root:

```bash
STATEUI_UPDATE_EXPORTS=1 .scripts/AppKit/test-appkit.sh --filter AppKitConformanceTests
STATEUI_UPDATE_DOCS=1 swift test --filter ControlDictionaryTests
```

In the editor, with AppKit chosen, **StateUI: Conformance - Rebuild all**
runs both: the families writing their verdicts, then the documents.
**StateUI: Conformance - Rebuild changed** runs the stale families alone
before it renders.
