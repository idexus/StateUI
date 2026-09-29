// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A value on its way to text: an `Encoder` filling a tree of written values,
// which then appends itself as JSON.
// Design: docs/design/core/scenes.md#what-the-platform-keeps

extension ValueText {
    /// One value on its way to text - a reference, so that a container handed out
    /// early can still fill in what it stands for.
    final class Written {
        enum Kind {
            case null
            case bool(Bool)
            case number(String)
            case string(String)
            case array([Written])
            case object([(key: String, value: Written)])
        }

        var kind: Kind = .null

        /// Appends this value's JSON.
        func append(to text: inout String) {
            switch kind {
            case .null:
                text += "null"
            case .bool(let value):
                text += value ? "true" : "false"
            case .number(let value):
                text += value
            case .string(let value):
                Written.quote(value, into: &text)
            case .array(let items):
                text += "["

                for (index, item) in items.enumerated() {
                    if index > 0 { text += "," }
                    item.append(to: &text)
                }

                text += "]"
            case .object(let members):
                text += "{"

                for (index, member) in members.enumerated() {
                    if index > 0 { text += "," }
                    Written.quote(member.key, into: &text)
                    text += ":"
                    member.value.append(to: &text)
                }

                text += "}"
            }
        }

        /// A string as JSON writes one.
        static func quote(_ value: String, into text: inout String) {
            text += "\""

            // By the scalar's number: the quote, the backslash and the three
            // controls JSON has a letter for, then every other control as four
            // hex digits.
            for scalar in value.unicodeScalars {
                switch scalar.value {
                case 0x22: text += "\\\""
                case 0x5C: text += "\\\\"
                case 0x0A: text += "\\n"
                case 0x0D: text += "\\r"
                case 0x09: text += "\\t"
                case ..<0x20:
                    let hex = String(scalar.value, radix: 16)
                    text += "\\u" + String(repeating: "0", count: 4 - hex.count) + hex
                default:
                    text.unicodeScalars.append(scalar)
                }
            }

            text += "\""
        }

        /// The child a keyed container writes under `key`, replacing one written
        /// under it before.
        func member(_ key: String) -> Written {
            let child = Written()

            guard case .object(var members) = kind else { return child }

            if let index = members.firstIndex(where: { $0.key == key }) {
                members[index].value = child
            } else {
                members.append((key: key, value: child))
            }

            kind = .object(members)
            return child
        }

        /// The child an unkeyed container writes next.
        func next() -> Written {
            let child = Written()

            if case .array(var items) = kind {
                items.append(child)
                kind = .array(items)
            }

            return child
        }

        /// How many items an unkeyed container has written.
        var count: Int {
            if case .array(let items) = kind { return items.count }

            return 0
        }
    }

    struct Writing: Encoder {
        let into: Written
        let codingPath: [CodingKey]
        var userInfo: [CodingUserInfoKey: Any] { [:] }

        func container<Key: CodingKey>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> {
            if case .object = into.kind {} else { into.kind = .object([]) }

            return KeyedEncodingContainer(KeyedWriting<Key>(into: into, codingPath: codingPath))
        }

        func unkeyedContainer() -> UnkeyedEncodingContainer {
            if case .array = into.kind {} else { into.kind = .array([]) }

            return UnkeyedWriting(into: into, codingPath: codingPath)
        }

        func singleValueContainer() -> SingleValueEncodingContainer {
            SingleWriting(into: into, codingPath: codingPath)
        }
    }

    private struct KeyedWriting<Key: CodingKey>: KeyedEncodingContainerProtocol {
        let into: Written
        let codingPath: [CodingKey]

        /// Every value goes through here, primitives included - which is how a
        /// primitive reaches the single-value container that knows its spelling.
        private func put<T: Encodable>(_ value: T, _ key: Key) throws {
            try value.encode(to: Writing(into: into.member(key.stringValue), codingPath: codingPath + [key]))
        }

        mutating func encodeNil(forKey key: Key) throws { into.member(key.stringValue).kind = .null }
        mutating func encode(_ value: Bool, forKey key: Key) throws { try put(value, key) }
        mutating func encode(_ value: String, forKey key: Key) throws { try put(value, key) }
        mutating func encode(_ value: Double, forKey key: Key) throws { try put(value, key) }
        mutating func encode(_ value: Float, forKey key: Key) throws { try put(value, key) }
        mutating func encode(_ value: Int, forKey key: Key) throws { try put(value, key) }
        mutating func encode(_ value: Int8, forKey key: Key) throws { try put(value, key) }
        mutating func encode(_ value: Int16, forKey key: Key) throws { try put(value, key) }
        mutating func encode(_ value: Int32, forKey key: Key) throws { try put(value, key) }
        mutating func encode(_ value: Int64, forKey key: Key) throws { try put(value, key) }
        mutating func encode(_ value: UInt, forKey key: Key) throws { try put(value, key) }
        mutating func encode(_ value: UInt8, forKey key: Key) throws { try put(value, key) }
        mutating func encode(_ value: UInt16, forKey key: Key) throws { try put(value, key) }
        mutating func encode(_ value: UInt32, forKey key: Key) throws { try put(value, key) }
        mutating func encode(_ value: UInt64, forKey key: Key) throws { try put(value, key) }
        mutating func encode<T: Encodable>(_ value: T, forKey key: Key) throws { try put(value, key) }

        mutating func nestedContainer<NestedKey: CodingKey>(
            keyedBy keyType: NestedKey.Type,
            forKey key: Key
        ) -> KeyedEncodingContainer<NestedKey> {
            Writing(into: into.member(key.stringValue), codingPath: codingPath + [key])
                .container(keyedBy: keyType)
        }

        mutating func nestedUnkeyedContainer(forKey key: Key) -> UnkeyedEncodingContainer {
            Writing(into: into.member(key.stringValue), codingPath: codingPath + [key]).unkeyedContainer()
        }

        mutating func superEncoder() -> Encoder {
            Writing(into: into.member(PlaceKey.superKey.stringValue), codingPath: codingPath + [PlaceKey.superKey])
        }

        mutating func superEncoder(forKey key: Key) -> Encoder {
            Writing(into: into.member(key.stringValue), codingPath: codingPath + [key])
        }
    }

    private struct UnkeyedWriting: UnkeyedEncodingContainer {
        let into: Written
        let codingPath: [CodingKey]
        var count: Int { into.count }

        private func put<T: Encodable>(_ value: T) throws {
            let key = PlaceKey(intValue: count)
            try value.encode(to: Writing(into: into.next(), codingPath: codingPath + [key]))
        }

        mutating func encodeNil() throws { into.next().kind = .null }
        mutating func encode(_ value: Bool) throws { try put(value) }
        mutating func encode(_ value: String) throws { try put(value) }
        mutating func encode(_ value: Double) throws { try put(value) }
        mutating func encode(_ value: Float) throws { try put(value) }
        mutating func encode(_ value: Int) throws { try put(value) }
        mutating func encode(_ value: Int8) throws { try put(value) }
        mutating func encode(_ value: Int16) throws { try put(value) }
        mutating func encode(_ value: Int32) throws { try put(value) }
        mutating func encode(_ value: Int64) throws { try put(value) }
        mutating func encode(_ value: UInt) throws { try put(value) }
        mutating func encode(_ value: UInt8) throws { try put(value) }
        mutating func encode(_ value: UInt16) throws { try put(value) }
        mutating func encode(_ value: UInt32) throws { try put(value) }
        mutating func encode(_ value: UInt64) throws { try put(value) }
        mutating func encode<T: Encodable>(_ value: T) throws { try put(value) }

        mutating func nestedContainer<NestedKey: CodingKey>(
            keyedBy keyType: NestedKey.Type
        ) -> KeyedEncodingContainer<NestedKey> {
            let key = PlaceKey(intValue: count)
            return Writing(into: into.next(), codingPath: codingPath + [key]).container(keyedBy: keyType)
        }

        mutating func nestedUnkeyedContainer() -> UnkeyedEncodingContainer {
            let key = PlaceKey(intValue: count)
            return Writing(into: into.next(), codingPath: codingPath + [key]).unkeyedContainer()
        }

        mutating func superEncoder() -> Encoder {
            let key = PlaceKey(intValue: count)
            return Writing(into: into.next(), codingPath: codingPath + [key])
        }
    }

    private struct SingleWriting: SingleValueEncodingContainer {
        let into: Written
        let codingPath: [CodingKey]

        mutating func encodeNil() throws { into.kind = .null }
        mutating func encode(_ value: Bool) throws { into.kind = .bool(value) }
        mutating func encode(_ value: String) throws { into.kind = .string(value) }
        mutating func encode(_ value: Double) throws { into.kind = .number(try number(value)) }
        mutating func encode(_ value: Float) throws { into.kind = .number(try number(Double(value))) }
        mutating func encode(_ value: Int) throws { into.kind = .number(String(value)) }
        mutating func encode(_ value: Int8) throws { into.kind = .number(String(value)) }
        mutating func encode(_ value: Int16) throws { into.kind = .number(String(value)) }
        mutating func encode(_ value: Int32) throws { into.kind = .number(String(value)) }
        mutating func encode(_ value: Int64) throws { into.kind = .number(String(value)) }
        mutating func encode(_ value: UInt) throws { into.kind = .number(String(value)) }
        mutating func encode(_ value: UInt8) throws { into.kind = .number(String(value)) }
        mutating func encode(_ value: UInt16) throws { into.kind = .number(String(value)) }
        mutating func encode(_ value: UInt32) throws { into.kind = .number(String(value)) }
        mutating func encode(_ value: UInt64) throws { into.kind = .number(String(value)) }

        mutating func encode<T: Encodable>(_ value: T) throws {
            try value.encode(to: Writing(into: into, codingPath: codingPath))
        }

        /// A number as JSON can say it - Swift's own description, which reads
        /// back to the same double.
        private func number(_ value: Double) throws -> String {
            guard value.isFinite else {
                throw EncodingError.invalidValue(
                    value, .init(codingPath: codingPath, debugDescription: "JSON has no \(value)"))
            }

            return "\(value)"
        }
    }
}
