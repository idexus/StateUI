# UIKit host

The UIKit host renders a StateUI application with UIKit controls on iOS and
iPadOS. It is Swift, in the application's own process, beside the application
module and the library: it applies the typed sparse patches of the
[host contract](../internals/host-contract.md) directly, over the runtime every host
shares.

It presents StateUI's controls, arrangements and pages - the
[platform contract](../platform-contract.md#control-creation) says which, member by
member - and shows any other control's name in red where the control belongs,
so a gap is visible rather than silent.

```text
lib/StateUI/StateUI.UIKit/
  Sources/    StateUIUIKit: the renderer, scenes and windows, pages, controls and the registry
  Tests/      the host's suite - an application of tests, run on a simulator
.scripts/UIKit/
  build-app.sh      an application's UIKit head, bundled as an .app for a simulator or a device
  run-app.sh        builds it, installs it on a simulator or a device and starts it
  deploy.sh         builds it for release and lays the bundle in a folder of its own
  test-uikit.sh     builds and runs the host's suite on a simulator
  tools.sh          what they share: the SDK, a build, a bundle, its icon and signature, where it runs
  draw-app-icon.swift  a head's icon, drawn from the application's Resources/AppIcon
apps/<App>/Platforms/UIKit/
  main.swift        the application's UIKit head
  Host/             what this host answers for the application
```

## Requirements

The host builds on macOS with Xcode, for iOS and iPadOS 26 or newer, and runs
on a simulator or on an iPhone or iPad paired with the Mac. `build-app.sh`
builds with Xcode's Swift against the simulator's SDK, for
`arm64-apple-ios26.0-simulator`, or against the device's, for
`arm64-apple-ios26.0`. A device runs with Developer Mode on, and its build is
signed with a development profile of this Mac's that provisions it - one
Xcode makes for a team once the device is added - and a certificate of the
keychain's that the profile names: the script picks them as Xcode does, an
exact application identifier before a wildcard.

## The head

An application's UIKit head is `Platforms/UIKit/main.swift`. It registers the
application, says what this host answers for it, then starts the host, which
never returns - here the Gallery's:

```swift listing uikit.md.head
// Platforms/UIKit/main.swift
import GalleryUI
import StateUIUIKit

registerApplication()

// What this host answers for the application, said before it runs: the
// controls it realizes, the acts it performs, and the pushes it reports. Each
// lives in Host/ beside this file.
GalleryControls.register()
GalleryActs.register()
GalleryEventSources.start()

StateUIUIKit.run()
```

The bundle `build-app.sh` makes carries the application's `Resources/Images`
in `Images/`, every SVG drawn three times over as PNGs, which
`Image("mark.png")` finds as it finds the SVG on every other host, and the
StateUI libraries in `Frameworks/`. Its icon is drawn from
`Resources/AppIcon`: `appicon_bkg.svg` over the whole of a 1024-pixel square
and `appicon_mark.svg` in its middle, opaque, which iOS rounds itself. Its
`Info.plist` says the application supports many scenes.

An application's own keys - the reason it asks for the local network, a
capability the device must have - stand in `Platforms/UIKit/Info.plist`,
which the bundle's `Info.plist` takes in, the application's value where both
name one key. The head's target leaves the file out, as a head leaves out
anything that is not its Swift:

```swift quote
.executableTarget(
    name: "NotesUIKit", dependencies: head, path: "Platforms/UIKit", exclude: ["Info.plist"])
```

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>NSLocalNetworkUsageDescription</key>
    <string>Notes reaches its server on this network.</string>
</dict>
</plist>
```

`STATEUI_HOST=uikit` is what makes a build a UIKit one: the application's
manifest reads it, declares its `Platforms/UIKit` head, and defines the
`UIKIT` compilation condition for every module of the application;
`lib/StateUI.Head` brings the `StateUIUIKit` host to the head. Swift written for this host alone stands
under `#if UIKIT`.

A new application made in `apps/` - **StateUI: New Application in apps/**, or
`.scripts/new-app.sh` - has a UIKit head, as HelloWorld does.

## Scenes and windows

Each StateUI window stands in a window scene of its own. On an iPad the
application opens as many scenes as its windows ask for, and the user moves
between them and closes them as between any application's windows: a window
hears it is activated, put in the background and closed by the user as its
scene is. A window the application closes leaves the one the user was in
before in front of them. On an iPhone one scene stands, and a second window
has none to stand in.

A window's pages are UIKit's own controllers - a navigation controller for a
`NavigationStack`, a tab bar controller for a `TabView`, a split view
controller for a `SplitView` - and its sheets are presented over it, the user's
swipe down taking the top one away. The menus the page the user sees declares
with `.menuBar` stand in the iPad's main menu.

## Controls, acts, and events registered in Swift

An application extends the host from its UIKit head. Registrations run before
`StateUIUIKit.run`, on the main thread. Registering a contract or an act again
replaces the earlier registration.

**A host in the same process registers BY TYPE.** Every registration is
written against the same `ElementContract` the application's own views are
written against, so the compiler refuses a property of the wrong type, an
event of a contract the element does not wear, and a performer whose arguments
are not the act's. The application's contracts are `public`, for the host's
module to see them. The UIKit halves of the Gallery's own are in
`apps/Gallery/Platforms/UIKit/Host/`.

### A control

`StateUIControls.add` says what an application's own element IS on screen:

```swift quote
public static func add<Realized: ElementContract, Made: UIView>(
    _ contract: Realized.Type,
    create: @escaping (UIKitReports<Realized>) -> Made,
    members: (UIKitRegistration<Realized, Made>) -> Void = { _ in })
```

- **`create`** makes the view once per element, and wires what the view
  reports: `reports.raise(Contract.member, values)` for an event of the
  element's own or of a tier it wears, and `reports.report(property, value, as: event)` for a value
  the USER changed - which lands on the state the value is carried in and
  raises the event with it.
- **`members`** registers what the view takes: `property(_:_:)` hands a value
  over as the type its contract declares, `nil` where it is no longer
  described, and `raises(_:)` records an event the view raises.

```swift listing uikit.md.control
// Platforms/UIKit/Host/TrafficLightView.swift
extension TrafficLightView {
    /// Adds the light for `TrafficLightContract`: `create` makes the view once
    /// per element and wires the tap it reports, and `property` puts the
    /// described signal on it. Said once, before the application runs.
    @MainActor
    static func register() {
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
    }
}
```

The host asks a registered view how big it is with `sizeThatFits(_:)`, as
UIKit asks any view it lays out, so a view of the application's own answers
there. It keeps the view between renders by identity and applies the shared
view properties around it: margins, alignment, opacity, sizing, gestures,
focus, and frame reports. A registered view draws however it likes, the GPU
included: the Gallery's `Cube3D` is an `MTKView` drawing with Metal, and its
loop pauses in `didMoveToWindow` once no window shows it. A registered element
is a leaf here: it draws the children of a contract it names itself, as the
next section says, and no other child is shown.

### Properties taken together

A view that must take properties together - a rating bar its stars and its
rating, a web view its agent before its page - names them with `applies`, and
is handed them whole whenever any of them changes: each as the type its
contract declares, and whether it changed (`ControlValues`). Each `property`
alone comes in no promised order. The Gallery's rating bar also reports the
rating the user taps, with `reports.report`:

```swift listing uikit.md.applies
// Platforms/UIKit/Host/RatingBarView.swift
// The bar, added for its contract: its stars and its rating put on it together, a tapped star reported.
StateUIControls.add(RatingBarContract.self, create: { reports -> RatingBarView in
    let bar = RatingBarView()

    // A tapped star is the USER's change: it lands on the state the
    // value is carried in, and raises the event with it - so an
    // application hears it once, whether it holds the rating in a
    // state or in a handler.
    bar.onRatingChanged = { rating in
        reports.report(RatingBarContract.rating, rating, as: RatingBarContract.ratingChanged)
    }
    return bar
}) { bar in
    // The stars and the rating come together: a rating stands within
    // the stars, whichever of the two changed.
    bar.applies(RatingBarContract.maximum, RatingBarContract.rating) { view, values in
        view.show(
            rating: values[RatingBarContract.rating] ?? 0,
            of: Int(values[RatingBarContract.maximum] ?? 5))
    }
    bar.raises(RatingBarContract.ratingChanged)
}
```

### Children a control draws

A view may draw the children of one contract itself - a map draws its markers.
`children` names their contract and what of each the view realizes, and hands
it every such child, in the tree's order, whenever the element's children
change: one added, moved, taken away, or given another value. A child is a
`UIKitChild` - its values read as the types its contract declares, and its own
`reports` to raise its events on it - and stays the same child for as long as
it lives, so the view keeps what it drew for one by it. Such a child has no
view of its own. The Gallery's [Web](web.md#children-a-control-draws) and
[Android](android.md#children-a-control-draws) heads register a map this way.

This host draws a `Map` with MapKit itself. A library element a host does
not realize - a `Map` on a platform with no map of its own - is registered
the same way, with the provider and the key it needs.

### An act

`StateUIActs.add` registers a function the application calls by its act, and
`StateUIActs.add(_:on:_:)` one aimed at the application's own element, handed
that element's view:

```swift listing uikit.md.acts
// Platforms/UIKit/Host/GalleryActs.swift
StateUIActs.add(GalleryContract.log) { line in
    Logger(subsystem: "com.stateui.gallery", category: "Gallery").notice("\(line, privacy: .public)")
}

StateUIActs.add(GalleryContract.batteryLevel) {
    battery()
}

// Platforms/UIKit/Host/RatingBarView.swift
// Aimed at one bar: the identity the aim sent is turned back into the
// view this host made, and the performer is handed that view.
StateUIActs.add(RatingBarContract.flash, on: RatingBarView.self) { bar in
    bar.flash()
}
```

A performer runs on the main thread, takes the act's own types and answers
its own. A thrown error, an aim at nothing, and an act nobody registered each
fail the call with the reason, named. The Swift half is under
[Host-extension actions](../interface/interaction-and-actions.md#host-extension-actions).

### An event without a control

`StateUIEvents.raise` pushes an event of the application's that belongs to no
element, and `StateUIEvents.raises` declares it where its source is wired -
here the Gallery's battery:

```swift listing uikit.md.event
// Platforms/UIKit/Host/GalleryEventSources.swift
/// Declares what the gallery raises and starts watching. Said once,
/// before the application runs.
static func start() {
    // What the host raises, declared where its source is wired: a handler
    // listening for an event nothing raises is told so.
    StateUIEvents.raises(GalleryContract.batteryChanged)

    UIDevice.current.isBatteryMonitoringEnabled = true
    for name in [UIDevice.batteryLevelDidChangeNotification, UIDevice.batteryStateDidChangeNotification] {
        observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { report() }
        })
    }
    report()
}

/// Raises the battery's reading, where it has changed and there is one.
private static func report() {
    let (level, charging) = GalleryActs.battery()

    guard level > 0 else { return }
    guard lastSaid?.level != level || lastSaid?.charging != charging else { return }

    lastSaid = (level, charging)
    StateUIEvents.raise(GalleryContract.batteryChanged, level, charging)
}
```

`raise` is one door in from any thread, as a post is: the subscriptions hear
it on the UI thread soon after, in the order raised; a raise nobody hears is
an ordinary one. The Swift side subscribes with
`HostEvents.on`; see
[Host-extension events](../interface/interaction-and-actions.md#host-extension-events).

## Running

```bash
.scripts/UIKit/run-app.sh apps/HelloWorld debug "iPhone 18 Pro"
.scripts/UIKit/run-app.sh apps/Gallery debug "iPad Air 13-inch (M4)"
.scripts/UIKit/run-app.sh apps/Gallery debug "My iPhone"
```

`run-app.sh` builds the head, installs the application, starts it and follows
what it prints. Where it goes is a device's name, its identifier or its UDID,
or a simulator's name or UDID; with none named it is the simulator booted,
else an iPhone. A simulator is booted where it is not running and the
Simulator opened; a device is reached over USB or Wi-Fi, its build signed for
it. `--no-log` returns once the application has started. Everything a build
writes stays in the application's `.build/uikit/`.

In VS Code, choose **UIKit** as the host and an iPhone, an iPad or a
simulator, and press **F5**.

## Debugging

**StateUI: Debug** runs the application as `run-app.sh --debugger` does and
attaches `lldb-dap` to it: a breakpoint in the application, in StateUI or in
the host stops it from the first line, with its source, its stack and its
variables. `--debugger` starts the application held until a debugger
attaches, and writes where to `.build/uikit/debugger.json`: its process and,
on a device, the device and the bundle built, whose symbols the debugger
reads. A simulator's process is one of this Mac's; a device's is reached
through the device:

```bash
.scripts/UIKit/run-app.sh apps/Gallery debug "My iPhone" --no-log --debugger
lldb -o "device select <device from debugger.json>" \
     -o "device process attach --pid <process from debugger.json>"
```

Only a debug build can be debugged.

## Deploying

```bash
.scripts/UIKit/deploy.sh apps/Gallery artifacts/Gallery/UIKit "My iPhone"
```

`deploy.sh` builds an application's head for release as an application
bundle for the device named - a simulator, by its name or UDID, or an iPhone
or iPad, the bundle then signed for it as `build-app.sh` signs one - and lays
the bundle, `<App>UIKit.app`, in the folder named, made anew.
**StateUI: Deploy** in the editor runs it for the application and the device
chosen, and lays the bundle in `artifacts/<application>/UIKit` of the folder
that holds the application's `apps/` - a checkout's, or a project group's.

## Testing

A view exists only in an application's process, so the host's suite is an
application of tests, run in its own scene on a simulator:

```bash
.scripts/UIKit/test-uikit.sh "iPhone 18 Pro"
.scripts/UIKit/test-uikit.sh "iPad Air 13-inch (M4)"
STATEUI_FILTER=testSlider .scripts/UIKit/test-uikit.sh
```

Each test and each conformance case says as it ends where the run stands, and
the run ends with *Executed N tests, with M failures*. `STATEUI_FILTER` runs
the tests whose name holds one of its comma-separated names;
`STATEUI_UPDATE_EXPORTS=1` writes what the run says into `lib/StateUI/exports/` instead of
holding it to them. The suite runs with the simulator's accessibility off, as
a simulator starts.

`STATEUI_STALE_ONLY=1` runs only the conformance families whose verdicts in
`lib/StateUI/exports/marks/uikit` stand at another revision than
`lib/StateUI/StateUI.Conformance/revisions.txt` gives, or at none. With the
verdicts written, `STATEUI_UPDATE_DOCS=1 swift test --filter
ControlDictionaryTests` at the repository's root renders the
[platform contract](../platform-contract.md#reading-the-matrix) and
[the control dictionary](../controls/README.md) from them. In the editor,
with UIKit and a simulator chosen, **StateUI: Conformance - Rebuild all** runs
both - `UIKitConformanceTests` writing its verdicts, then the documents - and
**StateUI: Conformance - Rebuild changed** runs the stale families alone
before it renders.
