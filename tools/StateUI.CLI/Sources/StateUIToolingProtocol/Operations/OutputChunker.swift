// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation

/// A stream's bytes in pieces an event carries: below 64 KiB, cut where a character ends, UTF-8 as text and
/// anything else as Base64.
/// Design: docs/design/tooling/protocol.md#an-operation-and-its-events
enum OutputChunker {
    /// The most bytes one chunk carries before it is encoded.
    static let limit = 64 * 1024 - 1

    /// `bytes` in chunks, each with how its data is written.
    static func chunks(of bytes: [UInt8]) -> [(encoding: OutputChunk.Encoding, data: String, count: Int)] {
        var chunks: [(OutputChunk.Encoding, String, Int)] = []
        var start = 0
        while start < bytes.count {
            var end = min(start + limit, bytes.count)
            while end < bytes.count, end > start + limit - 3, bytes[end] & 0xC0 == 0x80 { end -= 1 }
            let piece = Array(bytes[start..<end])
            if let text = String(validating: piece, as: UTF8.self) {
                chunks.append((.utf8, text, piece.count))
            } else {
                chunks.append((.base64, Data(piece).base64EncodedString(), piece.count))
            }
            start = end
        }
        return chunks
    }
}
