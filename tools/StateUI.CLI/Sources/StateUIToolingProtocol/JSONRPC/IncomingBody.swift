// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation

/// What a frame's body holds: one message, a batch of them, or nothing that can be read.
public enum IncomingBody: Equatable, Sendable {
    /// One message.
    case single(IncomingMessage)
    /// A batch: each message dispatched on its own, the answers sent together.
    case batch([IncomingMessage])
    /// No message can be read; answered once, to the `null` id.
    case unreadable(RPCError)

    /// What `body` holds.
    public init(_ body: Data) {
        guard let value = try? ToolingJSON.decoder().decode(JSONValue.self, from: body) else {
            self = .unreadable(.parseError("The message is not JSON."))
            return
        }
        switch value {
        case .array(let messages) where messages.isEmpty:
            self = .unreadable(.invalidRequest("A batch holds at least one message."))
        case .array(let messages):
            self = .batch(messages.map(IncomingMessage.init))
        default:
            self = .single(IncomingMessage(value))
        }
    }
}
