// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// An act: something the host performs on its native objects, described here and
// queued for the host with the id of whoever waits for it.
// Design: docs/design/core/acts.md#an-act-is-a-member

/// One act for the host to perform.
struct ActCall {
    /// The act's token; what crosses is the session dictionary's number for it.
    let act: Act

    /// Its arguments, in the order the act takes them.
    let arguments: [PropValue]

    /// The id of the continuation waiting for it - negative, apart from handler ids.
    let completion: Int?

    /// The act's name - what diagnostics and the fixture sidecars read.
    var name: String { act.name }
}

extension ActCall {
    /// An act the library sends with nobody waiting, its arguments as its member
    /// declares.
    init<Owner: Contract, each Argument: HostRepresentable, Answer>(
        _ act: ElementAct<Owner, (repeat each Argument), Answer>,
        _ arguments: repeat each Argument
    ) {
        self.init(act: act.token, arguments: MemberValues.encode(repeat each arguments), completion: nil)
    }
}

/// Something the host could not do.
///
/// Carries the message the host reported, which is usually why the platform
/// refused - a view that has gone, a page that is not there.
public struct StateUIError: Error, CustomStringConvertible, Equatable {
    /// What went wrong, as the host described it.
    public let message: String

    /// A failure with a message.
    public init(message: String) {
        self.message = message
    }

    /// The message, so `print(error)` says something useful.
    public var description: String { message }
}

/// Performs an act of the application's - one with no control behind it -
/// handing it the arguments its contract declares and answering with the values
/// it declares.
///
///     let text = try await stateUICall(NotesContract.readClipboard)
///     try await stateUICall(NotesContract.setClipboard, "note")
///
/// Throws `StateUIError` when the host could not perform it - including when no
/// host answers its name - and when the answer is not what the contract
/// declares. It resumes where it was called, and may be called from a handler, a
/// child task or a detached task. Acts queued without an `await` between them
/// start in order and finish in whatever order the host's work does. An act of
/// an element is called through its aim: `Aim.call`.
///
/// - Parameters:
///   - act: the member, written with its contract.
///   - arguments: its arguments, in the order the contract declares them.
/// - Returns: the answer, as the contract declares it.
@discardableResult
public nonisolated(nonsending) func stateUICall<
    Owner: ApplicationTier, each Argument: HostRepresentable, each Answer: HostRepresentable
>(
    _ act: ElementAct<Owner, (repeat each Argument), (repeat each Answer)>,
    _ arguments: repeat each Argument
) async throws -> (repeat each Answer) {
    let reply = try await Renderer.shared.call(act.token, MemberValues.encode(repeat each arguments))
    return try MemberValues.answer(reply, of: act.name, as: repeat (each Answer).self)
}

/// Asks the host to perform an act of the application's without waiting for
/// it - for an act whose outcome nothing depends on. What it answers, and
/// whether it failed, reaches nothing here.
///
///     stateUISend(NotesContract.logEvent, "opened the sample")
///
/// It returns at once, and the host performs the act on its next drain. A
/// name the host has no case for is logged there and never told here - the
/// difference from `stateUICall`, and the reason to reach for that one
/// instead.
///
/// - Parameters:
///   - act: the member, written with its contract.
///   - arguments: its arguments, in the order the contract declares them.
public func stateUISend<Owner: ApplicationTier, each Argument: HostRepresentable, Answer>(
    _ act: ElementAct<Owner, (repeat each Argument), Answer>,
    _ arguments: repeat each Argument
) {
    Renderer.shared.send(act.token, MemberValues.encode(repeat each arguments), completion: nil)
}
