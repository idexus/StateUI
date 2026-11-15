// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A message the service sends.
public enum OutgoingMessage: Encodable, Equatable, Sendable {
    /// The answer to request `id`: its result, or the error it was refused with.
    case response(id: RequestID, outcome: Outcome)
    /// A notification.
    case notification(method: String, params: JSONValue)
    /// The answers to a batch, in one array.
    case batch([OutgoingMessage])

    /// How a request was answered.
    public enum Outcome: Equatable, Sendable {
        /// The method's result.
        case result(JSONValue)
        /// The error the request was refused with.
        case error(RPCError)
    }

    private enum Field: String, CodingKey {
        case jsonrpc, id, result, error, method, params
    }

    /// Writes the message.
    public func encode(to encoder: any Encoder) throws {
        if case .batch(let messages) = self {
            var array = encoder.unkeyedContainer()
            for message in messages { try array.encode(message) }
            return
        }
        var object = encoder.container(keyedBy: Field.self)
        try object.encode("2.0", forKey: .jsonrpc)
        switch self {
        case .response(let id, .result(let result)):
            try object.encode(id, forKey: .id)
            try object.encode(result, forKey: .result)
        case .response(let id, .error(let error)):
            try object.encode(id, forKey: .id)
            try object.encode(error, forKey: .error)
        case .notification(let method, let params):
            try object.encode(method, forKey: .method)
            try object.encode(params, forKey: .params)
        case .batch:
            break
        }
    }
}
