// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The error a request is answered with when it is not accepted.
public struct RPCError: Error, Codable, Equatable, Sendable {
    /// The error's code: JSON-RPC's own, or one of the tooling API's.
    public var code: Int
    /// What went wrong, for a person.
    public var message: String
    /// The tooling API's error, for a request its method refused.
    public var data: ToolingError?

    /// An error of `code`.
    public init(code: Int, message: String, data: ToolingError? = nil) {
        self.code = code
        self.message = message
        self.data = data
    }

    /// The frame's body is not JSON.
    public static func parseError(_ message: String) -> RPCError { RPCError(code: -32700, message: message) }
    /// The message is not a JSON-RPC request or notification.
    public static func invalidRequest(_ message: String) -> RPCError { RPCError(code: -32600, message: message) }
    /// No method of that name.
    public static func methodNotFound(_ method: String) -> RPCError {
        RPCError(code: -32601, message: "No method \(method).")
    }
    /// The parameters are not the method's.
    public static func invalidParams(_ message: String) -> RPCError { RPCError(code: -32602, message: message) }
    /// The service failed answering.
    public static func internalError(_ message: String) -> RPCError { RPCError(code: -32603, message: message) }
    /// The client speaks no API version the service speaks.
    public static func incompatibleAPI(_ message: String) -> RPCError { RPCError(code: -32001, message: message) }
    /// A method other than `initialize` before the connection is initialized.
    public static let notInitialized = RPCError(code: -32002, message: "The connection is not initialized.")
    /// A request after `shutdown`.
    public static let shuttingDown = RPCError(code: -32003, message: "The service is shutting down.")
    /// The method refused the request, for the reason `error` gives.
    public static func refused(_ error: ToolingError) -> RPCError {
        RPCError(code: -32010, message: error.message, data: error)
    }
}
