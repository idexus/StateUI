// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// Bytes written in base64, the words a relay carries a picture's bytes in.
@_spi(Host) public enum Base64 {
    private static let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/")

    /// `bytes` in base64, padded with `=` to a whole four characters.
    public static func encoded(_ bytes: [UInt8]) -> String {
        var text = ""
        text.reserveCapacity((bytes.count + 2) / 3 * 4)
        var index = 0
        while index < bytes.count {
            let chunk = bytes[index..<min(index + 3, bytes.count)]
            let value = chunk.enumerated().reduce(0) { $0 | Int($1.element) << (16 - 8 * $1.offset) }
            for place in 0..<4 {
                text.append(place <= chunk.count ? alphabet[(value >> (18 - 6 * place)) & 63] : "=")
            }
            index += 3
        }
        return text
    }
}
