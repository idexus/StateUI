# AppKit host

The AppKit host renders a StateUI application with AppKit controls on macOS. It
runs in the same process as the application module and the library, and applies
the typed sparse patches of the [host contract](host-contract.md) directly - no
Wire encoding stands between them.

```text
lib/StateUI.AppKit/
  Sources/    StateUIAppKit: the renderer, windows, sessions and the registries
  Tests/      the host's suite
.scripts/AppKit/
  build-gallery-appkit.sh      the Gallery's bundle, in apps/Gallery/.build-appkit
apps/<App>/Platforms/AppKit/
  main.swift                   the application's AppKit head
```

An application's AppKit head is `Platforms/AppKit/main.swift`. It registers the
application, then starts the host:

```swift quote
import NotesUI
import StateUIAppKit

stateui_app_register()

// StateUIControls.add(…), StateUIActs.add(…) and StateUIEvents
// sources go here, before the host runs.

StateUIAppKit.run(resourceDirectory: resources, applicationIcon: icon)
```

Every AppKit build of an application defines the `APPKIT` compilation
condition; Swift written for this host alone stands under `#if APPKIT`. See
[Project structure and development](development.md).

## Controls, acts, and events registered in Swift

An application extends the host from its AppKit head. Registrations run before
`StateUIAppKit.run`, on the main thread. Each name carries the application's own
prefix, such as `Notes.`, so it never meets a name the host adds later.
Registering a name again replaces the earlier registration. The registries live
in `StateUIAppKit`; payloads, arguments and answers are `PropValue`s, the values
the Swift side reads.

The Swift half of each registration is ordinary StateUI API, the same one the
[MAUI host](maui-host.md#a-control) registers against: a registration on either
host answers the same `Node(type:)`, `setValue`, `onEvent`, `stateUICall` and
`HostEvents.on`. The Gallery's "AppKit interop" group, compiled under
`#if APPKIT`, shows every kind of registration working; its AppKit halves are in
`apps/Gallery/Platforms/AppKit/`.

### A control

`StateUIControls.add` names an application's own `NSView` under a node type:

```swift quote
public typealias StateUIRaise =
    @MainActor (_ sender: NSView, _ event: Event, _ payload: [PropValue]) -> Void

public static func add<Control: NSView>(
    _ type: NodeType,
    create: @escaping @MainActor (_ raise: @escaping StateUIRaise) -> Control,
    apply: (@MainActor (_ control: Control, _ properties: [Prop: PropValue]) -> Void)? = nil,
    properties: [Prop: ReferenceWritableKeyPath<Control, Double>] = [:],
    content: (@MainActor (_ control: Control, _ child: NSView?) -> Void)? = nil)
```

- **`create`** makes the control once per element. It wires the control's
  events through the `StateUIRaise` it receives:
  `raise(sender, event, payload)`.
- **`apply`** runs on every message that touches the control and receives only
  what arrived: an absent property did not change, and `.nothing` clears one.
- **`properties`** declares the control's own numbers by key path. The host
  assigns them, and journeys and styles reach them. See
  [A control's own properties](#a-controls-own-properties).
- **`content`** places the one child view the Swift side describes into the
  control. It is called only when the slot changes hands.

The host keeps a registered control between renders by identity, and applies
the shared view properties after `apply`: margins, opacity, sizing, gestures,
focus, and frame reports. A node type with no registration draws the
unsupported-control marker.

`TrafficLightView` below is the application's own `NSView`, with a `phase`
property, an `onTap` callback, and a `flash(times:)` method:

```swift quote
StateUIControls.add("Notes.TrafficLight",
    create: { raise in
        let light = TrafficLightView()
        light.onTap = { index in raise(light, "lightTapped", [.number(Double(index))]) }
        return light
    },
    apply: { light, properties in
        if let phase = properties["phase"]?.string {
            light.phase = phase
        }
    })

StateUIActs.add("Notes.FlashLight") { arguments in
    if let light = StateUIActs.target(of: arguments) as? TrafficLightView {
        light.flash(times: Int(arguments.dropFirst().first?.number ?? 1))
    }
    return []
}
```

The Swift half describes the same node type, property, event and act - the
`TrafficLight` and `Crossing` of the [MAUI host](maui-host.md#a-control),
unchanged. `Aim.target` puts the control's identity in argument 0, and
`StateUIActs.target(of:)` turns it back into the control. It answers nil when
the control has left the tree before the host performs the act.

A Swift `Style` can target the control once its Swift struct conforms to
`StyleTarget`. Styles resolve on the Swift side, so the control arrives with
the style's values already among its own; the registration needs nothing for
it.

### A control's own properties

A number the control holds can be declared by key path instead of applied by
hand. The host then assigns it whenever a message carries it, moves it along a
journey frame by frame, and reads it back for a state handed over `.inOut`:

```swift quote
StateUIControls.add("Notes.Gauge",
    create: { _ in GaugeView() },
    properties: ["level": \GaugeView.level])
```

The Swift half - `Gauge().level($level)` over
`setValue(.gaugeLevel, on: state, mode: .inOut, kind: .property)` - is the one
under [A control's own properties](maui-host.md#a-controls-own-properties).
Handing `$level` to the control makes the gauge a host-carried reader: a write
to `level`, and its journey, reaches the control without rebuilding the view
that wrote it; see [Motion and journeys](motion-and-journeys.md). A property
that is not a number is `apply`'s.

### An act

`StateUIActs.add` registers a function that Swift calls by name with
`stateUICall` or `stateUISend`:

```swift quote
public static func add(
    _ act: Act,
    _ performer: @escaping @MainActor (_ arguments: [PropValue]) async throws -> [PropValue])
```

```swift quote
StateUIActs.add("Notes.BatteryLevel") { _ in
    [.number(Battery.level)]
}

StateUIActs.add("Notes.Export") { arguments in
    let location = try await Exporter.save(arguments.first?.string ?? "")
    return [.string(location)]
}
```

- **Where it runs.** A performer runs on the main thread, where AppKit draws,
  and an async one is awaited there.
- **Its values.** It reads its arguments in the order the Swift call gave them,
  with `PropValue`'s accessors - `string`, `number`, `bool`, `enumeration`,
  `name`, `values` - and answers `PropValue`s, empty when it has nothing to
  say.
- **Failure.** A thrown error fails the act: the awaiting Swift handler throws
  `StateUIError` with the error's description.
- **Scope.** A registration never shadows an act of the host's own. An act
  nobody registered fails with that reason.

The Swift half is under
[Host-extension actions](interaction-and-actions.md#host-extension-actions).

### An event without a control

`StateUIEvents.raise` pushes a named event that belongs to no element, such as
a power or network change:

```swift quote
public static func raise(_ event: Event, _ payload: [PropValue] = [])
```

```swift quote
NotificationCenter.default.addObserver(
    forName: .NSProcessInfoPowerStateDidChange, object: nil, queue: nil
) { _ in
    StateUIEvents.raise("Notes.LowPowerChanged",
        [.bool(ProcessInfo.processInfo.isLowPowerModeEnabled)])
}
```

`raise` is safe from any thread: it reaches the Swift side on the main thread.
It drops an event nobody subscribed to, and one raised before the first
interface exists. The Swift side subscribes with `HostEvents.on`; see
[Host-extension events](interaction-and-actions.md#host-extension-events).
