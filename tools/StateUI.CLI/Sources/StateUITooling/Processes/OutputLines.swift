// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// Bytes cut into lines as they arrive: at each line feed, a carriage return before it dropped.
/// Design: docs/design/tooling/processes.md#output-comes-in-lines
struct OutputLines {
    /// The longest line given whole, in bytes; a longer one comes in pieces.
    let limit: Int
    private var pending: [UInt8] = []

    init(limit: Int = 64 * 1024) {
        self.limit = limit
    }

    /// The lines `bytes` complete.
    mutating func take(_ bytes: some Sequence<UInt8>) -> [String] {
        var lines: [String] = []
        for byte in bytes {
            if byte == 0x0A {
                if pending.last == 0x0D { pending.removeLast() }
                lines.append(String(decoding: pending, as: UTF8.self))
                pending.removeAll(keepingCapacity: true)
            } else {
                pending.append(byte)
                if pending.count > limit { lines.append(piece()) }
            }
        }
        return lines
    }

    /// The last line, when the bytes ended without a line feed.
    mutating func finish() -> String? {
        guard !pending.isEmpty else { return nil }
        defer { pending.removeAll() }
        return String(decoding: pending, as: UTF8.self)
    }

    /// The first `limit` bytes of the pending line, cut before a character that would be split.
    private mutating func piece() -> String {
        var end = limit
        while end > 0, pending[end] & 0xC0 == 0x80 { end -= 1 }
        if end == 0 { end = limit }
        defer { pending.removeFirst(end) }
        return String(decoding: pending[..<end], as: UTF8.self)
    }
}
