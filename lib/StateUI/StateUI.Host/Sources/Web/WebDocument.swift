// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// Where a WebKit web view goes to show a document written in place with no address of its own: a `data:` address
/// holding it, which WebKit keeps in the page's history as any other - of a document shown without one it keeps none.
/// Design: docs/design/host/web.md#a-document-with-no-address
@_spi(Host) public enum WebDocument {
    /// The `data:` address holding `document`, its words as UTF-8 in base64.
    public static func address(of document: String) -> String {
        prefix + base64(Array(document.utf8))
    }

    /// The document the `data:` address `address` holds; nil for any other address.
    public static func document(at address: String) -> String? {
        guard address.hasPrefix(prefix), let bytes = bytes(base64: address.dropFirst(prefix.count)) else { return nil }
        return String(decoding: bytes, as: UTF8.self)
    }

    /// What every such address starts with.
    static let prefix = "data:text/html;charset=utf-8;base64,"

    /// `bytes` in base64, padded to whole groups of four.
    static func base64(_ bytes: [UInt8]) -> String {
        let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/")
        var written = ""
        for start in stride(from: 0, to: bytes.count, by: 3) {
            let group = Array(bytes[start..<min(start + 3, bytes.count)])
            let number = group.enumerated().reduce(0) { $0 | Int($1.element) << (16 - 8 * $1.offset) }
            for place in 0..<4 {
                written.append(place <= group.count ? alphabet[(number >> (18 - 6 * place)) & 63] : "=")
            }
        }
        return written
    }

    /// The bytes `text` holds in base64, padded to whole groups of four; nil for text that is not.
    static func bytes(base64 text: Substring) -> [UInt8]? {
        let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/".utf8)
        let digits = Array(text.utf8)
        guard digits.count % 4 == 0 else { return nil }
        var bytes: [UInt8] = []
        for start in stride(from: 0, to: digits.count, by: 4) {
            let group = digits[start..<start + 4]
            let padding = group.reversed().prefix { $0 == UInt8(ascii: "=") }.count
            guard padding <= 2, start + 4 == digits.count || padding == 0 else { return nil }
            var number = 0
            for digit in group.dropLast(padding) {
                guard let value = alphabet.firstIndex(of: digit) else { return nil }
                number = number << 6 | value
            }
            number <<= 6 * padding
            bytes += [UInt8(number >> 16 & 255), UInt8(number >> 8 & 255), UInt8(number & 255)].prefix(3 - padding)
        }
        return bytes
    }
}
