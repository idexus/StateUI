// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// The acts an application performs on its host, beside those the host performs itself, the same on every host:
/// each registered by its member and handed the values its contract declares - an aimed one the control of the
/// element it names - and answered once it returns, or failed with why.
/// Design: docs/design/host/runtime.md#an-applications-own-acts
@_spi(Host) @MainActor public final class InteropActs<View> {
    /// What answers one act, and what it needs to answer it.
    public enum Performer {
        /// An act of the application's, given the values it was called with.
        case application(@MainActor ([HostValue]) async throws -> [HostValue])

        /// An act aimed at one element, given that element's view and the values after the identity the aim put
        /// in argument 0.
        case aimed(@MainActor (View, [HostValue]) async throws -> [HostValue])
    }

    /// The performers, by the act.
    public private(set) var performers: [Act: Performer] = [:]

    /// No act registered.
    public init() {}

    /// Forgets every performer: a test registers its own and leaves none standing for the next.
    public func forget() {
        performers = [:]
    }

    /// Performs an act of the application's own with `perform`, handed the values its contract declares; a second
    /// registration replaces the first.
    public func add<Owner: ApplicationTier, each Argument: HostRepresentable, each Answer: HostRepresentable>(
        _ act: ElementAct<Owner, (repeat each Argument), (repeat each Answer)>,
        _ perform: @escaping @MainActor (repeat each Argument) async throws -> (repeat each Answer)
    ) {
        performers[act.token] = .application { values in
            guard let arguments = MemberValues.decode(values, as: repeat (each Argument).self) else {
                throw Self.miscalled(act.name, values, declaring: MemberValues.describe(repeat (each Argument).self))
            }
            let answer = try await perform(repeat each arguments)
            return MemberValues.encode(repeat each answer)
        }
    }

    /// Performs an act aimed at an element with `perform`, handed the control `control` finds in the element's
    /// view and the values its contract declares; an element shown otherwise fails the call.
    public func add<
        Owner: Contract, Made, each Argument: HostRepresentable, each Answer: HostRepresentable
    >(
        _ act: ElementAct<Owner, (repeat each Argument), (repeat each Answer)>,
        control: @escaping @MainActor (View) -> Made?,
        _ perform: @escaping @MainActor (Made, repeat each Argument) async throws -> (repeat each Answer)
    ) {
        performers[act.token] = .aimed { view, values in
            guard let made = control(view) else {
                throw StateUIError(message: "`\(act.name)` is aimed at an element this host shows otherwise, "
                    + "and it performs on \(Made.self)")
            }
            guard let arguments = MemberValues.decode(values, as: repeat (each Argument).self) else {
                throw Self.miscalled(act.name, values, declaring: MemberValues.describe(repeat (each Argument).self))
            }
            let answer = try await perform(made, repeat each arguments)
            return MemberValues.encode(repeat each answer)
        }
    }

    /// Performs `call` where the application registered its act - an aimed one handed the view `view` finds for
    /// the element it names - answering it through `core` once the performer returns, or failing it with why;
    /// whether the application registered the act.
    public func perform(
        _ call: HostActCall, in tree: MountedTree, core: CoreLink, view: (MountedElement) -> View?,
        log: @escaping (String) -> Void
    ) -> Bool {
        guard let performer = performers[call.act] else { return false }

        var aimed: View?
        if case .aimed = performer {
            do {
                let element = try tree.aimed(call)
                guard let found = view(element) else {
                    core.fail(call, "\(element.id) has no view", log: log)
                    return true
                }
                aimed = found
            } catch {
                core.fail(call, error.reason, log: log)
                return true
            }
        }
        // A performer may await; the call is answered once it returns.
        Task { @MainActor in
            do {
                switch performer {
                case .application(let perform): core.reply(call, try await perform(call.arguments))
                case .aimed(let perform): core.reply(call, try await perform(aimed!, Array(call.arguments.dropFirst())))
                }
            } catch {
                core.fail(call, "\(error)", log: log)
            }
        }
        return true
    }

    /// Why a call carrying other values than its act declares fails.
    private static func miscalled(_ name: String, _ values: [HostValue], declaring declared: String) -> StateUIError {
        StateUIError(message: "`\(name)` was called with \(values.count) value(s), and its contract declares " + declared)
    }
}
