// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The reader of every channel the host writes: an event's payload, an act's
// reply, a raised event, the store's values, a realization, a declaration and
// an environment push. A buffer that will not read answers nil.
// Design: docs/design/core/wire.md#reading-the-host-channels

extension Wire {
    /// Decodes an event's payload: an empty buffer is an event with nothing to say, and
    /// nil a buffer that would not read.
    /// Design: docs/design/core/wire.md#reading-the-host-channels
    static func decodePayload(_ bytes: [UInt8]) -> [PropValue]? {
        guard !bytes.isEmpty else { return [] }

        var reader = Reader(bytes)

        guard reader.u8() == version, let values = values(&reader), reader.atEnd else {
            return nil
        }

        return values
    }

    /// Decodes an act's outcome; nil for a buffer that would not read, which the caller
    /// turns into a failure rather than a hang.
    static func decodeReply(_ bytes: [UInt8]) -> Reply? {
        var reader = Reader(bytes)

        guard reader.u8() == version, let ok = reader.u8(),
              let values = values(&reader), reader.atEnd else {
            return nil
        }

        if ok == 1 {
            return .finished(values)
        }

        // A failure carries exactly one value: the reason, as text.
        guard let reason = values.first?.string, values.count == 1 else { return nil }
        return .failed(reason)
    }

    /// Decodes an event the host raised by name; nil for a buffer that would not read,
    /// which the caller answers with -1.
    static func decodeHostEvent(_ bytes: [UInt8]) -> (name: String, payload: [PropValue])? {
        var reader = Reader(bytes)

        guard reader.u8() == version, let name = reader.string(),
              let values = values(&reader), reader.atEnd else {
            return nil
        }

        return (name, values)
    }

    /// Decodes what the host read out of the store - a name and a value per key it
    /// found; nil for a buffer that would not read.
    static func decodePersistent(_ bytes: [UInt8]) -> [(name: String, value: PropValue)]? {
        var reader = Reader(bytes)

        guard reader.u8() == version, let count = reader.u16() else { return nil }

        var found: [(name: String, value: PropValue)] = []
        found.reserveCapacity(Int(count))

        for _ in 0..<count {
            guard let name = reader.string(), let value = value(&reader) else { return nil }

            found.append((name: name, value: value))
        }

        return reader.atEnd ? found : nil
    }

    /// Decodes what `encodeDeclaration` writes; nil for a buffer that would not read.
    static func decodeDeclaration(_ bytes: [UInt8]) -> HostDeclaration? {
        var reader = Reader(bytes)

        guard reader.u8() == version, let elements = reader.u16() else { return nil }

        var declaration = HostDeclaration()

        for _ in 0..<elements {
            guard let element = reader.string(), let declared = read(&reader) else { return nil }

            declaration.elements[element] = declared
        }

        guard let shared = read(&reader), let acts = reader.u16() else { return nil }

        declaration.shared = shared

        for _ in 0..<acts {
            guard let act = reader.string() else { return nil }

            declaration.acts.insert(act)
        }

        return reader.atEnd ? declaration : nil
    }

    /// One element's members and then its events, as `encodeDeclaration` wrote them.
    private static func read(_ reader: inout Reader) -> HostDeclaration.Element? {
        guard let members = reader.u16() else { return nil }

        var declared = HostDeclaration.Element()

        for _ in 0..<members {
            guard let member = reader.string() else { return nil }

            declared.members.insert(member)
        }

        guard let events = reader.u16() else { return nil }

        for _ in 0..<events {
            guard let event = reader.string() else { return nil }

            declared.events.insert(event)
        }

        return declared
    }

    /// Decodes what `encodeRealization` writes; nil for a buffer that would not read.
    static func decodeRealization(_ bytes: [UInt8]) -> HostRealization? {
        var reader = Reader(bytes)

        guard reader.u8() == version, let elements = reader.u16() else { return nil }

        var realization = HostRealization()

        for _ in 0..<elements {
            guard let name = reader.string() else { return nil }

            realization.elements.insert(name)
        }

        guard let members = reader.u16() else { return nil }

        for _ in 0..<members {
            guard let element = reader.string(), let owner = reader.string(), let member = reader.string()
            else { return nil }

            realization.members.insert(HostRealizedMember(element: element, owner: owner, member: member))
        }

        return reader.atEnd ? realization : nil
    }

    /// Decodes a standard-environment push: the provider's domain byte, then the
    /// values; nil for a buffer that would not read.
    static func decodeEnvironment(_ bytes: [UInt8]) -> (domain: UInt8, payload: [PropValue])? {
        var reader = Reader(bytes)

        guard reader.u8() == version, let domain = reader.u8(),
              let values = values(&reader), reader.atEnd else {
            return nil
        }

        return (domain, values)
    }

    /// A counted value list - the shape the value channels share.
    private static func values(_ reader: inout Reader) -> [PropValue]? {
        guard let count = reader.u8() else { return nil }

        var values: [PropValue] = []
        values.reserveCapacity(Int(count))

        for _ in 0..<count {
            guard let value = value(&reader) else { return nil }
            values.append(value)
        }

        return values
    }

    /// One tagged value, the mirror of `[UInt8].value(_:)`. No arm for a name: the
    /// host never sends one.
    private static func value(_ reader: inout Reader, depth: Int = 0) -> PropValue? {
        switch reader.u8() {
        case 1:
            return .bool(false)
        case 2:
            return .bool(true)
        case 3:
            return reader.f64().map { .number($0) }
        case 4:
            return reader.string().map { .string($0) }
        case 5:
            guard let count = reader.u16() else { return nil }
            var numbers: [Double] = []
            numbers.reserveCapacity(Int(count))
            for _ in 0..<count {
                guard let number = reader.f64() else { return nil }
                numbers.append(number)
            }
            return .numbers(numbers)
        case 6:
            guard let count = reader.u16() else { return nil }
            var strings: [String] = []
            strings.reserveCapacity(Int(count))
            for _ in 0..<count {
                guard let text = reader.string() else { return nil }
                strings.append(text)
            }
            return .strings(strings)
        case 8:
            guard let red = reader.u8(), let green = reader.u8(),
                  let blue = reader.u8(), let alpha = reader.u8()
            else { return nil }
            return .color(red: red, green: green, blue: blue, alpha: alpha)
        case 9:
            guard depth < mostNesting, let count = reader.u16() else { return nil }
            var values: [PropValue] = []
            values.reserveCapacity(Int(count))
            for _ in 0..<count {
                guard let value = value(&reader, depth: depth + 1) else { return nil }
                values.append(value)
            }
            return .values(values)
        case 10:
            return reader.i32().map { .enumeration($0) }
        case 12:
            return .nothing
        default:
            return nil
        }
    }

    /// A bounds-checked cursor over one message: every read past the end answers nil.
    private struct Reader {
        private let bytes: [UInt8]
        private var offset = 0

        init(_ bytes: [UInt8]) {
            self.bytes = bytes
        }

        var atEnd: Bool { offset == bytes.count }

        mutating func u8() -> UInt8? {
            guard offset < bytes.count else { return nil }
            defer { offset += 1 }
            return bytes[offset]
        }

        mutating func u16() -> UInt16? {
            guard let low = u8(), let high = u8() else { return nil }
            return UInt16(low) | UInt16(high) << 8
        }

        mutating func i32() -> Int32? {
            guard let low = u16(), let high = u16() else { return nil }
            return Int32(bitPattern: UInt32(low) | UInt32(high) << 16)
        }

        mutating func f64() -> Double? {
            guard offset + 8 <= bytes.count else { return nil }
            var bits: UInt64 = 0
            for index in (0..<8).reversed() {
                bits = bits << 8 | UInt64(bytes[offset + index])
            }
            offset += 8
            return Double(bitPattern: bits)
        }

        mutating func string() -> String? {
            guard let low = u16(), let high = u16() else { return nil }

            // Compared unsigned and 32 bits wide against what is left, so a 32-bit target
            // refuses a huge length rather than trapping.
            // Design: docs/design/core/wire.md#limits
            let stated = UInt64(UInt32(low) | UInt32(high) << 16)
            guard stated <= UInt64(bytes.count - offset) else { return nil }

            let count = Int(stated)
            defer { offset += count }
            return String(decoding: bytes[offset..<offset + count], as: UTF8.self)
        }
    }
}
