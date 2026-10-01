// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// Where a WebKit web view goes to show a document written in place with no address of its own: a `data:` address
/// holding it, which WebKit keeps in the page's history as any other - of a document shown without one it keeps none.
/// Design: docs/design/host/web.md#a-document-with-no-address
@_spi(Host) public enum WebDocument {
    /// The `data:` address holding `document`, its words as UTF-8 in base64.
    public static func address(of document: String) -> String {
        "data:text/html;charset=utf-8;base64," + base64(Array(document.utf8))
    }

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
}
