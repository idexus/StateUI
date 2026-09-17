# AppKit host

The AppKit host renders a StateUI application with AppKit controls on macOS. It
runs in the same process as the application module and the library, and applies
the typed sparse patches of the [host contract](host-contract.md) directly - no
Wire encoding stands between them.

```text
lib/StateUI.AppKit/
  Sources/    StateUIAppKit: the renderer, windows, sessions and the registry
  Tests/      the host's suite
.scripts/AppKit/
  build-gallery-appkit.sh      the Gallery's bundle, in apps/Gallery/.build-appkit
apps/<App>/Platforms/AppKit/
  main.swift                   the application's AppKit head
  Host/                        what this host answers for the application
```

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
[Project structure and development](development.md).

## Controls, acts, and events registered in Swift

An application extends the host from its AppKit head. Registrations run before
`StateUIAppKit.run`, on the main thread. Registering a contract or an act again
replaces the earlier registration.

**A host in the same process registers BY TYPE.** Every registration is written
against the same `ElementContract` the application's own views are written
against, so the compiler refuses a property of the wrong type, an event of a
contract the element does not wear, and a performer whose arguments are not the
act's. That is the difference from the [MAUI host](maui-host.md), which
registers by name across the wire and reads its values untyped.

Because the registration names the contract's types, the application's
contracts are `public`: the host lives in a module of its own and must see
them. The Swift half itself is unchanged from any other host - one contract,
one `View` - which is why the Gallery's "AppKit interop" group and its "C#
interop" group show the SAME Swift beside two different hosts. The AppKit
halves are in `apps/Gallery/Platforms/AppKit/Host/`.

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
  the READER changed - which lands on the state the value is carried in and
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
frames; see [Motion and journeys](motion-and-journeys.md).

**A registered view draws however it likes, the GPU included.** An `MTKView` is
an `NSView`, so its registration says no more than any other one: the Gallery's
Metal cube takes a size, a colour and whether it turns, and the corners, the
matrix and the frames stay the host's. Two things belong to a view that runs a
loop of its own. It stops that loop when the tree drops it - the Gallery's
pauses in `viewDidMoveToWindow`, so nothing turns behind a page the reader has
left. And a stopped loop still owes one frame to a value that changed, or a
size moved while it is paused arrives only when the reader starts it again.

An element only one host can honestly realize is declared only for that host.
The Metal cube's contract and its `View` stand under `#if APPKIT` beside its
samples, so a test reading an application's elements against another host's
registrations never demands of that host a control it cannot draw.

**A registered control has no slot on this host.** The MAUI
registration takes a `content:` that places the one child the Swift side
describes. This host arranges children by the container classes it makes
itself, so a registered view is handed none - a registered element's children
reach nothing. An application's own element is a leaf here.

### An act

`StateUIActs.add` registers a function the application calls by its act:

```swift quote
public static func add<
    Owner: ApplicationTier, each Argument: HostRepresentable, each Answer: HostRepresentable
>(
    _ act: ElementAct<Owner, (repeat each Argument), (repeat each Answer)>,
    _ perform: @escaping @MainActor (repeat each Argument) throws -> (repeat each Answer))
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

- **Where it runs.** A performer runs on the main thread, where AppKit draws.
- **Its values.** The arguments and the answer are the act's own types. A call
  carrying anything else fails with the reason rather than running on a guess.
- **Failure.** A thrown error fails the act: the awaiting Swift handler throws
  `StateUIError` with the reason. An aim at nothing, or at an element no longer
  on screen, fails the same way.
- **Scope.** An act nobody registered fails with that reason, named.

The Swift half is under
[Host-extension actions](interaction-and-actions.md#host-extension-actions).

### An event without a control

`StateUIEvents.raise` pushes an event of the application's that belongs to no
element, such as a power or network change:

```swift quote
@discardableResult
public nonisolated static func raise<Owner: ApplicationTier, each Value: HostRepresentable>(
    _ event: ElementEvent<Owner, (repeat each Value)>,
    _ value: repeat each Value) -> Int
```

```swift quote
NotificationCenter.default.addObserver(
    forName: .NSProcessInfoPowerStateDidChange, object: nil, queue: nil
) { _ in
    StateUIEvents.raise(
        NotesContract.lowPowerChanged, ProcessInfo.processInfo.isLowPowerModeEnabled)
}
```

`raise` is safe from any thread, so a source is wired where the platform
reports it. It answers how many subscriptions heard it: a raise nobody hears is
an ordinary zero rather than a failure, so an application wires its sources
unconditionally. The Swift side subscribes with `HostEvents.on`; see
[Host-extension events](interaction-and-actions.md#host-extension-events).
