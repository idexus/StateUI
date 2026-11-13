// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation

/// How every message of the tooling API is written and read: one message, the same bytes.
public enum ToolingJSON {
    /// An encoder writing keys in sorted order and slashes unescaped; `pretty` lays a message out over lines.
    public static func encoder(pretty: Bool = false) -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = pretty
            ? [.sortedKeys, .withoutEscapingSlashes, .prettyPrinted]
            : [.sortedKeys, .withoutEscapingSlashes]
        return encoder
    }

    /// A decoder for the messages `encoder` writes.
    public static func decoder() -> JSONDecoder {
        JSONDecoder()
    }
}
