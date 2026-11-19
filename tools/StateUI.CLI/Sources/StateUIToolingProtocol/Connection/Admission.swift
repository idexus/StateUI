// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// Who a connection admits, where it admits not every client - a service's: the methods it answers before
/// `initialize`, pairing and a challenge, and whether an `initialize`'s credential proves a paired client.
public struct Admission: Sendable {
    /// The methods answered before `initialize`.
    public let methods: Set<String>
    /// The outcome of one of `methods`, asked with its parameters.
    public let answer: @Sendable (String, JSONValue?) -> OutgoingMessage.Outcome
    /// Whether an `initialize` carrying a credential - or none - is admitted.
    public let admits: @Sendable (Credential?) -> Bool

    /// Answers `methods` before `initialize` through `answer`, and admits an `initialize` whose credential `admits`.
    public init(
        methods: Set<String>, answer: @escaping @Sendable (String, JSONValue?) -> OutgoingMessage.Outcome,
        admits: @escaping @Sendable (Credential?) -> Bool
    ) {
        self.methods = methods
        self.answer = answer
        self.admits = admits
    }
}
