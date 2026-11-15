// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation

/// A message as a connection carries it: `Content-Length`, a blank line, the JSON.
public enum Frame {
    /// The frame carrying `message`.
    public static func encode(_ message: OutgoingMessage) throws -> Data {
        let body = try ToolingJSON.encoder().encode(message)
        return Data("Content-Length: \(body.count)\r\n\r\n".utf8) + body
    }
}
