// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// Where an operation's events go: the connection that started it.
public final class EventChannel: Sendable {
    private let deliver: @Sendable (OperationEvent) -> Void
    private let backlog: @Sendable () -> Int

    /// A channel writing each event through `deliver`, whose writer holds `backlog` bytes not yet written.
    public init(deliver: @escaping @Sendable (OperationEvent) -> Void, backlog: @escaping @Sendable () -> Int) {
        self.deliver = deliver
        self.backlog = backlog
    }

    /// The most bytes a client may leave unread before its live output is dropped for a gap.
    public static let backlogLimit = 8 * 1024 * 1024

    /// Whether the client reads too slowly for live output.
    var isCongested: Bool { backlog() > Self.backlogLimit }

    /// Writes `event`, in the order given.
    func send(_ event: OperationEvent) {
        deliver(event)
    }
}
