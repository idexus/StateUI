// The binary wire format.
//
// One process, one address space, and every platform this library targets is
// little-endian arm64 or x86_64 - so numbers cross as their own bytes, fixed
// width, no text in between: an Int32 here is an Int32 there. A message is a
// byte buffer the host reads IN PLACE, with no UTF-16 round trip and nothing
// materialized on the way.
//
// SEVEN channels share the one value encoding below. This side WRITES the tree
// and the acts; it READS the five the host writes - the two laid out here, and
// the three at `decodeHostEvent`, `decodeEnvironment` and `decodePersistent`.
// An eighth carries no values at all: `encodePersistent` announces the
// application's persistent keys, which are names and a kind byte.
//
//   reply    [version: U8][ok: U8][count: U8][values...]
//            what an act came to - the values a `try await` resumes with, or
//            ok 0 and one string, the reason it throws.
//   payload  [version: U8][count: U8][values...]
//            what an event carried - one value per property of the MAUI
//            EventArgs it stands for, in the order MAUI declares them. An
//            event with nothing to say crosses no bytes at all.
//
// THE DICTIONARY: a name - a node type, a property key, an event, an act -
// does not travel as its spelling. Each SESSION numbers the names it actually
// uses: the first message that uses one assigns it the next UInt16 and
// ANNOUNCES the pair in its head, and both sides speak the number from then
// on. See `WireDictionary`. What that buys, in order of importance:
//
//   - An application's names are numbered exactly as the library's are. There
//     is no reserved pool, no table to be missing from, and no ledger to keep
//     append-only - the name IS the registration, said once per session.
//   - The reader can never hold a table from another version: it learns every
//     entry from the message itself. A name the RENDERER does not recognize
//     degrades gently - an unknown property is ignored, an unknown node type
//     draws the marker.
//   - A message costs a name's spelling once per session and two bytes ever
//     after.
//
// Announcements sit at the HEAD of a message, before anything that could
// refer to them - so a batch that fails later in its bytes has still taught
// the reader its names, and the session's numbering can never drift on a
// failure. The host checks `stateui_wire_version` before the first render,
// so two halves built from different versions fail loudly at startup instead
// of reading each other's bytes wrong.
//
// The layout of an acts batch:
//
//   [version: U8][announcements][count: U16]
//   per act:
//     [method: U16, from the dictionary]
//     [completion: I32]  (0 when nobody is waiting - real ids are negative)
//     [argCount: U8]
//     [arguments...]
//
// where announcements are [count: U16] then per entry [id: U16][name: string].
// The render message's envelope is [version][complete][generation], then the
// announcements, then the root's patch. A value is one tag byte, then its
// payload:
//
//   1 false | 2 true | 3 number: F64 | 4 string: [length: U32][UTF-8]
//   5 numbers: [count: U16][F64...] | 6 strings: [count: U16][string...]
//   7 unused
//   8 color: [r: U8][g: U8][b: U8][a: U8]
//   9 values: [count: U16][values...]
//   10 enumeration: [member: I32]
//   11 name: [id: U16, from the dictionary]
//   12 nothing: (no payload)
//
// TAG 4 IS TEXT SOMEONE WROTE, and it is the only arm that carries a
// spelling. A closed vocabulary is tag 10 and rides its member's NUMBER - see
// the head of Types/Enums.swift for whose numbers those are; an open
// vocabulary an author NAMES is tag 11 and rides the session's dictionary,
// announced once like a property key; and a value made of parts is tag 9 and
// rides as its parts. An argument or a list element that is not there is tag
// 12 - one spelling for absence, so no corner of the wire has to read an empty
// string, a -1 or an empty list as one.
//
// TAG 7 IS UNUSED, and nothing is renumbered to close the gap: a number costs
// nothing left alone, while moving one has to land on both halves in the same
// breath. Tag 11 is the one way a name crosses.
//
// A COLOUR has a tag of its own because it is the value this tree carries
// most of and the cheapest to say exactly: four bytes against the twelve a
// "#RRGGBB" string cost, with no parser and no vocabulary on the far side.
// Channel order is written out rather than packed into a word, so there is no
// endianness to agree about.
//
// A string carries its LENGTH, so nothing is ever escaped and a comma inside
// one needs no rule. A number crosses as its own bits, so nothing is formatted
// invariantly and a non-finite needs no sentinel beside it - the reader
// answers "not a number" for one and the caller is left alone.
//
// A TRANSITION is not a value and does not ride in one. A property being
// FLOWN carries its target as the ordinary value it is; a separate field
// beside the props says which of them the host is to walk to rather than
// assign:
//
//   6 transitions: [count: U16] then per entry
//     [property: U16, from the dictionary]
//     [length: U32, milliseconds][easing: I32, the member's number]
//     [channel: I32, the completion the handler waits on]
//     [report: U32, milliseconds between progress reports, 0 for none]
//
// Beside the props rather than inside them, and this is why: a wrapped VALUE
// answers nil from every typed accessor on the far side, so a host that did
// not know the wrapper would silently not write the property -
// indistinguishable from "this did not change" - and a wrapper leaking into
// the visual-state overlay, which copies prop bags whole, would re-fire a
// flight nobody asked for. A field is skipped by nobody: an unknown one throws
// on arrival, which is the loud failure this deserves.

/// One session's numbering of every name the wire carries - node types,
/// property keys, event names, act methods, one id space for all of them.
///
/// A name is assigned the next number the first time a message uses it, and
/// that message announces the pair in its head - so the reader learns the
/// dictionary exactly as fast as it needs it, and an application's own names
/// ride numbers the same way the library's do. Nothing is reserved and
/// nothing can collide: the numbering is this session's own and dies with it.
///
/// Touched only while a message is being encoded, which happens on the host's
/// one thread - renders and takes alike - so it needs no lock of its own. The
/// tests hand each fixture a fresh one, which is what makes a fixture's bytes
/// deterministic and self-describing.
final class WireDictionary {
    private var ids: [String: UInt16] = [:]
    private var pending: [(id: UInt16, name: String)] = []
    private var next: UInt16 = 1

    /// The name's number in this session - assigned, and queued for
    /// announcement, the first time it is asked for.
    func id(of name: String) -> UInt16 {
        if let id = ids[name] { return id }

        let id = next

        // The counter has come back round to where it started. It must not
        // wrap: the number is the reader's ONLY handle on a name, so issuing
        // one twice would quietly rename half a tree, and there is nothing on
        // the wire that could notice.
        precondition(
            id != 0,
            "StateUI: this session has named \(UInt16.max) different things, "
            + "which is every number the wire has for one. What does it is a "
            + "vocabulary that grows without end - a style key, a font family "
            + "or a visual state built out of a row's own text. Name them from "
            + "a fixed set instead.")

        next &+= 1
        ids[name] = id
        pending.append((id: id, name: name))
        return id
    }

    /// The entries assigned since the last take - what the message being
    /// encoded writes into its head, each exactly once.
    func takePending() -> [(id: UInt16, name: String)] {
        defer { pending.removeAll() }
        return pending
    }
}

/// The wire's writer - and the reader of every channel the host writes.
public enum Wire {
    /// A list's length as the wire writes it, which is a fixed number of bits.
    ///
    /// Everything in a message is length-prefixed, so a list longer than its
    /// prefix can count cannot be written at all. The plain conversion ends the
    /// process on an arithmetic trap that names neither the list nor the limit;
    /// this names both, which is the difference between a crash report someone
    /// can act on and one nobody can place.
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

    /// The format's version, answered by `stateui_wire_version` and written
    /// first into every message on every channel. Bumped only when the LAYOUT
    /// changes.
    /// 2: replies and event payloads carry typed values.
    /// 3: names are numbered per session and announced by the message that
    ///    first uses them.
    /// 4: the arrangement IS the children list - a node whose child order
    ///    changed carries the COMPLETE list in order, unchanged children as
    ///    stubs.
    /// 5: a colour is four bytes, a brush is a list of typed values, and the
    ///    theme is resolved before anything is written - so no value on this
    ///    wire means two colours.
    /// 6: an element may say that some of its properties are to be WALKED to
    ///    rather than assigned - a transitions field beside the props.
    /// 7: a walk may be REPORTED as it goes - every entry of that field says
    ///    how many milliseconds apart, and 0 means nobody is watching. The
    ///    cadence is the author's, stated at the call, because the walk's own
    ///    frames are the host's and no interface needs sixty a second.
    /// 8: A STRING IS TEXT SOMEONE WROTE, and nothing else is a string. Every
    ///    closed vocabulary rides its member's NUMBER, every open-vocabulary
    ///    NAME rides the session's dictionary like a property key, and every
    ///    value with parts rides as its parts: a stroke shape, a row
    ///    definition list, a point list, a date, a time, the easing of a walk,
    ///    and the whole of a GraphicsView's drawing.
    /// 9: a property an element STOPS describing is named in a field of its
    ///    own and the host CLEARS it, so what the modifier stood for goes back
    ///    to MAUI's own default. Before this a lost property was the whole
    ///    element again, which cost every descendant its identity, its
    ///    handlers and its state.
    public static let version: UInt8 = 9

    // The tree message's field markers, one byte each, written only when the
    // field is present: a field that is not there did not change. Zero ends a
    // node, so optionality costs one byte per present field and nothing per
    // absent one.
    enum Field {
        static let end: UInt8 = 0
        static let replace: UInt8 = 1
        static let props: UInt8 = 2
        static let events: UInt8 = 3
        static let children: UInt8 = 4
        static let arranged: UInt8 = 5
        static let transitions: UInt8 = 6
        static let cleared: UInt8 = 7
    }

    /// Serializes a render message: the envelope, the names the message is
    /// the first to use, then the root's patch.
    static func encode(
        _ patch: Patch,
        generation: Int32,
        complete: Bool = false,
        dictionary: WireDictionary
    ) -> [UInt8] {
        // The body is written first, because writing it is what discovers
        // which names still need announcing - the head then carries exactly
        // those.
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
    static func encode(_ commands: [Command], dictionary: WireDictionary) -> [UInt8] {
        var body: [UInt8] = []
        body.u16(count(commands.count, of: "acts"))

        for command in commands {
            body.u16(dictionary.id(of: command.act.name))
            body.i32(Int32(command.completion ?? 0))
            body.u8(count(command.arguments.count, of: "arguments to one act"))

            for argument in command.arguments {
                write(argument, into: &body, dictionary: dictionary)
            }
        }

        var out: [UInt8] = []
        out.u8(version)
        announce(dictionary.takePending(), into: &out)
        out.append(contentsOf: body)
        return out
    }

    /// The head's dictionary section: the names this message is the first in
    /// its session to use. At the head, BEFORE anything that could refer to
    /// them, so a batch that fails later in its bytes has still taught the
    /// reader its names.
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

    /// Writes one element's patch, and recursively the elements under it.
    ///
    /// The identity and the type come first, always - the id is how C# finds
    /// the control and the type is worth its two bytes on every message - and
    /// every other field is written only when it is there.
    private static func write(
        _ patch: Patch,
        into out: inout [UInt8],
        dictionary: WireDictionary
    ) {
        write(patch.id, into: &out)
        out.u16(dictionary.id(of: patch.type.name))

        if patch.replace {
            out.u8(Field.replace)
        }

        if !patch.props.isEmpty {
            out.u8(Field.props)
            out.u16(count(patch.props.count, of: "properties on one element"))
            // Sorted so the output is deterministic - it makes diffs between
            // two renders meaningful and test output stable.
            for key in patch.props.keys.sorted() {
                out.u16(dictionary.id(of: key.name))
                write(patch.props[key]!, into: &out, dictionary: dictionary)
            }
        }

        // What this element described last time and does not describe now.
        // Only the keys: there is no value to send for a property that is
        // gone, and what it goes back to is MAUI's business rather than this
        // side's. Already in name order, as everything written here is.
        if !patch.cleared.isEmpty {
            out.u8(Field.cleared)
            out.u16(count(patch.cleared.count, of: "cleared properties on one element"))

            for key in patch.cleared {
                out.u16(dictionary.id(of: key.name))
            }
        }

        // Beside the properties, never inside one: the value above is the
        // target, written exactly as it would be if nothing were flying, and
        // this says which of them the host walks to instead of assigning.
        // Sorted for the same reason the props are.
        if !patch.transitions.isEmpty {
            out.u8(Field.transitions)
            out.u16(count(patch.transitions.count, of: "flights on one element"))

            for key in patch.transitions.keys.sorted() {
                let transition = patch.transitions[key]!
                out.u16(dictionary.id(of: key.name))
                out.u32(transition.length)
                out.i32(transition.easing.rawValue)
                out.i32(transition.channel)
                out.u32(transition.report)
            }
        }

        // Written whenever the patch decided the event set changed, EMPTY set
        // included: an element whose last handler went carries `[:]` here, and
        // the host replaces its map with an empty one. Skipping an empty set
        // would leave that element reading as "events unchanged", so the host
        // would keep the id Swift has forgotten and resolve a gesture to
        // nobody - a false "handler on a released element" in the log the one
        // reader debugging it reads. The count-0 case the reader already
        // handles, so the host needs nothing.
        if let events = patch.events {
            out.u8(Field.events)
            out.u16(count(events.count, of: "handlers on one element"))
            for key in events.keys.sorted() {
                out.u16(dictionary.id(of: key.name))
                out.i32(Int32(events[key]!))
            }
        }

        // The two shapes of the child list: the COMPLETE arrangement, written
        // even when it is empty - an element whose last child left has to say
        // so - and the sparse form, worth bytes only when something is in it.
        if patch.arranged || !patch.children.isEmpty {
            out.u8(patch.arranged ? Field.arranged : Field.children)
            out.u16(count(patch.children.count, of: "children of one element"))
            for child in patch.children {
                write(child, into: &out, dictionary: dictionary)
            }
        }

        out.u8(Field.end)
    }

    /// An identity, in the shape that says which kind it is: a number when
    /// the renderer assigned it, a string when the author did - the two
    /// namespaces the tree's ids travel in.
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

    /// One tagged value. The dictionary is for the arm that carries a NAME -
    /// `.name`, an open vocabulary an author names: a style key, a visual
    /// state, a font family, a radio group. It rides the session's number the
    /// way a property key does, so a name is spelled one way wherever it is
    /// given.
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
            // Recursed HERE rather than in the bare helper, so a token
            // nested in a list still rides the session's number - which the
            // drawing and every other value made of parts depend on.
            out.u8(9)
            out.u16(count(values.count, of: "parts of one value"))
            for value in values {
                write(value, into: &out, dictionary: dictionary)
            }

        default:
            out.value(value)
        }
    }

    // MARK: - Reading the host's channels

    /// Decodes an event's payload: the typed values a control reported, one
    /// per property of the MAUI EventArgs. An empty buffer IS the payload of
    /// an event with nothing to say - the host crosses no bytes for one - and
    /// nil is a buffer that would not read, which every typed reader treats
    /// as the gesture parse rule treats garbage: nothing moves.
    static func decodePayload(_ bytes: [UInt8]) -> [PropValue]? {
        guard !bytes.isEmpty else { return [] }

        var reader = Reader(bytes)

        guard reader.u8() == version, let values = values(&reader), reader.atEnd else {
            return nil
        }

        return values
    }

    /// Decodes an act's outcome. Nil for a buffer that would not read - the
    /// caller turns that into a failure rather than a hang, because a reply
    /// that cannot be read must still resume the handler waiting on it.
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

    /// Decodes an event the HOST raised by name - no element behind it, so
    /// the name travels in the buffer: the application registered it on the
    /// C# side and a `HostEvents.on` subscription is what hears it. Nil for
    /// a buffer that would not read, which the caller answers with -1 so the
    /// host can say version skew rather than nothing.
    static func decodeHostEvent(_ bytes: [UInt8]) -> (name: String, payload: [PropValue])? {
        var reader = Reader(bytes)

        guard reader.u8() == version, let name = reader.string(),
              let values = values(&reader), reader.atEnd else {
            return nil
        }

        return (name, values)
    }

    /// Announces which store the application keeps its state in and every key
    /// it keeps there, so the host can read exactly those before the first
    /// render:
    ///
    ///   [version: U8][storage: string][count: U16]
    ///   per key: [name: string][kind: U8]
    ///
    /// Names in full rather than dictionary numbers: this is the FIRST thing
    /// either side says, before any message has announced anything, and the
    /// names belong to the platform's store rather than to a session.
    static func encodePersistent(storage: PersistentStorage, keys: [PersistentKey]) -> [UInt8] {
        var out: [UInt8] = []
        out.u8(version)
        out.string(storage.name)
        out.u16(count(keys.count, of: "persistent keys"))

        for key in keys {
            out.string(key.name)

            // One byte for a vocabulary of four, where the tree's values would
            // spend five. Nothing here is repeated often enough to be worth a
            // dictionary entry.
            out.u8(UInt8(truncatingIfNeeded: key.kind.rawValue))
        }

        return out
    }

    /// Decodes what the host read out of the store - a name and a value per
    /// key it FOUND. A key the store had nothing under is simply absent, which
    /// is what leaves the state holding the value written beside it.
    ///
    ///   [version: U8][count: U16]
    ///   per entry: [name: string][value]
    ///
    /// Nil for a buffer that would not read, which the caller answers with -1
    /// so the host can say version skew rather than nothing.
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

    /// Decodes a standard-environment push - which provider, then the same
    /// counted value list every channel shares. The domain is one byte, not a
    /// name: the providers are a closed vocabulary both sides of this
    /// repository spell, see `EnvironmentDomain`. Nil for a buffer that would
    /// not read, which the caller answers with -1 so the host can say version
    /// skew rather than nothing.
    static func decodeEnvironment(_ bytes: [UInt8]) -> (domain: UInt8, payload: [PropValue])? {
        var reader = Reader(bytes)

        guard reader.u8() == version, let domain = reader.u8(),
              let values = values(&reader), reader.atEnd else {
            return nil
        }

        return (domain, values)
    }

    /// A counted value list - the shape both channels share.
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

    /// One tagged value, the mirror of `[UInt8].value(_:)` below.
    ///
    /// No arm for a name, and that is the only omission: its number belongs to
    /// the session's dictionary, which THIS side writes, so the host has
    /// nothing to number one against and never sends one. Everything else the
    /// writer can emit is read here, which is what lets a colour come back off
    /// a reply as the four bytes it is.
    private static func value(_ reader: inout Reader) -> PropValue? {
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
            guard let count = reader.u16() else { return nil }
            var values: [PropValue] = []
            values.reserveCapacity(Int(count))
            for _ in 0..<count {
                guard let value = value(&reader) else { return nil }
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

    /// A bounds-checked cursor over one message - every read answers nil past
    /// the end instead of trapping, so a truncated buffer is a refusal, never
    /// a crash.
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

            // Compared as it crossed - UNSIGNED and 32 bits wide - against
            // what is left. `Int` is 32 bits on a 32-bit target, armeabi-v7a
            // among them, where a length past Int32.max would trap on the way
            // in rather than be refused here.
            let stated = UInt64(UInt32(low) | UInt32(high) << 16)
            guard stated <= UInt64(bytes.count - offset) else { return nil }

            let count = Int(stated)
            defer { offset += count }
            return String(decoding: bytes[offset..<offset + count], as: UTF8.self)
        }
    }
}

/// What the host answered an act with: the values a `try await` resumes with,
/// or the reason it throws. Decoded from the reply channel by
/// `Wire.decodeReply`; `Renderer.answered` is where the two arms part.
enum Reply: Equatable, Sendable {
    /// The act ran; these are the values it returned - empty for a method
    /// that returns nothing.
    case finished([PropValue])

    /// The act could not be performed, and this is why.
    case failed(String)
}

/// The append helpers every record above is written with - little-endian,
/// fixed width, in one place so the layout has one spelling.
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

    /// One tagged value - see the layout in Wire's header. A NAME is not
    /// written here: its number belongs to a session's dictionary, so it goes
    /// through `Wire.write(_:into:dictionary:)`, and this helper serves the
    /// channels that never carry one.
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
        case .name(let name):
            preconditionFailure(
                "a name ('\(name)') rides the session dictionary - write it "
                    + "through Wire.encode, not the bare value helper")
        }
    }
}
