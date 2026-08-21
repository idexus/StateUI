// Asking the host to do something.
//
// The tree says what the interface IS. Some things are not a shape but an act -
// navigate, show an alert, copy to the clipboard - and Swift can no more perform
// those than it can create a Label: they are MAUI methods on MAUI objects.
//
// So the same split applies. Swift DESCRIBES the act and the host performs it:
//
//     try await Dialogs.displayAlert("Saved", message: "the draft is safe")
//
// puts one act in a queue - displayAlertAsync, three string arguments, and the
// completion id of the continuation waiting for it. The host drains that queue
// after the handler suspends, and performs the act against the real page.
//
// The name is the MAUI method camelCased, as everywhere else in this library;
// the class it sits on is said in the token's comment rather than in the name.
// On the wire it travels as its number from the session's dictionary in
// Core/Wire.swift, announced by the first batch that uses it.
//
// WHY THE HANDLER SUSPENDS RATHER THAN TAKING A CLOSURE:
// Both work; `await` reads better and sequences without nesting, which is what
// an animation or a confirm-then-act will want. What makes it SAFE is
// Core/MainThread.swift: the handler resumes on the thread MAUI draws on,
// because this library's executor puts it there. Read that file before changing
// anything here - a suspension that resumes anywhere else writes state next to a
// C# render, and nothing crashes reliably.
//
// A BATCH IS A BATCH AND NOT A TRANSACTION. The host takes the queue in order
// and STARTS each act in that order, but an act that waits - a dialog waiting
// for the reader, a scroll animating to a row - does not hold up the one behind
// it, so the answers come back in whatever order the MAUI methods finish. What
// puts one act after another is `await`: a handler that awaits the first queues
// the second only once the answer is in.
//
// The completion id is the token. It is negative, so it can never be mistaken
// for an element's handler id, and it is what the host quotes back - which is
// how the continuation waiting for this act is found again.

/// One act for the host to perform.
struct Command {
    /// The act - the MAUI method's name as a token, or an application's own
    /// registered one. What travels is the session dictionary's number for it.
    let act: Act

    /// Its arguments, in the order MAUI takes them.
    let arguments: [PropValue]

    /// The id of the continuation waiting for it, if anyone is waiting.
    /// Negative, so it can never be mistaken for an event handler id - those are
    /// positive and belong to elements.
    let completion: Int?

    /// The act's name - what diagnostics and the fixture sidecars read.
    var name: String { act.name }
}

/// Something the host could not do.
///
/// Carries the message the host reported, which for a MAUI method is usually the
/// exception it threw - a view that has gone, a page that is not there.
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

/// Asks the host to perform a MAUI method - or a function the application
/// registered with the host - and waits for it.
///
/// The escape hatch behind the typed calls - `Dialogs.displayAlert` is one line
/// over this - and the way an application reaches its OWN C# code: register a
/// performer with the host under a name, declare the same name as an `Act`
/// token, and call it like any act the library ships:
///
///     extension Act {
///         static let batteryLevel = Act("Gallery.BatteryLevel")
///     }
///
///     let level = try await stateUICall(.batteryLevel).value()?.number
///
/// Returns the VALUES the host's reply carried - read them with `PropValue`'s
/// accessors - and throws `StateUIError` if the act could not be performed,
/// including when the host has no case and no registration for the name.
/// Resumes on the thread MAUI draws on, which is where it was called from.
///
/// Callable from a handler, from a child task a handler started - `async let`
/// runs its child on the cooperative pool, and the queue behind this is locked
/// for exactly that - and from a `Task.detached`. A handler may also await
/// things that are NOT commands - `Task.sleep`, a task's value - because the
/// host keeps a thread parked in `stateui_wait_work` and a resume wakes it;
/// see Core/MainThread.swift.
///
/// Two acts queued without an `await` between them start in the order they were
/// queued and finish in whichever order the host's methods do. `await` is what
/// orders them.
///
/// - Parameters:
///   - act: the act's token - a literal spelling works too,
///     `stateUICall("Gallery.BatteryLevel", …)`.
///   - arguments: its arguments, in the order the method takes them.
/// - Returns: the values the host reported, empty for a method that returns
///   nothing.
@discardableResult
public nonisolated(nonsending) func stateUICall(
    _ act: Act,
    _ arguments: [PropValue] = []
) async throws -> [PropValue] {
    try await Renderer.shared.call(act, arguments)
}

/// Asks the host to perform an act without waiting for it.
///
///     extension Act {
///         static let logEvent = Act("Gallery.LogEvent")
///     }
///
///     stateUISend(.logEvent, [.string("opened the sample")])
///
/// For an act whose outcome nothing depends on: it returns at once, and the
/// host performs it on its next drain. Anything that fails does so silently -
/// a name the host has no case for included - which is the difference from
/// `stateUICall` and the reason to reach for that one instead.
///
/// - Parameters:
///   - act: the act's token - a literal spelling works too.
///   - arguments: its arguments, in the order the method takes them.
public func stateUISend(_ act: Act, _ arguments: [PropValue] = []) {
    Renderer.shared.send(act, arguments, completion: nil)
}
