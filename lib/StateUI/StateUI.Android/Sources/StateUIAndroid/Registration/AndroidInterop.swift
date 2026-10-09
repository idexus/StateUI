// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// What an application registers with this host beside the elements the host realizes itself: its controls, the
/// acts it performs and the events it raises, said before the host starts.
/// Design: docs/design/platforms/android/runtime.md#the-applications-own-acts
@MainActor
enum AndroidInterop {
    /// The application's acts, performed where no act of the library's answers the call (`InteropActs`).
    static let acts = InteropActs<AndroidView>()
}

/// A control of the application's own on this host: an object that holds the Android view it shows.
///
/// The application makes the view with a Java class of its own, beside its head, through `Java` - handed the
/// activity as `StateUIAndroid.context` - and hands the reference over: the host places, sizes and shows the view as
/// it does its own; the view's own `onMeasure` is what the host measures.
@MainActor
public protocol AndroidControl: AnyObject {
    /// The Android view the control shows, which the control holds.
    var view: JavaObject { get }
}

/// The controls an application adds to this host - its own elements, each realized with a control of its own.
///
/// Said once, from the application's Android head as its library loads, before `StateUIAndroid.load(_:)`.
@MainActor
public enum StateUIControls {
    /// Adds an element of the APPLICATION'S OWN, realized with a control of its own: how the control is made, and
    /// which of the element's members it takes and raises. A library element this host does not realize - a `Map`,
    /// its markers drawn through `children` - is added the same way.
    ///
    ///     StateUIControls.add(TrafficLightContract.self, create: { reports -> TrafficLightView in
    ///         let light = TrafficLightView()
    ///         light.onLampTapped = { index in reports.raise(TrafficLightContract.lampTapped, index) }
    ///         return light
    ///     }) { light in
    ///         light.property(TrafficLightContract.signal) { view, signal in
    ///             view.signal = signal ?? .stop
    ///         }
    ///     }
    ///
    /// What every view shares - margins, alignment, opacity, gestures, the frame reports - this host applies around
    /// the view, exactly as it does for the elements it realizes itself. A second registration of a contract
    /// replaces the first.
    ///
    /// - Parameters:
    ///   - contract: the element's contract.
    ///   - create: makes the control, once per element, handed what it reports through.
    ///   - members: registers the members the control takes and raises.
    public static func add<Realized: ElementContract, Made: AndroidControl>(
        _ contract: Realized.Type,
        create: @escaping (AndroidReports<Realized>) -> Made,
        members: (AndroidRegistration<Realized, Made>) -> Void = { _ in }
    ) {
        AndroidRegistrations.registry.add(
            contract,
            create: { reports in AndroidHostedView(create(AndroidReports(reports))) },
            members: { registration in members(AndroidRegistration(registration)) })
    }
}

/// The acts an application performs on this host - what its own `stateUICall` reaches.
///
/// Said once, from the application's Android head as its library loads - `JNI_OnLoad` runs on the UI thread -
/// before `StateUIAndroid.load(_:)`.
@MainActor
public enum StateUIActs {
    /// Performs an act of the application's - one no control stands behind - when the application calls it with
    /// `stateUICall`.
    ///
    /// The values are the act's own, as its contract declares them, so a performer of another shape does not
    /// compile and a call carrying anything else fails with the reason rather than running on a guess. A second
    /// registration of an act replaces the first.
    ///
    /// - Parameters:
    ///   - act: the member, written with its contract.
    ///   - perform: given the arguments the contract declares, answering the values it declares. What it throws
    ///     fails the call, and the caller throws that reason. A performer may await, and the call is answered once
    ///     it returns.
    public static func add<
        Owner: ApplicationTier, each Argument: HostRepresentable, each Answer: HostRepresentable
    >(
        _ act: ElementAct<Owner, (repeat each Argument), (repeat each Answer)>,
        _ perform: @escaping @MainActor (repeat each Argument) async throws -> (repeat each Answer)
    ) {
        AndroidInterop.acts.add(act, perform)
    }

    /// Performs an act AIMED at one of the application's own elements, when the application calls it through an
    /// `Aim`: the performer is handed the element's control. An aim at nothing, or at an element no longer on
    /// screen, fails the call with that reason.
    ///
    ///     StateUIActs.add(RatingBarContract.flash, on: RatingBarView.self) { bar in
    ///         bar.flash()
    ///     }
    ///
    /// - Parameters:
    ///   - act: the member, written with its contract.
    ///   - control: the class the application's registration makes for the element.
    ///   - perform: given the element's control and the arguments the contract declares, answering the values it
    ///     declares.
    public static func add<
        Owner: Contract, Made: AndroidControl, each Argument: HostRepresentable, each Answer: HostRepresentable
    >(
        _ act: ElementAct<Owner, (repeat each Argument), (repeat each Answer)>,
        on control: Made.Type,
        _ perform: @escaping @MainActor (Made, repeat each Argument) async throws -> (repeat each Answer)
    ) {
        AndroidInterop.acts.add(act, control: { ($0 as? AndroidHostedView<Made>)?.control }, perform)
    }
}

/// The events an application raises on this host, which every `HostEvents.on` of the event hears.
public enum StateUIEvents {
    /// Says the application raises `event`, so the host declares it realized.
    ///
    /// Said once, where the application registers its acts.
    @MainActor
    public static func raises<Owner: ApplicationTier, Payload>(_ event: ElementEvent<Owner, Payload>) {
        AndroidRegistrations.registry.raises(event)
    }

    /// Raises `event` with the values its contract declares, on the UI thread; how many handlers heard it.
    @discardableResult
    @MainActor
    public static func raise<Owner: ApplicationTier, each Value: HostRepresentable>(
        _ event: ElementEvent<Owner, (repeat each Value)>,
        _ value: repeat each Value
    ) -> Int {
        CoreLink().raise(event, repeat each value)
    }
}

/// What an element of the APPLICATION'S OWN tells the application: an event of its own, and a value its user
/// changed. Handed to the control where it is made, so the control names members of its contract and never a
/// handler.
public struct AndroidReports<Realized: ElementContract> {
    private let reports: Reports<Realized>

    init(_ reports: Reports<Realized>) {
        self.reports = reports
    }

    /// Raises one of the element's own events with the values its contract declares.
    ///
    /// - Parameters:
    ///   - event: the member, written with its contract.
    ///   - value: what it carries, in the order its contract declares.
    public func raise<each Value: HostRepresentable>(
        _ event: ElementEvent<Realized, (repeat each Value)>,
        _ value: repeat each Value
    ) {
        reports.raise(event, repeat each value)
    }

    /// A value the USER changed: it lands on the state the element's value is carried in, and the event is raised
    /// with it.
    ///
    /// - Parameters:
    ///   - property: the value's member, written with its contract.
    ///   - value: what the user made it.
    ///   - event: the member the element raises for that change.
    public func report<Owner: Contract, Raised: Contract, Value: HostRepresentable>(
        _ property: ElementProperty<Owner, Value>,
        _ value: Value,
        as event: ElementEvent<Raised, Value>
    ) {
        reports.report(property, value, as: event)
    }
}

/// How an application's own element is realized on this host, member by member: the properties its control takes,
/// and the events of its own it raises.
@MainActor
public final class AndroidRegistration<Realized: ElementContract, Made: AndroidControl> {
    private let registration: Registration<Realized, AndroidHostedView<Made>>

    init(_ registration: Registration<Realized, AndroidHostedView<Made>>) {
        self.registration = registration
    }

    /// A property the control takes, handed over as the type its contract declares - nil where the value is no
    /// longer described. A member of the element's contract or of a tier it wears; any other is refused, and said
    /// once.
    ///
    /// - Parameters:
    ///   - member: the property, written with its contract.
    ///   - apply: puts the value on the control.
    public func property<Owner: Contract, Value: HostRepresentable>(
        _ member: ElementProperty<Owner, Value>,
        _ apply: @escaping (Made, Value?) -> Void
    ) {
        registration.property(member) { hosted, value in apply(hosted.control, value) }
    }

    /// An event the control raises through its reports - recorded, so the core knows this host reports it.
    ///
    /// - Parameter event: the member, written with its contract.
    public func raises<Owner: Contract, Payload>(_ event: ElementEvent<Owner, Payload>) {
        registration.raises(event)
    }

    /// The children of one contract the control draws itself - a map's markers - handed over whole, in the tree's
    /// order, whenever the element's children change: one added, moved, taken away, or given another value. Such a
    /// child has no view of its own. `members` are what the control realizes of each child - a property or an
    /// event of the child's contract or of a tier it wears; anything else is left out, and said once.
    ///
    ///     map.children(MarkerContract.self, members: [MarkerContract.location, MarkerContract.selected]) { control, markers in
    ///         control.show(markers)
    ///     }
    ///
    /// - Parameters:
    ///   - contract: the children's contract.
    ///   - members: what the control realizes of each child, written with their contracts.
    ///   - apply: hands the control every child of the contract.
    public func children<Child: ElementContract>(
        _ contract: Child.Type,
        members: [any ContractMember],
        _ apply: @escaping (Made, [AndroidChild<Child>]) -> Void
    ) {
        registration.children(contract, members: members) { hosted, children in
            apply(hosted.control, children.map(AndroidChild.init))
        }
    }
}

/// A child element the control draws itself - a map's marker: its values as the types its contract declares, and the
/// reports its events leave through. Two are equal when they are the same child, for as long as it lives, so a
/// control keeps what it drew for one by it.
public struct AndroidChild<Child: ElementContract>: Hashable {
    private let child: ChildElement<Child>

    init(_ child: ChildElement<Child>) {
        self.child = child
    }

    /// One of the child's values, as the type its contract declares - nil where it is not described.
    ///
    /// - Parameter property: the member, written with its contract.
    /// - Returns: the value, or nil.
    public func value<Owner: Contract, Value: HostRepresentable>(_ property: ElementProperty<Owner, Value>) -> Value? {
        child.value(property)
    }

    /// What the child's events and the user's values on it leave through.
    public var reports: AndroidReports<Child> {
        AndroidReports(child.reports)
    }
}
