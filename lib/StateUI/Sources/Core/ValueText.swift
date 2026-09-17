// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A value written down as TEXT, and read back.
//
// What a window of a scene is opened FOR - a document's number, an item's id -
// is kept by the platform while the application is not running, so that the
// window comes back for the same value when the system restores the scene. The
// platform keeps text, and a window's value is any `Codable` the author chose,
// so this is the one road between the two.
//
// `Codable` is the standard library's, and so is everything here: the text is
// JSON, written and read by hand the way Core/Wire.swift writes the wire, with
// an object's members in the order the value encoded them - so one value is
// one text, in every run.

/// A `Codable` value as text, and back.
enum ValueText {
    /// The text a value is written down as.
    ///
    /// - Parameter value: what to write.
    /// - Returns: its JSON.
    /// - Throws: what the value's own `encode(to:)` throws, and an error for a
    ///   number JSON cannot say - an infinity, not a number.
    static func write<Value: Encodable>(_ value: Value) throws -> String {
        let root = Written()
        try value.encode(to: Writing(into: root, codingPath: []))

        var text = ""
        root.append(to: &text)
        return text
    }

    /// The value a text was written from - nothing where the text is not JSON,
    /// or not a `Value`.
    ///
    /// - Parameters:
    ///   - type: what to read.
    ///   - text: what `write` made.
    static func read<Value: Decodable>(_ type: Value.Type, from text: String) -> Value? {
        var parser = Parser(bytes: Array(text.utf8))

        guard let tree = parser.document() else { return nil }

        return try? Value(from: Reading(tree: tree, codingPath: []))
    }
}

// MARK: - Writing

/// One value on its way to text - a reference, so that a container handed out
/// early can still fill in what it stands for.
private final class Written {
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

/// A key for a place that has no key of its own - an array's index, the
/// member a superclass is written under.
private struct PlaceKey: CodingKey {
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

private struct Writing: Encoder {
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

// MARK: - Reading

/// A value as the text said it.
private indirect enum Tree {
    case null
    case bool(Bool)
    case number(String)
    case string(String)
    case array([Tree])
    case object([(key: String, value: Tree)])
}

/// JSON, read off its bytes.
private struct Parser {
    let bytes: [UInt8]
    var at = 0

    /// The one value the text holds, and nothing after it.
    mutating func document() -> Tree? {
        guard let tree = value() else { return nil }

        skip()
        return at == bytes.count ? tree : nil
    }

    private mutating func skip() {
        while at < bytes.count, [0x20, 0x0A, 0x0D, 0x09].contains(bytes[at]) {
            at += 1
        }
    }

    private mutating func value() -> Tree? {
        skip()

        guard at < bytes.count else { return nil }

        switch bytes[at] {
        case UInt8(ascii: "n"): return literal("null", .null)
        case UInt8(ascii: "t"): return literal("true", .bool(true))
        case UInt8(ascii: "f"): return literal("false", .bool(false))
        case UInt8(ascii: "\""): return string().map(Tree.string)
        case UInt8(ascii: "["): return array()
        case UInt8(ascii: "{"): return object()
        default: return number()
        }
    }

    private mutating func literal(_ word: String, _ tree: Tree) -> Tree? {
        let spelled = Array(word.utf8)

        guard at + spelled.count <= bytes.count,
            Array(bytes[at..<at + spelled.count]) == spelled
        else { return nil }

        at += spelled.count
        return tree
    }

    private mutating func number() -> Tree? {
        let start = at

        while at < bytes.count,
            let scalar = Optional(bytes[at]),
            (scalar >= UInt8(ascii: "0") && scalar <= UInt8(ascii: "9"))
                || [UInt8(ascii: "-"), UInt8(ascii: "+"), UInt8(ascii: "."),
                    UInt8(ascii: "e"), UInt8(ascii: "E")].contains(scalar) {
            at += 1
        }

        guard at > start else { return nil }

        return .number(String(decoding: bytes[start..<at], as: UTF8.self))
    }

    private mutating func string() -> String? {
        guard at < bytes.count, bytes[at] == UInt8(ascii: "\"") else { return nil }

        at += 1
        var scalars = String.UnicodeScalarView()
        var run: [UInt8] = []

        func flush() {
            scalars.append(contentsOf: String(decoding: run, as: UTF8.self).unicodeScalars)
            run.removeAll()
        }

        while at < bytes.count {
            let byte = bytes[at]
            at += 1

            switch byte {
            case UInt8(ascii: "\""):
                flush()
                return String(scalars)

            case UInt8(ascii: "\\"):
                flush()

                guard at < bytes.count else { return nil }

                let escape = bytes[at]
                at += 1

                switch escape {
                case UInt8(ascii: "\""): scalars.append("\"")
                case UInt8(ascii: "\\"): scalars.append("\\")
                case UInt8(ascii: "/"): scalars.append("/")
                case UInt8(ascii: "n"): scalars.append("\n")
                case UInt8(ascii: "r"): scalars.append("\r")
                case UInt8(ascii: "t"): scalars.append("\t")
                case UInt8(ascii: "b"): scalars.append("\u{08}")
                case UInt8(ascii: "f"): scalars.append("\u{0C}")
                case UInt8(ascii: "u"):
                    guard let unit = hex() else { return nil }

                    // A pair of halves stands for one scalar past the first
                    // plane.
                    if (0xD800...0xDBFF).contains(unit), at + 1 < bytes.count,
                        bytes[at] == UInt8(ascii: "\\"), bytes[at + 1] == UInt8(ascii: "u") {
                        at += 2

                        guard let low = hex(), (0xDC00...0xDFFF).contains(low),
                            let scalar = Unicode.Scalar(0x10000 + ((unit - 0xD800) << 10) + (low - 0xDC00))
                        else { return nil }

                        scalars.append(scalar)
                    } else {
                        guard let scalar = Unicode.Scalar(unit) else { return nil }

                        scalars.append(scalar)
                    }
                default:
                    return nil
                }

            default:
                run.append(byte)
            }
        }

        return nil
    }

    /// Four hex digits, as a number.
    private mutating func hex() -> UInt32? {
        guard at + 4 <= bytes.count,
            let value = UInt32(String(decoding: bytes[at..<at + 4], as: UTF8.self), radix: 16)
        else { return nil }

        at += 4
        return value
    }

    private mutating func array() -> Tree? {
        at += 1
        var items: [Tree] = []

        skip()
        if at < bytes.count, bytes[at] == UInt8(ascii: "]") {
            at += 1
            return .array(items)
        }

        while true {
            guard let item = value() else { return nil }

            items.append(item)
            skip()

            guard at < bytes.count else { return nil }

            if bytes[at] == UInt8(ascii: ",") {
                at += 1
                continue
            }

            guard bytes[at] == UInt8(ascii: "]") else { return nil }

            at += 1
            return .array(items)
        }
    }

    private mutating func object() -> Tree? {
        at += 1
        var members: [(key: String, value: Tree)] = []

        skip()
        if at < bytes.count, bytes[at] == UInt8(ascii: "}") {
            at += 1
            return .object(members)
        }

        while true {
            skip()

            guard let key = string() else { return nil }

            skip()

            guard at < bytes.count, bytes[at] == UInt8(ascii: ":") else { return nil }

            at += 1

            guard let member = value() else { return nil }

            members.append((key: key, value: member))
            skip()

            guard at < bytes.count else { return nil }

            if bytes[at] == UInt8(ascii: ",") {
                at += 1
                continue
            }

            guard bytes[at] == UInt8(ascii: "}") else { return nil }

            at += 1
            return .object(members)
        }
    }
}

/// What a read answers where the text is not the value asked for.
private func mismatch(_ type: Any.Type, _ path: [CodingKey]) -> DecodingError {
    .typeMismatch(type, .init(codingPath: path, debugDescription: "not a \(type)"))
}

private struct Reading: Decoder {
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
