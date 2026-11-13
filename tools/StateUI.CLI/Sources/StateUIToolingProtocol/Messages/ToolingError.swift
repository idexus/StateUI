// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// Why the tool refused or failed a request: a stable code and words for a person.
public struct ToolingError: Error, Codable, Equatable, Sendable {
    /// What kind of failure: a stable identifier a client acts on.
    public var code: ToolingErrorCode
    /// What went wrong, for a person; a client never reads meaning out of it.
    public var message: String
    /// Whether the same request may succeed when sent again.
    public var retryable: Bool

    /// A failure of kind `code`.
    public init(_ code: ToolingErrorCode, _ message: String, retryable: Bool = false) {
        self.code = code
        self.message = message
        self.retryable = retryable
    }
}
