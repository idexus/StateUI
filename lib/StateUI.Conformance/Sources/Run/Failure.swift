// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A case's expectation that did not hold, where the case wrote it.
public struct Failure: Equatable, Sendable {
    /// What was expected and what came.
    public let message: String

    /// The file and the line of the expectation.
    public let file: StaticString
    public let line: UInt

    public static func == (lhs: Failure, rhs: Failure) -> Bool {
        lhs.message == rhs.message && lhs.line == rhs.line && "\(lhs.file)" == "\(rhs.file)"
    }
}
