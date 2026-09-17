// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// Asking the host to do something.
//
// The tree says what the interface IS. Some things are not a shape but an act -
// navigate, show an alert, copy to the clipboard - and Swift can no more perform
// those than it can create a Label: they are calls on the host's native objects.
//
// So the same split applies. Swift DESCRIBES the act and the host performs it:
//
//     try await Dialogs.alert("Saved", message: "the draft is safe")
//
// puts one act in a queue - `alert`, three string arguments, and the
// completion id of the continuation waiting for it. The host drains that queue
// after the handler suspends, and performs the act against the real page.
//
// The act is a member of a contract - the library's own are
// ApplicationContract's and its elements' - whose documentation says what the
// host does for it. On the wire it travels as its number from the session's
// dictionary in Core/Wire.swift, announced by the first batch that uses it.
//
// WHY THE HANDLER SUSPENDS RATHER THAN TAKING A CLOSURE:
// Both work; `await` reads better and sequences without nesting, which is what
// an animation or a confirm-then-act will want. What makes it SAFE is
// Core/MainThread.swift: the handler resumes on the host's UI thread, because
// this library's executor puts it there. Read that file before changing
// anything here - a suspension that resumes anywhere else writes state next to
// a render the host is running, and nothing crashes reliably.
//
// A BATCH IS A BATCH AND NOT A TRANSACTION. The host takes the queue in order
// and STARTS each act in that order, but an act that waits - a dialog waiting
// for the reader, a scroll animating to a row - does not hold up the one behind
// it, so the answers come back in whatever order the host finishes them. What
// puts one act after another is `await`: a handler that awaits the first queues
// the second only once the answer is in.
//
// The completion id is the token. It is negative, so it can never be mistaken
// for an element's handler id, and it is what the host quotes back - which is
// how the continuation waiting for this act is found again.

/// One act for the host to perform.
struct ActCall {
    /// The act - one of the library's tokens, or an application's own
    /// registered one. What travels is the session dictionary's number for it.
    let act: Act

    /// Its arguments, in the order the act takes them.
    let arguments: [PropValue]

    /// The id of the continuation waiting for it, if anyone is waiting.
    /// Negative, so it can never be mistaken for an event handler id - those are
    /// positive and belong to elements.
    let completion: Int?

    /// The act's name - what diagnostics and the fixture sidecars read.
    var name: String { act.name }
}

extension ActCall {
    /// An act the library sends with nobody waiting on its answer, its
    /// arguments the values its member declares - so the declaration types
    /// what the library queues, as it types what an application calls.
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
/// handing it arguments of the types its contract declares and answering with
/// the values it declares.
///
///     let text = try await stateUICall(NotesContract.readClipboard)
///     try await stateUICall(NotesContract.setClipboard, "note")
///
/// Throws `StateUIError` when the host could not perform it - including when
/// no host act or registration answers its name - and when the answer is not
/// what the contract declares. Resumes on the host's UI thread, which is where
/// it was called from. An act of an element's own goes through the element's
/// aim: `Aim.call`.
///
/// Callable from a handler, from a child task a handler started - `async let`
/// runs its child on the cooperative pool, and the queue behind this is locked
/// for exactly that - and from a `Task.detached`. A handler may also await
/// things that are NOT acts - `Task.sleep`, a task's value - because the host
/// keeps a thread parked in `stateui_wait_work` and a resume wakes it; see
/// Core/MainThread.swift.
///
/// Two acts queued without an `await` between them start in the order they
/// were queued and finish in whichever order the host's methods do. `await` is
/// what orders them.
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
