// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
import CStateUIGTK

/// What an APPLICATION registers with this host, beside the elements the host realizes itself: the controls of its
/// own, the acts it performs and the events it raises. Said once, before `StateUIGTK.run(applicationID:)`.
/// Design: docs/design/platforms/gtk/interop.md
@MainActor
enum GTKInterop {
    /// What answers one act, and what it needs to answer it.
    enum Performer {
        /// An act of the application's, given the values it was called with.
        case application(([HostValue]) throws -> [HostValue])

        /// An act aimed at one element, given that element's view and the values after the identity the aim put
        /// in argument 0.
        case aimed((GTKView, [HostValue]) throws -> [HostValue])
    }

    /// The performers, by the act - read where no act of the library's own answers the call.
    static var performers: [Act: Performer] = [:]

    /// Forgets every performer: a test registers its own and leaves none standing for the next.
    static func forgetPerformers() {
        performers = [:]
    }
}

/// A control of the application's own on this host: an object that makes and holds the GTK widget it shows.
///
/// The host places, sizes and shows the widget as it does its own, and holds the control for as long as its element
/// lives; the widget's own measure is what the host measures.
@MainActor
public protocol GTKControl: AnyObject {
    /// The widget the control shows.
    var widget: UnsafeMutablePointer<GtkWidget> { get }
}

/// The controls an application adds to this host - its own elements, each realized with a control of its own.
///
/// Said once, from the application's GTK head, before `StateUIGTK.run(applicationID:)`.
@MainActor
public enum StateUIControls {
    /// Adds an element of the APPLICATION'S OWN, realized with a control of its own: how the control is made, and
    /// which of the element's members it takes and raises.
    ///
    ///     StateUIControls.add(TrafficLightContract.self, create: { reports -> TrafficLightWidget in
    ///         let light = TrafficLightWidget()
    ///         light.onLampTapped = { index in reports.raise(TrafficLightContract.lampTapped, index) }
    ///         return light
    ///     }) { light in
    ///         light.property(TrafficLightContract.signal) { control, signal in
    ///             control.signal = signal ?? .stop
    ///         }
    ///     }
    ///
    /// What every view shares - margins, alignment, opacity, gestures, the frame reports - this host applies around
    /// the widget, exactly as it does for the elements it realizes itself. A second registration of a contract
    /// replaces the first.
    ///
    /// - Parameters:
    ///   - contract: the element's contract.
    ///   - create: makes the control, once per element, handed what it reports through.
    ///   - members: registers the members the control takes and raises.
    public static func add<Realized: ElementContract, Made: GTKControl>(
        _ contract: Realized.Type,
        create: @escaping (GTKReports<Realized>) -> Made,
        members: (GTKRegistration<Realized, Made>) -> Void = { _ in }
    ) {
        GTKRegistrations.registry.add(
            contract,
            create: { reports in GTKHostedView(create(GTKReports(reports))) },
            members: { registration in members(GTKRegistration(registration)) })
    }
}

/// The acts an application performs on this host - what its own calls, `stateUICall` and an `Aim`, reach.
///
/// Said once, from the application's GTK head, before `StateUIGTK.run(applicationID:)`.
@MainActor
public enum StateUIActs {
    /// Performs an act of the application's - one no control stands behind - when the application calls it with
    /// `stateUICall`.
    ///
    ///     StateUIActs.add(GalleryContract.setClipboard) { text in
    ///         gdk_clipboard_set_text(gdk_display_get_clipboard(gdk_display_get_default()), text)
    ///     }
    ///
    /// The values are the act's own, as its contract declares them, so a performer of another shape does not
    /// compile and a call carrying anything else fails with the reason. A second registration replaces the first.
    ///
    /// - Parameters:
    ///   - act: the member, written with its contract.
    ///   - perform: given the arguments the contract declares, answering the values it declares. What it throws
    ///     fails the call, and the caller throws that reason.
    public static func add<
        Owner: ApplicationTier, each Argument: HostRepresentable, each Answer: HostRepresentable
    >(
        _ act: ElementAct<Owner, (repeat each Argument), (repeat each Answer)>,
        _ perform: @escaping @MainActor (repeat each Argument) throws -> (repeat each Answer)
    ) {
        GTKInterop.performers[act.token] = .application { values in
            guard let arguments = MemberValues.decode(values, as: repeat (each Argument).self) else {
                throw StateUIError(message: "`\(act.name)` was called with \(values.count) value(s), and its "
                    + "contract declares " + MemberValues.describe(repeat (each Argument).self))
            }
            let answer = try perform(repeat each arguments)
            return MemberValues.encode(repeat each answer)
        }
    }

    /// Performs an act AIMED at one of the application's own elements, when the application calls it through an
    /// `Aim`: the performer is handed the element's control. An aim at nothing, or at an element no longer on
    /// screen, fails the call with that reason.
    ///
    ///     StateUIActs.add(RatingBarContract.flash, on: RatingBarWidget.self) { bar in
    ///         bar.flash()
    ///     }
    ///
    /// - Parameters:
    ///   - act: the member, written with its contract.
    ///   - control: the class the application's registration makes for the element.
    ///   - perform: given the element's control and the arguments the contract declares, answering the values it
    ///     declares.
    public static func add<
        Owner: Contract, Made: GTKControl, each Argument: HostRepresentable, each Answer: HostRepresentable
    >(
        _ act: ElementAct<Owner, (repeat each Argument), (repeat each Answer)>,
        on control: Made.Type,
        _ perform: @escaping @MainActor (Made, repeat each Argument) throws -> (repeat each Answer)
    ) {
        GTKInterop.performers[act.token] = .aimed { view, values in
            guard let made = (view as? GTKHostedView<Made>)?.control else {
                throw StateUIError(message: "`\(act.name)` is aimed at an element this host shows otherwise, "
                    + "and it performs on \(Made.self)")
            }
            guard let arguments = MemberValues.decode(values, as: repeat (each Argument).self) else {
                throw StateUIError(message: "`\(act.name)` was called with \(values.count) value(s), and its "
                    + "contract declares " + MemberValues.describe(repeat (each Argument).self))
            }
            let answer = try perform(made, repeat each arguments)
            return MemberValues.encode(repeat each answer)
        }
    }
}

/// The events an application raises through this host - the ones no control raises, heard by every
/// `HostEvents.on`.
public enum StateUIEvents {
    /// Declares an event of the application's this host raises, where its source is wired: a handler listening for
    /// an event nothing declared is told, once, that it will not hear it.
    ///
    ///     StateUIEvents.raises(GalleryContract.batteryChanged)
    ///
    /// - Parameter event: the member, written with its contract.
    @MainActor
    public static func raises<Owner: ApplicationTier, Payload>(_ event: ElementEvent<Owner, Payload>) {
        GTKRegistrations.registry.raises(event)
    }

    /// Raises an event of the application's - one no control raises - with the values its contract declares.
    /// Every `HostEvents.on` subscription to the member hears it. Safe from any thread.
    ///
    ///     StateUIEvents.raise(GalleryContract.batteryChanged, level, charging)
    ///
    /// - Parameters:
    ///   - event: the member, written with its contract.
    ///   - value: what it carries, in the order its contract declares.
    /// - Returns: how many subscriptions heard it - a raise nobody hears is an ordinary zero.
    @discardableResult
    public nonisolated static func raise<Owner: ApplicationTier, each Value: HostRepresentable>(
        _ event: ElementEvent<Owner, (repeat each Value)>,
        _ value: repeat each Value
    ) -> Int {
        CoreLink().raise(event, repeat each value)
    }
}

/// What an element of the APPLICATION'S OWN tells the application: an event of its own, and a value its user
/// changed. Handed to the control where it is made, so the control names members of its contract and never a
/// handler.
public struct GTKReports<Realized: ElementContract> {
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
public final class GTKRegistration<Realized: ElementContract, Made: GTKControl> {
    private let registration: Registration<Realized, GTKHostedView<Made>>

    init(_ registration: Registration<Realized, GTKHostedView<Made>>) {
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
}
