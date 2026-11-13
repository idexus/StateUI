// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A piece of a program's output, below 64 KiB before it is encoded.
public struct OutputChunk: Codable, Equatable, Sendable {
    /// How a chunk's bytes are written.
    public enum Encoding: String, Codable, Sendable {
        /// As text: the bytes are UTF-8.
        case utf8
        /// As Base64: bytes that are not UTF-8, kept as they are.
        case base64
    }

    /// The stream it came on.
    public var stream: StandardStream
    /// How `data` holds the bytes.
    public var encoding: Encoding
    /// The bytes, as `encoding` writes them.
    public var data: String
    /// Where the stream stands after this chunk; opaque to a client.
    public var cursor: String

    /// A chunk of `stream`.
    public init(stream: StandardStream, encoding: Encoding, data: String, cursor: String) {
        self.stream = stream
        self.encoding = encoding
        self.data = data
        self.cursor = cursor
    }
}
