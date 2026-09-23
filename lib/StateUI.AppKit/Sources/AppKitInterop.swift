// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI

/// What an APPLICATION registers with this host, beside the elements the host
/// realizes itself: the acts it performs and the events it raises.
///
/// An application says these once, before `StateUIAppKit.run(resourceDirectory:applicationIcon:)`,
/// from its own host file. Nothing new reaches the core: an act arrives as the
/// call the application already made through `stateUICall` or an `Aim`, and an
/// event leaves as the raise every `HostEvents.on` already hears.
///
/// The performers live here rather than on the performer itself because an
/// application registers them before any renderer exists, and the renderer is
/// what turns an aimed act's identity back into a view.
@MainActor
enum AppKitInterop {
    /// What answers one act, and what it needs to answer it.
    enum Performer {
        /// An act of the application's, given the values it was called with.
        case application(([HostValue]) throws -> [HostValue])

        /// An act aimed at one element, given that element's view and the
        /// values after the identity the aim put in argument 0.
        case aimed((NSView, [HostValue]) throws -> [HostValue])
    }

    /// The performers, by the act's name - read where no act of the library's
    /// own answers the call.
    static var performers: [Act: Performer] = [:]

    /// Forgets every performer. For a test, which registers its own and must
    /// not leave them standing for the next one.
    static func forgetPerformers() {
        performers = [:]
    }
}

/// The acts an application performs on this host - what its own calls,
/// `stateUICall` and an `Aim`, reach.
///
/// Said once, from the application's AppKit head, before
/// `StateUIAppKit.run(resourceDirectory:applicationIcon:)`. The MAUI host's
/// registry of the same name takes the same acts by their names.
@MainActor
public enum StateUIActs {
    /// Performs an act of the application's - one no control stands behind -
    /// when the application calls it with `stateUICall`.
    ///
    /// The values are the act's own, as its contract declares them, so a
    /// performer of another shape does not compile and a call carrying
    /// anything else fails with the reason rather than running on a guess.
    ///
    ///     StateUIActs.add(GalleryContract.setClipboard) { text in
    ///         NSPasteboard.general.clearContents()
    ///         NSPasteboard.general.setString(text, forType: .string)
    ///     }
    ///
    /// A second registration of an act replaces the first.
    ///
    /// - Parameters:
    ///   - act: the member, written with its contract.
    ///   - perform: given the arguments the contract declares, answering the
    ///     values it declares. What it throws fails the call, and the caller
    ///     throws that reason.
    public static func add<
        Owner: ApplicationTier, each Argument: HostRepresentable, each Answer: HostRepresentable
    >(
        _ act: ElementAct<Owner, (repeat each Argument), (repeat each Answer)>,
        _ perform: @escaping @MainActor (repeat each Argument) throws -> (repeat each Answer)
    ) {
        AppKitInterop.performers[act.token] = .application { values in
            guard let arguments = MemberValues.decode(values, as: repeat (each Argument).self) else {
                throw StateUIError(message: "`\(act.name)` was called with "
                    + "\(values.count) value(s), and its contract declares "
                    + MemberValues.describe(repeat (each Argument).self))
            }

            let answer = try perform(repeat each arguments)
            return MemberValues.encode(repeat each answer)
        }
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
    ///     declares, answering the values it declares.
    public static func add<
        Owner: Contract, Made: NSView,
        each Argument: HostRepresentable, each Answer: HostRepresentable
    >(
        _ act: ElementAct<Owner, (repeat each Argument), (repeat each Answer)>,
        on view: Made.Type,
        _ perform: @escaping @MainActor (Made, repeat each Argument) throws -> (repeat each Answer)
    ) {
        AppKitInterop.performers[act.token] = .aimed { native, values in
            guard let made = native as? Made else {
                throw StateUIError(message: "`\(act.name)` is aimed at a \(type(of: native)), "
                    + "and it performs on \(Made.self)")
            }

            guard let arguments = MemberValues.decode(values, as: repeat (each Argument).self) else {
                throw StateUIError(message: "`\(act.name)` was called with "
                    + "\(values.count) value(s), and its contract declares "
                    + MemberValues.describe(repeat (each Argument).self))
            }

            let answer = try perform(made, repeat each arguments)
            return MemberValues.encode(repeat each answer)
        }
    }
}

/// The events an application raises through this host - the ones no control
/// raises, heard by every `HostEvents.on`.
///
/// The MAUI host's registry of the same name raises the same events by their
/// names.
public enum StateUIEvents {
    /// Raises an event of the application's - one no control raises - with the
    /// values its contract declares.
    ///
    /// Every `HostEvents.on` subscription to the member hears it, each handler
    /// queued on this library's executor. Safe from any thread, so an
    /// application wires its sources where the platform reports them.
    ///
    ///     StateUIEvents.raise(GalleryContract.batteryChanged, level, charging)
    ///
    /// - Parameters:
    ///   - event: the member, written with its contract.
    ///   - value: what it carries, in the order its contract declares.
    /// - Returns: how many subscriptions heard it - a raise nobody hears is an
    ///   ordinary zero.
    @discardableResult
    public nonisolated static func raise<Owner: ApplicationTier, each Value: HostRepresentable>(
        _ event: ElementEvent<Owner, (repeat each Value)>,
        _ value: repeat each Value
    ) -> Int {
        CoreLink().raise(event, repeat each value)
    }
}

/// The controls an application adds to this host - its own elements, each
/// realized with a view of its own.
///
/// Said once, from the application's AppKit head, before
/// `StateUIAppKit.run(resourceDirectory:applicationIcon:)`. The MAUI host's
/// registry of the same name adds the same elements by their node types.
@MainActor
public enum StateUIControls {
    /// Adds an element of the APPLICATION'S OWN, realized with a view of its own:
    /// how the view is made, and which of the element's members it takes and
    /// raises.
    ///
    /// The Swift half is the application's already - a contract, and a `View`
    /// whose node that contract makes. This is the other half, and the only
    /// one this host was missing: what the element IS on screen.
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
        create: @escaping (AppKitReports<Realized>) -> Made,
        members: (AppKitRegistration<Realized, Made>) -> Void = { _ in }
    ) {
        AppKitRegistrations.registry.add(
            contract,
            create: { reports in create(AppKitReports(reports)) },
            members: { registration in members(AppKitRegistration(registration)) })
    }
}

/// What an element of the APPLICATION'S OWN tells the application: an event of
/// its own, and a value its reader changed.
///
/// Handed to the view where the view is made, so the view names members of its
/// contract and never a handler.
public struct AppKitReports<Realized: ElementContract> {
    private let reports: Reports<Realized>

    /// Made where the element's view is.
    init(_ reports: Reports<Realized>) {
        self.reports = reports
    }

    /// Raises one of the element's own events with the values its contract
    /// declares.
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

    /// A value the READER changed: it lands on the state the element's value
    /// is carried in, and the event is raised with it - so an application
    /// hears the change once, whether it holds the value in a state or in a
    /// handler.
    ///
    /// - Parameters:
    ///   - property: the value's member, written with its contract.
    ///   - value: what the reader made it.
    ///   - event: the member the element raises for that change.
    public func report<Owner: Contract, Raised: Contract, Value: HostRepresentable>(
        _ property: ElementProperty<Owner, Value>,
        _ value: Value,
        as event: ElementEvent<Raised, Value>
    ) {
        reports.report(property, value, as: event)
    }
}

/// How an application's own element is realized on this host, member by
/// member: the properties its view takes, and the events of its own it raises.
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
    public func property<Owner: Contract, Value: HostRepresentable>(
        _ member: ElementProperty<Owner, Value>,
        _ apply: @escaping (Made, Value?) -> Void
    ) {
        registration.property(member, apply)
    }

    /// An event the view raises through its reports - recorded, so the core
    /// knows this host reports it.
    ///
    /// - Parameter event: the member, written with its contract.
    public func raises<Owner: Contract, Payload>(_ event: ElementEvent<Owner, Payload>) {
        registration.raises(event)
    }
}
#endif
