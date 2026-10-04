// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A `Decoder` over a parsed tree: the value a text was written from.
// Design: docs/design/core/scenes.md#what-the-platform-keeps

/// What a read answers where the text is not the value asked for.
private func mismatch(_ type: Any.Type, _ path: [CodingKey]) -> DecodingError {
    .typeMismatch(type, .init(codingPath: path, debugDescription: "not a \(type)"))
}

extension ValueText {
    struct Reading: Decoder {
        let tree: Tree
        let codingPath: [CodingKey]
        var userInfo: [CodingUserInfoKey: Any] { [:] }

        func container<Key: CodingKey>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> {
            guard case .object(let members) = tree else { throw mismatch([String: Any].self, codingPath) }

            return KeyedDecodingContainer(KeyedReading<Key>(members: members, codingPath: codingPath))
        }

        func unkeyedContainer() throws -> UnkeyedDecodingContainer {
            guard case .array(let items) = tree else { throw mismatch([Any].self, codingPath) }

            return UnkeyedReading(items: items, codingPath: codingPath)
        }

        func singleValueContainer() throws -> SingleValueDecodingContainer {
            SingleReading(tree: tree, codingPath: codingPath)
        }
    }

    private struct KeyedReading<Key: CodingKey>: KeyedDecodingContainerProtocol {
        let members: [(key: String, value: Tree)]
        let codingPath: [CodingKey]

        var allKeys: [Key] { members.compactMap { Key(stringValue: $0.key) } }

        func contains(_ key: Key) -> Bool { members.contains { $0.key == key.stringValue } }

        private func member(_ key: Key) throws -> Tree {
            guard let found = members.first(where: { $0.key == key.stringValue }) else {
                throw DecodingError.keyNotFound(
                    key, .init(codingPath: codingPath, debugDescription: "no \(key.stringValue)"))
            }

            return found.value
        }

        private func take<T: Decodable>(_ type: T.Type, _ key: Key) throws -> T {
            try T(from: Reading(tree: member(key), codingPath: codingPath + [key]))
        }

        func decodeNil(forKey key: Key) throws -> Bool {
            if case .null = try member(key) { return true }

            return false
        }

        func decode(_ type: Bool.Type, forKey key: Key) throws -> Bool { try take(type, key) }
        func decode(_ type: String.Type, forKey key: Key) throws -> String { try take(type, key) }
        func decode(_ type: Double.Type, forKey key: Key) throws -> Double { try take(type, key) }
        func decode(_ type: Float.Type, forKey key: Key) throws -> Float { try take(type, key) }
        func decode(_ type: Int.Type, forKey key: Key) throws -> Int { try take(type, key) }
        func decode(_ type: Int8.Type, forKey key: Key) throws -> Int8 { try take(type, key) }
        func decode(_ type: Int16.Type, forKey key: Key) throws -> Int16 { try take(type, key) }
        func decode(_ type: Int32.Type, forKey key: Key) throws -> Int32 { try take(type, key) }
        func decode(_ type: Int64.Type, forKey key: Key) throws -> Int64 { try take(type, key) }
        func decode(_ type: UInt.Type, forKey key: Key) throws -> UInt { try take(type, key) }
        func decode(_ type: UInt8.Type, forKey key: Key) throws -> UInt8 { try take(type, key) }
        func decode(_ type: UInt16.Type, forKey key: Key) throws -> UInt16 { try take(type, key) }
        func decode(_ type: UInt32.Type, forKey key: Key) throws -> UInt32 { try take(type, key) }
        func decode(_ type: UInt64.Type, forKey key: Key) throws -> UInt64 { try take(type, key) }
        func decode<T: Decodable>(_ type: T.Type, forKey key: Key) throws -> T { try take(type, key) }

        func nestedContainer<NestedKey: CodingKey>(
            keyedBy type: NestedKey.Type,
            forKey key: Key
        ) throws -> KeyedDecodingContainer<NestedKey> {
            try Reading(tree: member(key), codingPath: codingPath + [key]).container(keyedBy: type)
        }

        func nestedUnkeyedContainer(forKey key: Key) throws -> UnkeyedDecodingContainer {
            try Reading(tree: member(key), codingPath: codingPath + [key]).unkeyedContainer()
        }

        func superDecoder() throws -> Decoder {
            let found = members.first { $0.key == PlaceKey.superKey.stringValue }?.value ?? .null
            return Reading(tree: found, codingPath: codingPath + [PlaceKey.superKey])
        }

        func superDecoder(forKey key: Key) throws -> Decoder {
            Reading(tree: try member(key), codingPath: codingPath + [key])
        }
    }

    private struct UnkeyedReading: UnkeyedDecodingContainer {
        let items: [Tree]
        let codingPath: [CodingKey]
        var currentIndex = 0

        var count: Int? { items.count }
        var isAtEnd: Bool { currentIndex >= items.count }

        private mutating func next() throws -> (tree: Tree, key: CodingKey) {
            guard !isAtEnd else {
                throw DecodingError.valueNotFound(
                    Any.self, .init(codingPath: codingPath, debugDescription: "no more items"))
            }

            let key = PlaceKey(intValue: currentIndex)
            currentIndex += 1
            return (items[currentIndex - 1], key)
        }

        private mutating func take<T: Decodable>(_ type: T.Type) throws -> T {
            let item = try next()
            return try T(from: Reading(tree: item.tree, codingPath: codingPath + [item.key]))
        }

        mutating func decodeNil() throws -> Bool {
            guard !isAtEnd, case .null = items[currentIndex] else { return false }

            currentIndex += 1
            return true
        }

        mutating func decode(_ type: Bool.Type) throws -> Bool { try take(type) }
        mutating func decode(_ type: String.Type) throws -> String { try take(type) }
        mutating func decode(_ type: Double.Type) throws -> Double { try take(type) }
        mutating func decode(_ type: Float.Type) throws -> Float { try take(type) }
        mutating func decode(_ type: Int.Type) throws -> Int { try take(type) }
        mutating func decode(_ type: Int8.Type) throws -> Int8 { try take(type) }
        mutating func decode(_ type: Int16.Type) throws -> Int16 { try take(type) }
        mutating func decode(_ type: Int32.Type) throws -> Int32 { try take(type) }
        mutating func decode(_ type: Int64.Type) throws -> Int64 { try take(type) }
        mutating func decode(_ type: UInt.Type) throws -> UInt { try take(type) }
        mutating func decode(_ type: UInt8.Type) throws -> UInt8 { try take(type) }
        mutating func decode(_ type: UInt16.Type) throws -> UInt16 { try take(type) }
        mutating func decode(_ type: UInt32.Type) throws -> UInt32 { try take(type) }
        mutating func decode(_ type: UInt64.Type) throws -> UInt64 { try take(type) }
        mutating func decode<T: Decodable>(_ type: T.Type) throws -> T { try take(type) }

        mutating func nestedContainer<NestedKey: CodingKey>(
            keyedBy type: NestedKey.Type
        ) throws -> KeyedDecodingContainer<NestedKey> {
            let item = try next()
            return try Reading(tree: item.tree, codingPath: codingPath + [item.key]).container(keyedBy: type)
        }

        mutating func nestedUnkeyedContainer() throws -> UnkeyedDecodingContainer {
            let item = try next()
            return try Reading(tree: item.tree, codingPath: codingPath + [item.key]).unkeyedContainer()
        }

        mutating func superDecoder() throws -> Decoder {
            let item = try next()
            return Reading(tree: item.tree, codingPath: codingPath + [item.key])
        }
    }

    private struct SingleReading: SingleValueDecodingContainer {
        let tree: Tree
        let codingPath: [CodingKey]

        func decodeNil() -> Bool {
            if case .null = tree { return true }

            return false
        }

        func decode(_ type: Bool.Type) throws -> Bool {
            guard case .bool(let value) = tree else { throw mismatch(type, codingPath) }

            return value
        }

        func decode(_ type: String.Type) throws -> String {
            guard case .string(let value) = tree else { throw mismatch(type, codingPath) }

            return value
        }

        func decode(_ type: Double.Type) throws -> Double {
            guard case .number(let text) = tree, let value = Double(text) else {
                throw mismatch(type, codingPath)
            }

            return value
        }

        func decode(_ type: Float.Type) throws -> Float { Float(try decode(Double.self)) }
        func decode(_ type: Int.Type) throws -> Int { try whole(type) }
        func decode(_ type: Int8.Type) throws -> Int8 { try whole(type) }
        func decode(_ type: Int16.Type) throws -> Int16 { try whole(type) }
        func decode(_ type: Int32.Type) throws -> Int32 { try whole(type) }
        func decode(_ type: Int64.Type) throws -> Int64 { try whole(type) }
        func decode(_ type: UInt.Type) throws -> UInt { try whole(type) }
        func decode(_ type: UInt8.Type) throws -> UInt8 { try whole(type) }
        func decode(_ type: UInt16.Type) throws -> UInt16 { try whole(type) }
        func decode(_ type: UInt32.Type) throws -> UInt32 { try whole(type) }
        func decode(_ type: UInt64.Type) throws -> UInt64 { try whole(type) }

        func decode<T: Decodable>(_ type: T.Type) throws -> T {
            try T(from: Reading(tree: tree, codingPath: codingPath))
        }

        private func whole<T: FixedWidthInteger>(_ type: T.Type) throws -> T {
            guard case .number(let text) = tree, let value = T(text) else {
                throw mismatch(type, codingPath)
            }

            return value
        }
    }
}
