// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The stable identifier of a kind of failure, such as `NOT_FOUND`.
///
/// A client reads a code it does not know as a failure of no kind it can act on.
public struct ToolingErrorCode: RawRepresentable, Codable, Hashable, Sendable {
    /// The code as the API writes it.
    public var rawValue: String

    /// The code `rawValue`.
    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    /// What the request names - an operation, a session - is not there.
    public static let notFound = ToolingErrorCode(rawValue: "NOT_FOUND")
    /// A request token already stands for a request of other parameters.
    public static let requestTokenConflict = ToolingErrorCode(rawValue: "REQUEST_TOKEN_CONFLICT")
    /// The tool failed in a way no other code describes.
    public static let internalError = ToolingErrorCode(rawValue: "INTERNAL_ERROR")
}
