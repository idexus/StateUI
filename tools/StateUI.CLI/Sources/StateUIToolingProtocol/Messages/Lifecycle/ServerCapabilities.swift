// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What a service offers: only what it does, never what is planned.
public struct ServerCapabilities: Codable, Equatable, Sendable {
    /// The methods it answers, in sorted order.
    public var methods: [String]
    /// The notifications it sends, in sorted order.
    public var notifications: [String]

    /// A service answering `methods` and sending `notifications`.
    public init(methods: [String], notifications: [String]) {
        self.methods = methods.sorted()
        self.notifications = notifications.sorted()
    }
}
