// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A `Codable` value written down as text and read back: what a scene's window is
// opened for, kept by the platform as JSON written and read by hand.
// Design: docs/design/core/scenes.md#what-the-platform-keeps

/// A `Codable` value as text, and back.
enum ValueText {
    /// The JSON a value is written down as. Throws what the value's own `encode(to:)`
    /// throws, and for a number JSON cannot say - an infinity, not a number.
    static func write<Value: Encodable>(_ value: Value) throws -> String {
        let root = Written()
        try value.encode(to: Writing(into: root, codingPath: []))

        var text = ""
        root.append(to: &text)
        return text
    }

    /// The value a text `write` made was written from - nothing where the text is
    /// not JSON, or not a `Value`.
    static func read<Value: Decodable>(_ type: Value.Type, from text: String) -> Value? {
        var parser = Parser(bytes: Array(text.utf8))

        guard let tree = parser.document() else { return nil }

        return try? Value(from: Reading(tree: tree, codingPath: []))
    }
}

extension ValueText {
    /// A key for a place that has no key of its own - an array's index, the
    /// member a superclass is written under.
    struct PlaceKey: CodingKey {
        let stringValue: String
        let intValue: Int?

        init(stringValue: String) {
            self.stringValue = stringValue
            intValue = nil
        }

        init(intValue: Int) {
            stringValue = "\(intValue)"
            self.intValue = intValue
        }

        static let superKey = PlaceKey(stringValue: "super")
    }
}
