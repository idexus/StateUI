// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The application's handlers, raised in the order they came: held while a patch applies or the user's
/// transaction runs, and raised once it is over.
/// Design: docs/design/host/runtime.md#the-handlers-order
@_spi(Host) @MainActor public final class HandlerDispatch {
    private let core: CoreLink
    private let intake: PatchIntake

    /// Handlers waiting for their turn, in the order they came.
    private var queued: [Queued] = []

    /// How deep the user's transactions stand.
    private var transactions = 0

    private struct Queued {
        let handler: Int32
        let payload: [HostValue]
        let isPhase: Bool
    }

    /// Handlers raised through `core`, held while `intake` applies a message.
    public init(core: CoreLink, intake: PatchIntake) {
        self.core = core
        self.intake = intake
    }

    /// Whether a handler raised now waits: a message applies, or the user's transaction runs.
    public var isHeld: Bool { intake.isApplying || transactions > 0 }

    /// Whether the user's transaction runs.
    public var inTransaction: Bool { transactions > 0 }

    /// Raises `handler` with `payload` now, or queues it while held; whether it ran.
    @discardableResult
    public func raise(_ handler: Int32, payload: [HostValue] = []) -> Bool {
        guard !isHeld else {
            queued.append(Queued(handler: handler, payload: payload, isPhase: false))
            return false
        }

        _ = core.dispatch(handler, payload: payload)
        return true
    }

    /// Queues a page's or a window's phase: it runs in its turn, and is rendered before anything after it.
    public func enqueuePhase(_ handler: Int32) {
        queued.append(Queued(handler: handler, payload: [], isPhase: true))
    }

    /// Runs `body` as the user's transaction; whether it was the outermost.
    func transaction(_ body: () -> Void) -> Bool {
        transactions += 1
        body()
        transactions -= 1
        return transactions == 0
    }

    /// Raises what waits, in order, stopping after a phase so it is rendered first; whether any ran.
    func raiseQueued() -> Bool {
        guard !queued.isEmpty, !isHeld else { return false }

        while !queued.isEmpty {
            let each = queued.removeFirst()
            _ = core.dispatch(each.handler, payload: each.payload)
            if each.isPhase { break }
        }
        return true
    }
}
