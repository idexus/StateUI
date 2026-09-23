// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The Wire: the patch, the acts and the host's reports as deterministic bytes, for
// a runtime that cannot read Swift types. Little-endian and fixed width; every
// name rides the session's dictionary.
// Design: docs/design/core/wire.md#bytes-rather-than-text

/// One session's numbering of every name the wire carries, announced by the first
/// message that uses each. Touched only while encoding, on the host's one thread.
/// Design: docs/design/core/wire.md#the-dictionary
final class WireDictionary {
    private var ids: [String: UInt16] = [:]
    private var pending: [(id: UInt16, name: String)] = []
    private var next: UInt16 = 1

    /// The name's number in this session, assigned and queued for announcement the
    /// first time it is asked for.
    func id(of name: String) -> UInt16 {
        if let id = ids[name] { return id }

        let id = next

        // The counter must not wrap: a number issued twice would rename half a tree.
        precondition(
            id != 0,
            "StateUI: this session has named \(UInt16.max) different things, "
            + "which is every number the wire has for one. What does it is a "
            + "vocabulary that grows without end - a font family, a radio group "
            + "or a visual state built out of a row's own text. Name them from "
            + "a fixed set instead.")

        next &+= 1
        ids[name] = id
        pending.append((id: id, name: name))
        return id
    }

    /// The entries assigned since the last take - what the message being encoded
    /// announces, each once.
    func takePending() -> [(id: UInt16, name: String)] {
        defer { pending.removeAll() }
        return pending
    }
}

/// The wire's writer - and the reader of every channel the host writes.
public enum Wire {
    /// How deep a list value may nest before decoding refuses it, so a corrupt count
    /// is an unreadable buffer rather than a stack overflow.
    static let mostNesting = 256

    /// A list's length in the width the wire writes, or a stop naming the list and the
    /// limit where it does not fit.
    /// Design: docs/design/core/wire.md#limits
    static func count<Written: FixedWidthInteger>(
        _ value: Int,
        of what: String
    ) -> Written {
        guard let written = Written(exactly: value) else {
            preconditionFailure(
                "StateUI: \(value) \(what) in one message, and the wire counts "
                + "them in \(Written.bitWidth) bits - at most \(Written.max).")
        }

        return written
    }

    /// The format's version, answered by `stateui_wire_version` and written first into
    /// every message on every channel but the state batch. It changes only when the
    /// layout does.
    public static let version: UInt8 = 15

    // The render message's field markers, each written only when its field is
    // present; zero ends a node.
    // Design: docs/design/core/wire.md#the-render-message
    enum Field {
        static let end: UInt8 = 0
        static let replace: UInt8 = 1
        static let props: UInt8 = 2
        static let events: UInt8 = 3
        static let children: UInt8 = 4
        static let arranged: UInt8 = 5
        static let transitions: UInt8 = 6
        static let cleared: UInt8 = 7
        static let recycles: UInt8 = 8
        static let shape: UInt8 = 9
        static let motion: UInt8 = 10
        static let driven: UInt8 = 11
    }

    /// Serializes a render message: the envelope, the names the message is
    /// the first to use, then the root's patch.
    static func encode(
        _ patch: HostPatch,
        generation: Int32,
        complete: Bool = false,
        dictionary: WireDictionary
    ) -> [UInt8] {
        // The body first: writing it discovers which names the head announces.
        var body: [UInt8] = []
        write(patch, into: &body, dictionary: dictionary)

        var out: [UInt8] = []
        out.u8(version)
        out.u8(complete ? 1 : 0)
        out.i32(generation)
        announce(dictionary.takePending(), into: &out)
        out.append(contentsOf: body)
        return out
    }

    /// Serializes a batch of acts for the host, announcements first.
    static func encode(_ calls: [ActCall], dictionary: WireDictionary) -> [UInt8] {
        var body: [UInt8] = []
        body.u16(count(calls.count, of: "acts"))

        for call in calls {
            body.u16(dictionary.id(of: call.act.name))
            body.i32(Int32(call.completion ?? 0))
            body.u8(count(call.arguments.count, of: "arguments to one act"))

            for argument in call.arguments {
                write(argument, into: &body, dictionary: dictionary)
            }
        }

        var out: [UInt8] = []
        out.u8(version)
        announce(dictionary.takePending(), into: &out)
        out.append(contentsOf: body)
        return out
    }

    /// The head's announcements: the names this message is the first to use, ahead of
    /// anything that refers to them.
    /// Design: docs/design/core/wire.md#announcements-come-first
    private static func announce(
        _ entries: [(id: UInt16, name: String)],
        into out: inout [UInt8]
    ) {
        out.u16(count(entries.count, of: "names announced"))

        for entry in entries {
            out.u16(entry.id)
            out.string(entry.name)
        }
    }

    /// Writes one element's patch and, recursively, the patches under it: the key and
    /// the type always, every other field only when present.
    private static func write(
        _ patch: HostPatch,
        into out: inout [UInt8],
        dictionary: WireDictionary
    ) {
        write(patch.id, into: &out)
        out.u16(dictionary.id(of: patch.type.name))

        if patch.replace {
            out.u8(Field.replace)
        }

        // Whether the children are rows the host may reuse, and what a row looks like -
        // each only when it changed.
        if let recycles = patch.recycles {
            out.u8(Field.recycles)
            out.u8(recycles ? 1 : 0)
        }

        if let shape = patch.shape {
            out.u8(Field.shape)
            out.u64(shape)
        }

        if !patch.properties.isEmpty {
            out.u8(Field.props)
            out.u16(count(patch.properties.count, of: "properties on one element"))
            // Sorted: the determinism rule.
            // Design: docs/design/core/wire.md#determinism
            for key in patch.properties.keys.sorted() {
                out.u16(dictionary.id(of: key.name))
                write(patch.properties[key]!, into: &out, dictionary: dictionary)
            }
        }

        // The properties no longer described, by key alone, in name order.
        if !patch.clearedProperties.isEmpty {
            out.u8(Field.cleared)
            out.u16(count(
                patch.clearedProperties.count,
                of: "cleared properties on one element"))

            for key in patch.clearedProperties {
                out.u16(dictionary.id(of: key.name))
            }
        }

        // How the children animate where this element places them.
        // Design: docs/design/core/wire.md#layout-motion
        if let placement = patch.motion {
            out.u8(Field.motion)

            // Inherited is -1 here: a layout that stops saying how its children animate has
            // to be heard saying so.
            if placement.motion.isInherited {
                out.i32(-1)
            } else {
                out.i32(placement.motion.law.rawValue)
                out.u32(placement.motion.millis)
                out.i32(placement.motion.curve.rawValue)
                out.f64(placement.motion.factor)
            }

            // Always, whichever law: one part of a place may stay still.
            out.u8(placement.lanes.rawValue)
        }

        // Beside the properties, never inside one: the value is the destination, and this
        // says which the host animates to.
        // Design: docs/design/core/wire.md#transitions
        if !patch.transitions.isEmpty {
            out.u8(Field.transitions)
            out.u16(count(patch.transitions.count, of: "motions on one element"))

            for key in patch.transitions.keys.sorted() {
                let transition = patch.transitions[key]!
                out.u16(dictionary.id(of: key.name))
                out.i32(transition.motion.law.rawValue)
                out.u32(transition.motion.millis)
                out.i32(transition.motion.curve.rawValue)
                out.f64(transition.motion.factor)
            }
        }

        // The driven properties, whenever the set changed, an empty set included; sorted;
        // no law - it lies in the value's own lanes.
        // Design: docs/design/core/wire.md#driven-states
        if case .replace(let driven)? = patch.driven {
            out.u8(Field.driven)
            out.u16(count(driven.count, of: "driven properties on one element"))

            for key in driven.keys.sorted(by: { ($0.name, driven[$0]!.kind.rawValue) < ($1.name, driven[$1]!.kind.rawValue) }) {
                let entry = driven[key]!
                out.u16(dictionary.id(of: key.name))
                out.i32(entry.state)
                out.u8(UInt8(truncatingIfNeeded: entry.mode.rawValue))
                out.u8(UInt8(truncatingIfNeeded: entry.kind.rawValue))
            }
        }

        // Whenever the event set changed, an empty set included.
        // Design: docs/design/core/wire.md#events-and-children
        if case .replace(let events)? = patch.events {
            out.u8(Field.events)
            out.u16(count(events.count, of: "handlers on one element"))
            for key in events.keys.sorted() {
                out.u16(dictionary.id(of: key.name))
                out.i32(events[key]!)
            }
        }

        // The complete arrangement even when empty; the sparse form only when it is not.
        switch patch.children {
        case .unchanged:
            break

        case .changed(let children) where children.isEmpty:
            break

        case .changed(let children), .arranged(let children):
            if case .arranged = patch.children {
                out.u8(Field.arranged)
            } else {
                out.u8(Field.children)
            }
            out.u16(count(children.count, of: "children of one element"))
            for child in children {
                write(child, into: &out, dictionary: dictionary)
            }
        }

        out.u8(Field.end)
    }

    /// A key in the shape that says which kind: a number the differ assigned, or the
    /// author's text.
    private static func write(_ id: ElementId, into out: inout [UInt8]) {
        switch id {
        case .auto(let value):
            out.u8(1)
            out.i32(Int32(value))
        case .manual(let value):
            out.u8(2)
            out.string(value)
        }
    }

    /// One tagged value; the dictionary is for the arm that carries a name.
    private static func write(
        _ value: PropValue,
        into out: inout [UInt8],
        dictionary: WireDictionary
    ) {
        switch value {
        case .name(let name):
            out.u8(11)
            out.u16(dictionary.id(of: name))

        case .values(let values):
            // Recursed here, so a name nested in a list still rides the dictionary.
            out.u8(9)
            out.u16(count(values.count, of: "parts of one value"))
            for value in values {
                write(value, into: &out, dictionary: dictionary)
            }

        case .themed:
            // Picked by the differ as the element was built; one arriving here anyway is
            // written as the theme stands.
            write(value.resolvingTheme(), into: &out, dictionary: dictionary)

        default:
            out.value(value)
        }
    }

    // MARK: - Reading the host's channels

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

    /// Announces the store the application keeps state in and its keys, names in full.
    /// Design: docs/design/core/wire.md#persistent-keys
    static func encodePersistent(storage: PersistentStorage, keys: [PersistentKey]) -> [UInt8] {
        var out: [UInt8] = []
        out.u8(version)
        out.string(storage.name)
        out.u16(count(keys.count, of: "persistent keys"))

        for key in keys {
            out.string(key.name)

            // One byte for a vocabulary of four.
            out.u8(UInt8(truncatingIfNeeded: key.kind.rawValue))
        }

        return out
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

    /// What a host realizes, said once at start-up by a runtime across the Wire;
    /// sorted, names in full.
    /// Design: docs/design/core/wire.md#realizations-and-declarations
    static func encodeRealization(_ realization: HostRealization) -> [UInt8] {
        var out: [UInt8] = []
        out.u8(version)
        out.u16(count(realization.elements.count, of: "realized elements"))

        for element in realization.elements.sorted() {
            out.string(element)
        }

        let members = realization.members.sorted {
            ($0.element, $0.owner, $0.member) < ($1.element, $1.owner, $1.member)
        }
        out.u16(count(members.count, of: "realized members"))

        for member in members {
            out.string(member.element)
            out.string(member.owner)
            out.string(member.member)
        }

        return out
    }

    /// What a host declares, read off its own runtime: presence, never ownership.
    /// Design: docs/design/core/wire.md#realizations-and-declarations
    static func encodeDeclaration(_ declaration: HostDeclaration) -> [UInt8] {
        var out: [UInt8] = []
        out.u8(version)
        out.u16(count(declaration.elements.count, of: "declared elements"))

        for element in declaration.elements.keys.sorted() {
            let declared = declaration.elements[element] ?? HostDeclaration.Element()
            out.string(element)
            write(declared, into: &out, of: "element")
        }

        write(declaration.shared, into: &out, of: "shared")

        out.u16(count(declaration.acts.count, of: "performed acts"))

        for act in declaration.acts.sorted() {
            out.string(act)
        }

        return out
    }

    /// One element's members and then its events, each counted and sorted.
    private static func write(
        _ declared: HostDeclaration.Element, into out: inout [UInt8], of what: String
    ) {
        out.u16(count(declared.members.count, of: "members on one \(what)"))

        for member in declared.members.sorted() {
            out.string(member)
        }

        out.u16(count(declared.events.count, of: "events on one \(what)"))

        for event in declared.events.sorted() {
            out.string(event)
        }
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

/// What the host answered an act with: values to resume with, or a reason to
/// throw.
enum Reply: Equatable, Sendable {
    /// The act ran; these are the values it returned - empty for a method
    /// that returns nothing.
    case finished([PropValue])

    /// The act could not be performed, and this is why.
    case failed(String)
}

/// The append helpers every record is written with - little-endian, fixed width.
extension [UInt8] {
    mutating func u8(_ value: UInt8) {
        append(value)
    }

    mutating func u16(_ value: UInt16) {
        append(UInt8(truncatingIfNeeded: value))
        append(UInt8(truncatingIfNeeded: value >> 8))
    }

    mutating func u32(_ value: UInt32) {
        append(UInt8(truncatingIfNeeded: value))
        append(UInt8(truncatingIfNeeded: value >> 8))
        append(UInt8(truncatingIfNeeded: value >> 16))
        append(UInt8(truncatingIfNeeded: value >> 24))
    }

    /// Eight bytes, little-endian - what a shape crosses as.
    mutating func u64(_ value: UInt64) {
        for shift in stride(from: 0, to: 64, by: 8) {
            append(UInt8(truncatingIfNeeded: value >> UInt64(shift)))
        }
    }

    mutating func i32(_ value: Int32) {
        u32(UInt32(bitPattern: value))
    }

    mutating func f64(_ value: Double) {
        var bits = value.bitPattern
        for _ in 0..<8 {
            append(UInt8(truncatingIfNeeded: bits))
            bits >>= 8
        }
    }

    /// A length-prefixed UTF-8 string - nothing escaped, nothing scanned.
    mutating func string(_ value: String) {
        let bytes = Array(value.utf8)
        u32(UInt32(bytes.count))
        append(contentsOf: bytes)
    }

    /// One tagged value. A name is not written here: its number belongs to a session's
    /// dictionary, so it goes through `Wire.write(_:into:dictionary:)`.
    mutating func value(_ value: PropValue) {
        switch value {
        case .bool(false):
            u8(1)
        case .bool(true):
            u8(2)
        case .number(let number):
            u8(3)
            f64(number)
        case .string(let text):
            u8(4)
            string(text)
        case .numbers(let numbers):
            u8(5)
            u16(Wire.count(numbers.count, of: "numbers in one value"))
            for number in numbers {
                f64(number)
            }
        case .strings(let strings):
            u8(6)
            u16(Wire.count(strings.count, of: "strings in one value"))
            for text in strings {
                string(text)
            }
        case .color(let red, let green, let blue, let alpha):
            u8(8)
            u8(red)
            u8(green)
            u8(blue)
            u8(alpha)
        case .values(let values):
            u8(9)
            u16(Wire.count(values.count, of: "parts of one value"))
            for value in values {
                self.value(value)
            }
        case .enumeration(let member):
            u8(10)
            i32(member)
        case .nothing:
            u8(12)
        case .themed:
            self.value(value.resolvingTheme())
        case .name(let name):
            preconditionFailure(
                "a name ('\(name)') rides the session dictionary - write it "
                    + "through Wire.encode, not the bare value helper")
        }
    }
}
