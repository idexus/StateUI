// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// What an APPLICATION registers with this host, beside the elements the host
/// realizes itself: the acts it performs and the events it raises.
///
/// An application says these once, before `AppKitHost.run(resourceDirectory:applicationIcon:)`,
/// from its own host file. Nothing new reaches the core: an act arrives as the
/// call the application already made through `application.call` or an `Aim`, and an
/// event leaves as the raise every `HostEvents.on` already hears.
///
/// The performers live here rather than on the performer itself because an
/// application registers them before any renderer exists, and the renderer is
/// what turns an aimed act's identity back into a view.
@MainActor
enum AppKitInterop {
    /// The application's acts, performed where no act of the library's answers the call (`InteropActs`).
    static let acts = InteropActs<NSView>()
}

/// The acts an application performs on this host - what its own calls,
/// `application.call` and an `Aim`, reach.
///
/// Said once, from the application's AppKit head, before
/// `AppKitHost.run(resourceDirectory:applicationIcon:)`.
@MainActor
public enum StateUIActs {
    /// Performs an act of the application's - one no control stands behind -
    /// when the application calls it with `application.call`.
    ///
    /// The values are the act's own, as its contract declares them, so a
    /// performer of another shape does not compile and a call carrying
    /// anything else fails with the reason rather than running on a guess.
    ///
    ///     StateUIActs.add(GalleryContract.log) { line in
    ///         Logger(subsystem: "com.stateui.gallery", category: "Gallery").notice("\(line, privacy: .public)")
    ///     }
    ///
    /// A second registration of an act replaces the first.
    ///
    /// - Parameters:
    ///   - act: the member, written with its contract.
    ///   - perform: given the arguments the contract declares, answering the
    ///     values it declares. What it throws fails the call, and the caller
    ///     throws that reason. A performer may await, and the call is answered
    ///     once it returns.
    public static func add<
        Owner: ApplicationTier, each Argument: HostRepresentable, each Answer: HostRepresentable
    >(
        _ act: ElementAct<Owner, (repeat each Argument), (repeat each Answer)>,
        _ perform: @escaping @MainActor (repeat each Argument) async throws -> (repeat each Answer)
    ) {
        AppKitInterop.acts.add(act, perform)
    }

    /// Performs an act AIMED at one of the application's own elements, when
    /// the application calls it through an `Aim`.
    ///
    /// The aim puts the element's identity in argument 0 and this host turns
    /// it back into the view its registration made - so the performer is
    /// handed the view itself. An aim at nothing, or at an element no longer
    /// on screen, fails the call with that reason.
    ///
    ///     StateUIActs.add(RatingBarContract.flash, on: RatingBarView.self) { bar in
    ///         bar.flash()
    ///     }
    ///
    /// - Parameters:
    ///   - act: the member, written with its contract.
    ///   - view: the class this host makes for the element.
    ///   - perform: given the element's view and the arguments the contract
    ///     declares, answering the values it declares. A performer may await,
    ///     and the call is answered once it returns.
    public static func add<
        Owner: WornContract, Made: NSView,
        each Argument: HostRepresentable, each Answer: HostRepresentable
    >(
        _ act: ElementAct<Owner, (repeat each Argument), (repeat each Answer)>,
        on view: Made.Type,
        _ perform: @escaping @MainActor (Made, repeat each Argument) async throws -> (repeat each Answer)
    ) {
        AppKitInterop.acts.add(act, control: { $0 as? Made }, perform)
    }
}

/// The events an application raises through this host - the ones no control
/// raises, heard by every `HostEvents.on`.
public enum StateUIEvents {
    /// Declares an event of the application's this host raises, where its
    /// source is wired: a handler listening for an event nothing declared is
    /// told, once, that it will not hear it.
    ///
    /// Said once, from the application's AppKit head, before
    /// `AppKitHost.run(resourceDirectory:applicationIcon:)`.
    ///
    ///     StateUIEvents.declares(GalleryContract.batteryChanged)
    ///
    /// - Parameter event: the member, written with its contract.
    @MainActor
    public static func declares<Owner: ApplicationTier, Payload>(_ event: ElementEvent<Owner, Payload>) {
        AppKitRegistrations.registry.declares(event)
    }

    /// Raises an event of the application's - one no control raises - with the values its contract declares, from
    /// any thread: every `HostEvents.on` subscription to the member hears it in a job of the UI thread's soon after,
    /// in the order raised. A raise nobody hears is an ordinary one.
    ///
    ///     StateUIEvents.raise(GalleryContract.batteryChanged, level, charging)
    ///
    /// - Parameters:
    ///   - event: the member, written with its contract.
    ///   - value: what it carries, in the order its contract declares.
    public nonisolated static func raise<Owner: ApplicationTier, each Value: HostRepresentable>(
        _ event: ElementEvent<Owner, (repeat each Value)>,
        _ value: repeat each Value
    ) {
        CoreLink().raise(event, repeat each value)
    }
}

/// The controls an application adds to this host - its own elements, each
/// realized with a view of its own.
///
/// Said once, from the application's AppKit head, before
/// `AppKitHost.run(resourceDirectory:applicationIcon:)`.
@MainActor
public enum StateUIControls {
    /// Adds an element of the APPLICATION'S OWN, realized with a view of its own:
    /// how the view is made, and which of the element's members it takes and
    /// raises. A library element - a `Map`, its markers drawn through `children` -
    /// is added the same way.
    ///
    /// The Swift half is the application's already - a contract, and a `View`
    /// whose node that contract makes. This is the other half: what the
    /// element is on screen.
    ///
    /// The view's own class is named where the closure makes it, so every
    /// applier below is handed that class rather than a bare `NSView`.
    ///
    ///     StateUIControls.add(TrafficLightContract.self, create: { reports -> TrafficLightView in
    ///         let light = TrafficLightView()
    ///         light.onLampTapped = { index in
    ///             reports.raise(TrafficLightContract.lampTapped, index)
    ///         }
    ///         return light
    ///     }) { light in
    ///         light.property(TrafficLightContract.signal) { view, signal in
    ///             view.signal = signal ?? .stop
    ///         }
    ///     }
    ///
    /// What every view shares - margins, alignment, opacity, gestures, the
    /// frame reports - this host applies around the view, exactly as it does
    /// for the elements it realizes itself. A second registration of a
    /// contract replaces the first.
    ///
    /// - Parameters:
    ///   - contract: the element's contract.
    ///   - create: makes the view, once per element, handed what it reports
    ///     through.
    ///   - members: registers the members the view takes and raises.
    public static func add<Realized: ElementContract, Made: NSView>(
        _ contract: Realized.Type,
        create: @escaping @MainActor (ControlReports<Realized>) -> Made,
        members: @MainActor (AppKitRegistration<Realized, Made>) -> Void = { _ in }
    ) {
        AppKitRegistrations.registry.add(
            contract,
            create: create,
            members: { registration in members(AppKitRegistration(registration)) })
    }
}

/// How an application's own element is realized on this host, member by
/// member: the properties its view takes, and the events of its own it raises.
@MainActor
public final class AppKitRegistration<Realized: ElementContract, Made: NSView> {
    private let registration: Registration<Realized, Made>

    /// Made where the element is registered.
    init(_ registration: Registration<Realized, Made>) {
        self.registration = registration
    }

    /// A property the view takes, handed over as the type its contract
    /// declares - nil where the value is no longer described.
    ///
    /// A member of the element's contract or of a tier it wears; any other is
    /// refused, and said once.
    ///
    /// - Parameters:
    ///   - member: the property, written with its contract.
    ///   - apply: puts the value on the view.
    public func property<Owner: WornContract, Value: HostRepresentable>(
        _ member: ElementProperty<Owner, Value>,
        _ apply: @escaping @MainActor (Made, Value?) -> Void
    ) {
        registration.property(member, apply)
    }

    /// Properties the view takes together, handed over whole whenever any of them changes: each as the type its
    /// contract declares, and whether it changed - a view that must take one before another, a web view its agent
    /// before its page, takes them at once. Members of the element's contract or of the tiers it wears; any other is
    /// left out, and said once.
    ///
    ///     web.applies(WebViewContract.userAgent, WebViewContract.source) { view, values in
    ///         view.show(values[WebViewContract.source], userAgent: values[WebViewContract.userAgent])
    ///     }
    ///
    /// - Parameters:
    ///   - properties: the properties, written with their contracts.
    ///   - apply: puts the values on the view.
    public func applies<each Owner: WornContract, each Value: HostRepresentable>(
        _ properties: repeat ElementProperty<each Owner, each Value>,
        apply: @escaping @MainActor (Made, ControlValues<Realized>) -> Void
    ) {
        registration.applies(repeat each properties) { made, values in apply(made, ControlValues(values)) }
    }

    /// An event the view raises through its reports - recorded, so the core
    /// knows this host reports it.
    ///
    /// - Parameter event: the member, written with its contract.
    public func declares<Owner: WornContract, Payload>(_ event: ElementEvent<Owner, Payload>) {
        registration.declares(event)
    }

    /// The children of one contract the view draws itself - a map's markers - handed over whole, in the tree's order,
    /// whenever the element's children change: one added, moved, taken away, or given another value. Such a child has
    /// no view of its own. `properties` and `events` are what the view realizes of each child - members of the child's
    /// contract or of a tier it wears; any other is left out, and said once.
    ///
    ///     map.children(MarkerContract.self, properties: MarkerContract.location, events: MarkerContract.selected) {
    ///         view, markers in
    ///         view.show(markers)
    ///     }
    ///
    /// - Parameters:
    ///   - contract: the children's contract.
    ///   - properties: the children's properties the view realizes, written with their contracts.
    ///   - events: the children's events the view raises, written with their contracts.
    ///   - apply: hands the view every child of the contract.
    public func children<
        Child: ElementContract, each PropertyOwner: WornContract, each Value: HostRepresentable,
        each EventOwner: WornContract, each Payload
    >(
        _ contract: Child.Type,
        properties: repeat ElementProperty<each PropertyOwner, each Value>,
        events: repeat ElementEvent<each EventOwner, each Payload>,
        apply: @escaping @MainActor (Made, [ControlChild<Child>]) -> Void
    ) {
        registration.children(contract, properties: repeat each properties, events: repeat each events) { made, children in
            apply(made, children)
        }
    }
}

#endif
