// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// Whether a name can be used: `name/check`'s result.
public struct NameVerdict: Codable, Equatable, Sendable {
    /// Why it cannot, in words for the user; absent where it can.
    public var problem: String?

    /// A verdict refusing a name for `problem`, or taking it where `problem` is `nil`.
    public init(problem: String? = nil) {
        self.problem = problem
    }
}
