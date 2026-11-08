# Extending StateUI

StateUI has two public surfaces, and 1.0 freezes both. An application writes
the first: views and their modifiers, states, sessions and values. An author
adding to StateUI writes the second: an element of the application's own, a
value a state carries, and the application's own acts and events. The library
writes its own controls with the second surface, so an application's control
stands beside them as an equal - which is why that surface's members also
appear on every view: `setValue`, `onEvent`, `onHostEvent`, `modified` and
`node`.

Each surface is recorded line by line: `lib/StateUI/exports/api/StateUI.txt`
for the application and `StateUI.extending.txt` for an extension. The rest of
this page teaches the second one with the Gallery's own elements, whose code
runs on every host.

## An element of your own

An element has two halves. The Swift half - its contract and its view - is
the same wherever the application runs. Each host supplies the native half:
what the element is on screen, registered from the application's head before
the host runs. Each host's page shows its half under *Controls, acts, and
events registered in Swift*: [AppKit](../hosts/appkit.md),
[UIKit](../hosts/uikit.md), [Android Views](../hosts/android.md),
[WinUI](../hosts/winui.md), [GTK](../hosts/gtk.md) and [Web](../hosts/web.md).

The native half receives the same `ControlReports<Contract>` on every
host. A child drawn by its parent is a `ControlChild<Contract>`. Reading
live control values or a child, and reporting a native event, runs on
`MainActor`; a toolkit callback
enters that actor at its adapter boundary. Reporting is synchronous and
keeps the order of the native callback. Child identity can be compared and
hashed without reading its native values. Application events raised through
`StateUIEvents.raise` use the host's queue and can originate on any thread.

### The contract and the view

The Gallery's traffic light is a whole element:

```swift listing TrafficLight
// Sources/Samples/Interop/TrafficLight.swift
/// What the light can show.
///
/// A closed vocabulary, so it crosses as its member's number. The numbers are
/// this application's own contract, and every host's control mirrors them.
public enum TrafficSignal: Int32, CaseIterable, HostRepresentable {
    /// Red.
    case stop = 0

    /// Amber.
    case caution = 1

    /// Green.
    case go = 2
}

/// The gallery's own traffic light, declared: its node type, the tier it
/// wears, and its members, each with its value's type.
public enum TrafficLightContract: ElementContract {
    public static let nodeType: NodeType = "Gallery.TrafficLight"
    public static let tiers: [any Tier.Type] = [ViewContract.self]

    /// Which lamp is lit.
    public static let signal = ElementProperty<Self, TrafficSignal>("signal")

    /// A lamp was tapped, with its index from the top.
    public static let lampTapped = ElementEvent<Self, Int>("lampTapped")

    public static let members: [any ContractMember] = [signal, lampTapped]
}

/// The Swift half of the traffic light: a view whose node its contract makes.
/// `setValue` writes its property and `onEvent` hears its event; margins,
/// alignment, opacity and gestures come with `View`.
public struct TrafficLight: ElementView {
    public var node = Node(contract: TrafficLightContract.self)

    /// A light; `signal(_:)` says which lamp is lit.
    public init() {}

    /// Which lamp is lit.
    public func signal(_ value: TrafficSignal) -> Self {
        setValue(TrafficLightContract.signal, value)
    }

    /// The signal from a state, both ways: the light reads it as it is described, and a lamp the user taps lands
    /// on it.
    public func signal(_ state: Binding<TrafficSignal>) -> Self {
        setValue(TrafficLightContract.signal, whenDescribed: { state.wrappedValue })
            .onLampTapped { lamp in
                if let tapped = TrafficSignal(rawValue: Int32(lamp)) { state.wrappedValue = tapped }
            }
    }

    /// A lamp was tapped, with its index from the top.
    public func onLampTapped(_ handler: @escaping @MainActor (Int) throws -> Void) -> Self {
        onEvent(TrafficLightContract.lampTapped, handler)
    }
}
```

- **`ElementContract`** declares the element once: its `NodeType`, the tiers
  it wears - `ViewContract` brings margins, alignment, opacity and gestures -
  and its members, each a typed `ElementProperty`, `ElementEvent` or
  `ElementAct`. A member's `ElementLayer` says what kind of promise it is:
  native, adaptive, composed by StateUI or the provider's own. The library
  declares every control the same way; the [control dictionary](../controls/README.md)
  renders those declarations.
- **`Tier`** declares members many elements wear, such as a glow several of
  an application's controls share; an element lists it among its `tiers`.
  An element's own contract and its tiers are `WornContract`s: what a view
  writes, hears and is aimed with is a member of one, and the compiler
  refuses a member of an `ApplicationTier` there.
- **`HostRepresentable`** is a value that crosses to a host:
  `propValue` and `init?(propValue:)` turn it into a `PropValue` and back. A
  closed vocabulary crosses as its case's number, an author-named one as a
  `Name`, text as text, and numbers as numbers.
- **`ElementView`** is the view: its `node` is made from the contract with
  `Node(contract:)`, `setValue` writes a property, and `onEvent` hears an
  event, both by contract member. `modified` makes a copy with the node
  changed, which is what every modifier on a control is built from.

The application's contracts are `public`: a host registers by type and lives
in a module of its own.

### Properties a style wears too

A control's setters go on a protocol of its own, which its style wears too.
Then `Style<RatingBar>()` offers the same setters as `RatingBar()`, and each
setter is written once:

```swift listing extending.md.properties
// Sources/Samples/Interop/RatingBar.swift
/// The RatingBar's own properties. The control wears them and so does its
/// style, so each setter is written once.
public protocol RatingBarProperties: PropertyContainer {}

extension RatingBarProperties {
    /// How many stars are filled, 0 through the bar's stars.
    public func rating(_ value: Double) -> Modified {
        setValue(RatingBarContract.rating, value)
    }

    /// How many stars the bar has - five unless said.
    public func maximum(_ value: Double) -> Modified {
        setValue(RatingBarContract.maximum, value)
    }
}

/// A style can target the bar: a style target names the node type a style
/// resolves by - the bar's contract's.
extension RatingBar: StyleTarget {
    public static var nodeType: NodeType { RatingBarContract.nodeType }
}

/// A style of the bar offers the bar's own setters.
extension Styling: RatingBarProperties where Target == RatingBar {}
```

`PropertyContainer` is what holds properties: a control, or a style.
`StyleTarget` is a control a style can be written for, named by the node
type a style resolves by (`nodeType`, its contract's). `Styling` is the type
behind `Style<Target>`. A library control with settings a style may give has
a protocol of this kind:
`ButtonProperties`, `ColorPickerProperties`, `DatePickerProperties`,
`GridProperties`, `HStackProperties`, `ImageProperties`, `MapProperties`,
`RectangleProperties`, `ScrollViewProperties`, `StepperProperties`,
`TextEditorProperties`, `TextFieldProperties`, `TextProperties`,
`TimePickerProperties`, `ToolbarGroupProperties` and `WebViewProperties`. What a control is for -
a switch's position, a slider's value, a field's words, the place of its
cursor - whether a picker stands open, and what chooses a style's variant, a
button's role and a picker's presentation, are the control's own, never a
style's: a `Switch` has no such protocol, its style taking only what its
tiers offer.
What several controls share has one too: `ViewProperties`,
`VisualElementProperties`, `LayoutProperties`, `StackProperties`,
`ShapeProperties`, `FilledShapeProperties`, `CorneredShapeProperties` and
`TextInputProperties`. A tier stands on two sides. On the element side a
bare name says what an element is - `View`, `Layout`, `Stack`, `Shape`,
`TextInput` - and its `…Properties` protocol is the half a style wears too.
A mixin's name ends in `Element` and says what an element has: one a style
wears too stands on the property side, `FontElement` or `PaddingElement`, and
one only an element wears on the element side, `FocusElement` or
`KeyboardElement`. The control dictionary's tier pages name each one.

### A state the host walks

A property bound to a state is handed to the host with the state.
`setValue(_:on:as:)` says how it crosses, a `StatePassage`: `.journey`, walked
by the host and where the walk has got to reported back; `.oneWay`, written
to the host as it stands; `.twoWay`, written so, and what the control reports
landing back on the state; `.feed`, written by the host alone and read by the
application. A state takes only the ways its value can - a journey where the
host can walk it, a feed where it is numbers - so a flag or words walked as
a journey does not compile:

```swift listing extending.md.state
// Sources/Samples/Interop/RatingBar.swift
/// How many stars are filled, walked by the host from a state.
///
///     try await $stars.journey.move(to: 5, .eased(.milliseconds(1200))).arrived()
///
/// A `.journey`: the host walks it and reports where the walk has got to,
/// which is what `$stars.journey.value` reads. A tap does not arrive this
/// way; `.onRatingChanged(_:)` hears it.
///
/// On the control and not on `RatingBarProperties`: a style wears that
/// protocol, and a style has no state to follow.
public func rating(_ state: Binding<Double>) -> Modified {
    setValue(RatingBarContract.rating, on: state, as: .journey)
}
```

Handing the binding over reads nothing, so the view writing it is not the
state's reader ([state and reactivity](../concepts/state-and-reactivity.md)).
A change the user makes comes back as the control's event, which
`.onRatingChanged` lands on the state.

### An act aimed at it

An act of the element's own is declared in its contract and called through
an aim, which puts the element first:

```swift listing RatingBar.flash
// Sources/Samples/Interop/RatingBar.swift
/// An act of the bar's contract, aimed at one bar.
///
/// `call` puts the control's identity in argument 0, and the host half turns
/// it back into the control it made. Two bars on one page each answer to
/// their own aim.
extension Aim where Target == RatingBar {
    /// Flashes the bar this aim is on.
    public func flash() async throws {
        try await call(RatingBarContract.flash)
    }
}
```

### What a host is handed

A registration's `applies` takes the properties a host's view takes
together, such as the bar's stars with its rating, and hands them over as
`ControlValues`, read by contract member. The identities an ItemsView keeps,
in order, cross as `ItemsEntries`.

## Acts and events of the application

An act or an event with no control behind it - a log, the battery, the
network - belongs to the application. Its contract is an `ApplicationTier`:

```swift listing GalleryContract
// Sources/Samples/Interop/GalleryContract.swift
/// The gallery's own acts and events - the ones with no control behind them.
///
/// A host registers a function or a raise under each name, and this declares
/// what each one takes, answers and carries, the way the library declares its
/// own. The names are the APPLICATION's, so they are the same wherever it
/// runs; what answers them is the host's.
public enum GalleryContract: ApplicationTier {
    public static let name = "Gallery"

    /// Writes a line to the platform's own log, where its tools read it.
    public static let log = ElementAct<Self, String, Void>("log")

    /// The battery's level, 0 through 1, and whether it is charging.
    public static let batteryLevel = ElementAct<Self, Void, (Double, Bool)>("batteryLevel")

    /// Declared here and registered nowhere: calling it shows what an act no
    /// performer answers does.
    public static let nobody = ElementAct<Self, Void, Void>("nobody")

    /// The battery reported: its level and whether it is charging.
    public static let batteryChanged =
        ElementEvent<Self, (Double, Bool)>("batteryChanged")

    /// The network came or went: whether the internet is reachable.
    public static let connectivityChanged =
        ElementEvent<Self, Bool>("connectivityChanged")

    public static let members: [any ContractMember] = [
        log, batteryLevel, nobody, batteryChanged, connectivityChanged,
    ]
}
```

`application.call` performs an act and awaits what it answers, as the
contract declares it; `application.tell` asks for it without waiting. A page
hears an event with `.onHostEvent`, for as long as it stands; `HostEvents.on`
hears one from anywhere and answers a `HostEventSubscription`, which
`cancel()` ends:

```swift
public enum NotesContract: ApplicationTier {
    public static let name = "Notes"

    public static let exportDocument = ElementAct<Self, String, String>("exportDocument")
    public static let synced = ElementEvent<Self, Int>("synced")

    public static let members: [any ContractMember] = [exportDocument, synced]
}

struct ExportPage: View {
    @Environment(\.application) private var application
    @State private var said = ""

    var body: some View {
        VStack {
            Button("Export").onClicked(policy: .ignoreWhileRunning) {
                said = try await application.call(NotesContract.exportDocument, "draft-7")
            }
            Text(said)
        }
        .onHostEvent(NotesContract.synced) { count in said = "\(count) synced" }
    }
}
```

[Interaction and actions](interaction-and-actions.md#host-extension-actions)
says what a call throws, and each host's page shows how its head performs an
act and raises an event.

## A value of your own

A state the host carries holds a `StateValue`: a value that lies on the
state's image and back. An application's own value conforms to `LaneValue`,
which lies as numbers, one lane each; text is `String`'s alone. `Walked` adds
nothing but a half way, which a journey needs, so `$temperature.journey`
exists:

```swift
public struct Temperature: Walked {
    public var degrees: Double

    public init(degrees: Double) { self.degrees = degrees }

    public var carried: StateCarried { .lanes([degrees]) }

    public init?(carried: StateCarried) {
        guard case .lanes(let lanes) = carried, lanes.count == 1 else { return nil }
        degrees = lanes[0]
    }

    public static var lanes: Int { 1 }
}
```

- **`StateCarried`** is the image: lanes or text.
- **`LaneKind`** is what a host reads the lanes as - numbers unless the type
  says a Boolean, a choice, a color or a material.
- **`StateChoice`** is an enum whose `Int32` raw value is its one lane, a
  closed vocabulary carried as its case's number.

Every conversion reads alike: `carried` and `init?(carried:)`, `propValue`
and `init?(propValue:)`, `persistentValue` and `init?(persistentValue:)`.
The design note [three protocols, three
capabilities](../design/core/state.md#three-protocols-three-capabilities)
says why a value has three protocols and not one.
