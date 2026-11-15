// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// One JSON-RPC message a client sent, read for what it is.
public enum IncomingMessage: Equatable, Sendable {
    /// A request, which is answered.
    case request(id: RequestID, method: String, params: JSONValue?)
    /// A notification, which is never answered.
    case notification(method: String, params: JSONValue?)
    /// A client's answer to a request of the service's.
    case response(id: RequestID)
    /// Not a JSON-RPC message; answered with `error`, to `id` when one could be read.
    case invalid(id: RequestID?, error: RPCError)

    private static let fields: Set<String> = ["jsonrpc", "id", "method", "params", "result", "error"]

    /// What `value` is as a message.
    /// Design: docs/design/tooling/protocol.md#a-message-is-read-whole
    public init(_ value: JSONValue) {
        guard case .object(let message) = value else {
            self = .invalid(id: nil, error: .invalidRequest("A message is a JSON object."))
            return
        }
        let id = message["id"].flatMap(Self.identifier)
        guard message["jsonrpc"] == .string("2.0") else {
            self = .invalid(id: id, error: .invalidRequest("A message says \"jsonrpc\": \"2.0\"."))
            return
        }
        if let unknown = message.keys.sorted().first(where: { !Self.fields.contains($0) }) {
            self = .invalid(id: id, error: .invalidRequest("A message has no field \(unknown)."))
            return
        }
        if message["id"] != nil, id == nil {
            self = .invalid(id: nil, error: .invalidRequest("An id is a string, a number or null."))
            return
        }
        guard let method = message["method"] else {
            if let id, message["result"] != nil || message["error"] != nil {
                self = .response(id: id)
            } else {
                self = .invalid(id: id, error: .invalidRequest("A message names its method."))
            }
            return
        }
        guard case .string(let name) = method, message["result"] == nil, message["error"] == nil else {
            self = .invalid(id: id, error: .invalidRequest("A request's method is a string, with no result."))
            return
        }
        let params = message["params"]
        switch params {
        case nil, .object?, .array?:
            self = id.map { .request(id: $0, method: name, params: params) } ?? .notification(method: name, params: params)
        default:
            self = .invalid(id: id, error: .invalidRequest("A request's params are an object."))
        }
    }

    private static func identifier(_ value: JSONValue) -> RequestID? {
        switch value {
        case .string(let string): .string(string)
        case .number(let number): .number(number)
        case .null: .null
        default: nil
        }
    }
}
