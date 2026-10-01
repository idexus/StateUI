// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What a script run in a web page answers, from the JSON the platform writes its value in: words as they are, a
/// number as it is written, anything else as JSON.
/// Design: docs/design/host/web.md#a-scripts-answer
@_spi(Host) public enum ScriptAnswer {
    /// The answer `json` writes; nil for none - no value, `null`, or `undefined`.
    public static func text(json: String?) -> String? {
        guard let json else { return nil }
        let value = json.trimmingSpaces
        if value.isEmpty || value == "null" || value == "undefined" { return nil }
        guard value.first == "\"" else { return value }
        return words(value) ?? value
    }

    /// The words a JSON string writes; nil where it is none.
    static func words(_ string: String) -> String? {
        var scalars = Array(string.unicodeScalars).dropFirst()
        var result = String.UnicodeScalarView()
        var pendingHigh: UInt32?
        while let scalar = scalars.popFirst() {
            if scalar == "\"" { return scalars.isEmpty ? String(result) : nil }
            guard scalar == "\\" else {
                result.append(scalar)
                continue
            }
            guard let escaped = scalars.popFirst() else { return nil }
            switch escaped {
            case "n": result.append("\n")
            case "t": result.append("\t")
            case "r": result.append("\r")
            case "b": result.append("\u{8}")
            case "f": result.append("\u{C}")
            case "u":
                let hex = String(String.UnicodeScalarView(scalars.prefix(4)))
                guard hex.count == 4, let unit = UInt32(hex, radix: 16) else { return nil }
                scalars = scalars.dropFirst(4)
                if (0xD800..<0xDC00).contains(unit) {
                    pendingHigh = unit
                } else if let high = pendingHigh, (0xDC00..<0xE000).contains(unit) {
                    pendingHigh = nil
                    guard let joined = Unicode.Scalar(0x10000 + (high - 0xD800) << 10 + (unit - 0xDC00)) else { return nil }
                    result.append(joined)
                } else if let lone = Unicode.Scalar(unit) {
                    result.append(lone)
                }
            default: result.append(escaped)
            }
        }
        return nil
    }
}

private extension String {
    /// Without the spaces, tabs and line ends at either end.
    var trimmingSpaces: String {
        let spaces: Set<Character> = [" ", "\t", "\n", "\r"]
        return String(drop { spaces.contains($0) }.reversed().drop { spaces.contains($0) }.reversed())
    }
}
