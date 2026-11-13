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
    /// No project stands where the request names one.
    public static let projectNotFound = ToolingErrorCode(rawValue: "PROJECT_NOT_FOUND")
    /// A workspace's file cannot be read as written.
    public static let invalidConfiguration = ToolingErrorCode(rawValue: "INVALID_CONFIGURATION")
    /// A name the request gives cannot name what it would make.
    public static let invalidName = ToolingErrorCode(rawValue: "INVALID_NAME")
    /// What the request would make stands already.
    public static let alreadyExists = ToolingErrorCode(rawValue: "ALREADY_EXISTS")
    /// A program the tool runs - a compiler, a package manager - failed.
    public static let toolFailed = ToolingErrorCode(rawValue: "TOOL_FAILED")
    /// A program the tool needs cannot be found.
    public static let missingToolchain = ToolingErrorCode(rawValue: "MISSING_TOOLCHAIN")
    /// The request's work was interrupted before it ended.
    public static let operationInterrupted = ToolingErrorCode(rawValue: "OPERATION_INTERRUPTED")
    /// The tool failed in a way no other code describes.
    public static let internalError = ToolingErrorCode(rawValue: "INTERNAL_ERROR")
}
