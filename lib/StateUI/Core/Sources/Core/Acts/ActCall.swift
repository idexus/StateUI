// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// An act: something the host performs on its native objects, described here and
// queued for the host with the id of whoever waits for it.
// Design: docs/design/core/acts.md#an-act-is-a-member

/// One act for the host to perform.
struct ActCall {
    /// The act's token, which a host reads by its name.
    let act: Act

    /// Its arguments, in the order the act takes them.
    let arguments: [PropValue]

    /// The id of the continuation waiting for it - negative, apart from handler ids.
    let completion: Int?

    /// The act's name - what a host and the diagnostics read.
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

/// Something StateUI or the host could not do - each case a reason an application tells apart, its `description`
/// the words to show or to log.
///
///     do {
///         try await application.call(NotesContract.export, text)
///     } catch StateUIError.notPerformed(_, let reason) {
///         said = reason
///     }
///
/// A `switch` over it keeps a `default`: a later version may name another reason.
public enum StateUIError: Error, CustomStringConvertible, Equatable {
    /// The host could not perform `act`, for the `reason` it gave - a view that has gone, no window to ask the user
    /// in, a page that is not there.
    case notPerformed(act: String, reason: String)

    /// The host answered `act` with `answered`, where its contract declares `declared` - usually a native library
    /// and a runtime built from different versions.
    case unreadableAnswer(act: String, answered: String, declared: String)

    /// An aim on no view: `.aim(_:)` written on none, or an act called before the view rendered.
    case aimOnNoView

    /// An aim on two views; an aim names one.
    case aimOnTwoViews

    /// A list asked to scroll to an item it does not hold.
    case noItem(String)

    /// Views wrote state while being built, render after render; the pending change was dropped to stop the loop.
    case writesWhileBuilding

    /// The reason, in words.
    public var description: String {
        switch self {
        case .notPerformed(_, let reason):
            reason
        case .unreadableAnswer(let act, let answered, let declared):
            "`\(act)` answered \(answered), and its contract declares \(declared)"
        case .aimOnNoView:
            "this aim is on no view - write .aim(...) on the view, and act after it has rendered"
        case .aimOnTwoViews:
            "this aim is on two views - an aim names ONE; declare one for each view"
        case .noItem(let item):
            "the list holds no item \(item) to scroll to"
        case .writesWhileBuilding:
            "A view writes state while it is being built - render after render ended with the tree dirty again. "
                + "A body reads state; a handler writes it. The pending change was dropped to stop the render loop."
        }
    }
}

/// Performs an act of the application's and answers as its contract declares: `ApplicationSession.call(_:_:)`, which
/// the library's own acts call too.
func callAct<Owner: ApplicationTier, each Argument: HostRepresentable, each Answer: HostRepresentable>(
    _ act: ElementAct<Owner, (repeat each Argument), (repeat each Answer)>,
    _ arguments: repeat each Argument
) async throws -> (repeat each Answer) {
    let reply = try await Renderer.shared.call(act.token, MemberValues.encode(repeat each arguments))
    return try MemberValues.answer(reply, of: act.token.name, as: repeat (each Answer).self)
}

/// Asks the host to perform an act of the application's without waiting for it: `ApplicationSession.tell(_:_:)`.
@MainActor
func tellAct<Owner: ApplicationTier, each Argument: HostRepresentable, Answer>(
    _ act: ElementAct<Owner, (repeat each Argument), Answer>,
    _ arguments: repeat each Argument
) {
    Renderer.shared.send(act.token, MemberValues.encode(repeat each arguments), completion: nil)
}
