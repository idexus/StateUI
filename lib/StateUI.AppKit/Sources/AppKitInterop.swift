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

extension StateUIAppKit {
    /// Performs an act of the application's - one no control stands behind -
    /// when the application calls it with `stateUICall`.
    ///
    /// The values are the act's own, as its contract declares them, so a
    /// performer of another shape does not compile and a call carrying
    /// anything else fails with the reason rather than running on a guess.
    ///
    ///     StateUIAppKit.performs(GalleryContract.setClipboard) { text in
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
    public static func performs<
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
    ///     StateUIAppKit.performs(RatingBarContract.flash, on: RatingBarView.self) { bar in
    ///         bar.flash()
    ///     }
    ///
    /// - Parameters:
    ///   - act: the member, written with its contract.
    ///   - view: the class this host makes for the element.
    ///   - perform: given the element's view and the arguments the contract
    ///     declares, answering the values it declares.
    public static func performs<
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

    /// Raises an event of the application's - one no control raises - with the
    /// values its contract declares.
    ///
    /// Every `HostEvents.on` subscription to the member hears it, each handler
    /// queued on this library's executor. Safe from any thread, so an
    /// application wires its sources where the platform reports them.
    ///
    ///     StateUIAppKit.raise(GalleryContract.batteryChanged, level, charging)
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
        AppKitCoreLink().raise(event, repeat each value)
    }
}
#endif
