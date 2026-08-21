// The test-side reader of the binary acts channel - Core/Wire.swift decoded
// back into values a test can assert on.
//
// A third spelling of the format, deliberately confined to the TESTS: the
// library only writes, the host only reads, and this probe is how a Swift test
// looks at what was written. It reads the library's PUBLIC surface only
// (PropValue), so both test targets can import it plainly.
//
// Malformed bytes STOP a test run rather than answering something partial: a
// probe that shrugs at a framing bug would hide exactly what it exists to
// catch.
//
// IT ALSO RENDERS WHAT A NUMBER MEANS. A closed vocabulary rides its member
// NUMBER, so the bytes say 4 where a reviewer needs `tailTruncation` - and
// `lineBreakMode: enum 4` tells them nothing at all. The probe therefore keeps
// ONE table, from a property KEY to the vocabulary that property carries, and
// prints both halves: `lineBreakMode: enum tailTruncation(4)`. The KEY is the
// only thing that can say which vocabulary a number belongs to, so a number
// with no key over it - an act's positional argument, an event's payload, a
// value nested inside a list - is printed bare and is meant to be.
//
// The spellings are not written here: they come out of the library's own enum
// through `String(describing:)`, and the keys are `Prop`'s own members. So the
// probe can fall behind the library in COVERAGE - a vocabulary nobody added to
// the table - but never in SPELLING, and coverage is what
// `testEveryEnumerationInASidecarIsSpelled` fails on.

import StateUI

/// The names a decode resolves ids through - one session's worth, learned
/// from the announcements at the head of every buffer shown to it.
///
/// The live app has ONE session per process, so the probe keeps `.session`
/// as its mirror of it: every buffer a test takes from `Renderer.shared`
/// must be decoded - or at least shown to the probe - so the mirror hears
/// every announcement, dropped batches included. A FIXTURE is encoded with
/// a fresh `WireDictionary`, so its test decodes it with a fresh `WireNames`
/// - self-contained, deterministic, and never mixed into the session's ids.
public final class WireNames {
    var names: [Int: String] = [:]

    /// A fresh, empty dictionary - what a self-contained fixture decodes with.
    public init() {}

    /// The probe's mirror of the one live session - `Renderer.shared`'s
    /// numbering, learned from every buffer the tests take from it.
    /// `nonisolated(unsafe)` the way the renderer's own state is: the tests
    /// run serially on the one thread the host would call in from.
    public nonisolated(unsafe) static let session = WireNames()

    func resolve(_ id: Int) -> String {
        guard let name = names[id] else {
            preconditionFailure(
                "name #\(id) was never announced to this WireNames - "
                    + "was a batch taken from Renderer.shared without decoding it?")
        }
        return name
    }
}

/// One decoded act: what `Command` says, read back off the wire.
public struct WireAct {
    /// The MAUI method name, resolved from the session's dictionary - an act
    /// the library wraps and one an application named for itself alike.
    public let name: String

    /// Its arguments, in the order MAUI takes them.
    public let arguments: [PropValue]

    /// The completion id, when someone is waiting. Negative, always.
    public let completion: Int?

    /// A decoded act, or a normalized copy of one.
    public init(name: String, arguments: [PropValue], completion: Int?) {
        self.name = name
        self.arguments = arguments
        self.completion = completion
    }
}

/// The reader itself, plus the dump a fixture's sidecar carries.
public enum WireProbe {
    /// Decodes a taken batch, learning its announcements into `names`.
    /// Empty bytes are an empty batch.
    public static func decode(_ bytes: [UInt8], names: WireNames = .session) -> [WireAct] {
        guard !bytes.isEmpty else { return [] }

        var at = 0

        func u8() -> UInt8 {
            precondition(at + 1 <= bytes.count, "the batch ends mid-value")
            defer { at += 1 }
            return bytes[at]
        }

        func u16() -> Int {
            precondition(at + 2 <= bytes.count, "the batch ends mid-value")
            defer { at += 2 }
            return Int(bytes[at]) | Int(bytes[at + 1]) << 8
        }

        func u32() -> Int {
            precondition(at + 4 <= bytes.count, "the batch ends mid-value")
            defer { at += 4 }
            return Int(bytes[at]) | Int(bytes[at + 1]) << 8
                | Int(bytes[at + 2]) << 16 | Int(bytes[at + 3]) << 24
        }

        func i32() -> Int {
            Int(Int32(bitPattern: UInt32(u32())))
        }

        func f64() -> Double {
            precondition(at + 8 <= bytes.count, "the batch ends mid-value")
            var bits: UInt64 = 0
            for shift in 0..<8 {
                bits |= UInt64(bytes[at + shift]) << (8 * shift)
            }
            at += 8
            return Double(bitPattern: bits)
        }

        func string() -> String {
            let length = u32()
            precondition(at + length <= bytes.count, "the batch ends mid-string")
            defer { at += length }
            return String(decoding: bytes[at..<(at + length)], as: UTF8.self)
        }

        func value() -> PropValue {
            switch u8() {
            case 1: return .bool(false)
            case 2: return .bool(true)
            case 3: return .number(f64())
            case 4: return .string(string())
            case 5: return .numbers((0..<u16()).map { _ in f64() })
            case 6: return .strings((0..<u16()).map { _ in string() })
            case 8:
                let red = u8()
                let green = u8()
                let blue = u8()
                return .color(red: red, green: green, blue: blue, alpha: u8())
            case 9: return .values((0..<u16()).map { _ in value() })
            case 10: return .enumeration(Int32(truncatingIfNeeded: i32()))
            // A name rides the session's dictionary the way a property KEY
            // does - two bytes, resolved the same way - which is the whole of
            // what tells it apart from a string.
            case 11: return .name(names.resolve(u16()))
            case 12: return .nothing
            case let tag: preconditionFailure("unknown value tag \(tag)")
            }
        }

        // Read from the library rather than written out: the probe is a third
        // spelling of the LAYOUT, not of the number in front of it, and a
        // version bump that leaves the layout alone should not need an edit
        // here. A buffer that is not a message still fails on its first byte.
        let version = u8()
        precondition(
            version == Wire.version,
            "wire version \(version), this probe reads \(Wire.version)")

        for _ in 0..<u16() {
            let id = u16()
            names.names[id] = string()
        }

        var acts: [WireAct] = []
        for _ in 0..<u16() {
            let name = names.resolve(u16())

            let completion = i32()
            let arguments = (0..<Int(u8())).map { _ in value() }

            acts.append(WireAct(
                name: name,
                arguments: arguments,
                completion: completion == 0 ? nil : completion))
        }

        precondition(at == bytes.count, "the batch carries bytes past its last command")
        return acts
    }

    /// The names in a batch, for a test that asks only which acts were queued.
    public static func names(_ bytes: [UInt8], names dictionary: WireNames = .session) -> [String] {
        decode(bytes, names: dictionary).map(\.name)
    }

    /// The completion ids in a batch, in queue order.
    public static func completions(_ bytes: [UInt8], names dictionary: WireNames = .session) -> [Int] {
        decode(bytes, names: dictionary).compactMap(\.completion)
    }

    /// One decoded tree element - what a render message's node says.
    public struct WireNode {
        public var identity: WireIdentity
        public var type: String
        public var replace = false
        public var props: [(key: String, value: PropValue)] = []
        public var events: [(name: String, id: Int)] = []

        /// The properties among `props` the host walks to rather than
        /// assigns, each with how long, on what curve, and the completion the
        /// handler that started the flight waits on.
        ///
        /// The curve is `Easing`'s member NUMBER - a closed vocabulary like
        /// every other on this wire.
        public var transitions:
            [(property: String, length: Int, easing: Int32, channel: Int, report: Int)] = []

        /// Whether `children` is the COMPLETE list, in order - the arranged
        /// form, sent when something was added, removed or moved.
        public var arranged = false
        public var children: [WireNode] = []

        /// The properties this element described last render and no longer
        /// does, which the host clears.
        public var cleared: [String] = []
    }

    /// An element's identity, in whichever namespace it crossed in.
    public enum WireIdentity: Equatable {
        case number(Int)
        case name(String)
    }

    /// Decodes a render message - the envelope, its announcements, then the
    /// tree - learning the announced names into `names`.
    public static func decodeMessage(
        _ bytes: [UInt8],
        names: WireNames = .session
    ) -> (generation: Int, complete: Bool, root: WireNode) {
        var at = 0

        func u8() -> UInt8 {
            precondition(at + 1 <= bytes.count, "the message ends mid-value")
            defer { at += 1 }
            return bytes[at]
        }

        func u16() -> Int {
            Int(u8()) | Int(u8()) << 8
        }

        func u32() -> Int {
            u16() | u16() << 16
        }

        func i32() -> Int {
            Int(Int32(bitPattern: UInt32(u32())))
        }

        func f64() -> Double {
            var bits: UInt64 = 0
            for shift in 0..<8 {
                bits |= UInt64(u8()) << (8 * shift)
            }
            return Double(bitPattern: bits)
        }

        func string() -> String {
            let length = u32()
            precondition(at + length <= bytes.count, "the message ends mid-string")
            defer { at += length }
            return String(decoding: bytes[at..<(at + length)], as: UTF8.self)
        }

        func name() -> String {
            names.resolve(u16())
        }

        func value() -> PropValue {
            switch u8() {
            case 1: return .bool(false)
            case 2: return .bool(true)
            case 3: return .number(f64())
            case 4: return .string(string())
            case 5: return .numbers((0..<u16()).map { _ in f64() })
            case 6: return .strings((0..<u16()).map { _ in string() })
            case 8:
                let red = u8()
                let green = u8()
                let blue = u8()
                return .color(red: red, green: green, blue: blue, alpha: u8())
            case 9: return .values((0..<u16()).map { _ in value() })
            case 10: return .enumeration(Int32(truncatingIfNeeded: i32()))
            case 11: return .name(name())
            case 12: return .nothing
            case let tag: preconditionFailure("unknown value tag \(tag)")
            }
        }

        func identity() -> WireIdentity {
            switch u8() {
            case 1: return .number(i32())
            case 2: return .name(string())
            case let tag: preconditionFailure("unknown identity tag \(tag)")
            }
        }

        func node() -> WireNode {
            var read = WireNode(identity: identity(), type: name())

            while true {
                switch u8() {
                case 0: return read
                case 1: read.replace = true
                case 2:
                    for _ in 0..<u16() {
                        read.props.append((name(), value()))
                    }
                case 3:
                    for _ in 0..<u16() {
                        read.events.append((name(), i32()))
                    }
                case 6:
                    // The easing is the MEMBER'S NUMBER, not a name out of the
                    // dictionary - `Easing` is a closed vocabulary like any
                    // other.
                    for _ in 0..<u16() {
                        read.transitions.append(
                            (name(), u32(), Int32(truncatingIfNeeded: i32()), i32(), u32()))
                    }
                case 7:
                    for _ in 0..<u16() {
                        read.cleared.append(name())
                    }
                case let field where field == 4 || field == 5:
                    read.arranged = field == 5
                    read.children = (0..<u16()).map { _ in node() }
                case let field: preconditionFailure("unknown node field \(field)")
                }
            }
        }

        let version = u8()
        precondition(
            version == Wire.version,
            "wire version \(version), this probe reads \(Wire.version)")

        let complete = u8() != 0
        let generation = i32()

        for _ in 0..<u16() {
            let id = u16()
            names.names[id] = string()
        }

        let root = node()

        precondition(at == bytes.count, "the message carries bytes past its root")
        return (generation, complete, root)
    }

    /// The readable rendering of a render message, for a fixture's sidecar:
    /// one element per line, its fields indented under it, children deeper.
    /// The names are resolved inline, so the announcement section shows only
    /// as its count - the numbering is the bytes' business.
    public static func dumpMessage(_ bytes: [UInt8], names: WireNames = .session) -> String {
        let counted = WireNames()
        counted.names = names.names
        let before = counted.names.count
        let (generation, complete, root) = decodeMessage(bytes, names: counted)
        names.names = counted.names

        var out = "generation \(generation)\(complete ? " complete" : "")"
        let announced = counted.names.count - before
        if announced > 0 { out += " names +\(announced)" }
        out += "\n"
        dump(root, depth: 0, into: &out)
        return out
    }

    private static func dump(_ node: WireNode, depth: Int, into out: inout String) {
        let indent = String(repeating: "  ", count: depth)

        var head = indent + node.type + " " + spelled(node.identity)
        if node.replace { head += " replace" }
        if node.arranged { head += " arranged(\(node.children.count))" }
        out += head + "\n"

        // The one place in the whole dump where a value has a KEY over it, and
        // therefore the one place a member number can be spelled out.
        for (key, value) in node.props {
            out += indent + "  \(key): \(line(for: value, under: key))\n"
        }

        // Under the property it is about, and saying the target is the line
        // above: what flies is the walk to a value, never the value itself.
        for flight in node.transitions {
            let easing = spelled(flight.easing, as: Easing.self)
                .map { "\($0)(\(flight.easing))" } ?? "easing \(flight.easing)"

            out += indent
                + "  \(flight.property) flies over \(flight.length)ms"
                + " \(easing) on \(flight.channel)"
                + (flight.report == 0 ? "" : ", reported every \(flight.report)ms")
                + "\n"
        }

        // After the properties that arrived, which is the order they are
        // written in: what this element says now, then what it has stopped
        // saying.
        if !node.cleared.isEmpty {
            out += indent + "  clears \(node.cleared.joined(separator: " "))\n"
        }

        if !node.events.isEmpty {
            let all = node.events.map { "\($0.name)=\($0.id)" }.joined(separator: " ")
            out += indent + "  on \(all)\n"
        }

        for child in node.children {
            dump(child, depth: depth + 1, into: &out)
        }
    }

    private static func spelled(_ identity: WireIdentity) -> String {
        switch identity {
        case .number(let value): return String(value)
        case .name(let value): return "\"\(value)\""
        }
    }

    /// The human-readable rendering a `.bin` fixture's `.txt` sidecar carries:
    /// one act per line, its arguments indented under it. What review reads,
    /// the bytes being the contract.
    public static func dump(_ acts: [WireAct]) -> String {
        var out = ""

        for act in acts {
            out += act.name
            if let completion = act.completion {
                out += " completion=\(completion)"
            }
            out += "\n"

            for argument in act.arguments {
                out += "  " + line(for: argument) + "\n"
            }
        }

        return out
    }

    /// One value's line in the dump - the leading word is the ARM it crossed
    /// as, so `string "Normal"` and `name "Normal"` are told apart by a reader
    /// exactly as the wire tells them apart.
    ///
    /// `key` is the property this value was written under, where there is one.
    /// Only a key can say which closed vocabulary a member number belongs to,
    /// so it is threaded from the ONE caller that has one; every other entry
    /// point - an act's arguments, a reply, an event's payload, an environment
    /// push - and every value NESTED inside a list passes nothing, and a
    /// number there is printed bare because that is all that is known about it.
    private static func line(for value: PropValue, under key: String? = nil) -> String {
        switch value {
        case .bool(let flag):
            return flag ? "true" : "false"
        case .number(let number):
            return "number \(spelled(number))"
        case .string(let text):
            return "string \"\(text)\""
        // `[]` for an empty one rather than the tag and nothing: a line ending
        // in a space is whitespace an editor strips and a byte-for-byte
        // fixture check then fails on, and "no elements" is worth saying out
        // loud in a file whose whole job is to be read.
        case .numbers(let numbers):
            guard !numbers.isEmpty else { return "numbers []" }
            return "numbers " + numbers.map(spelled).joined(separator: ",")
        case .strings(let strings):
            guard !strings.isEmpty else { return "strings []" }
            return "strings " + strings.map { "\"\($0)\"" }.joined(separator: ",")
        case .name(let name):
            return "name \"\(name)\""
        case .enumeration(let member):
            guard let spelling = key.flatMap({ spelling(of: member, under: $0) }) else {
                return "enum \(member)"
            }
            return "enum \(spelling)(\(member))"
        case .nothing:
            return "nothing"
        case .color(let red, let green, let blue, let alpha):
            return "color " + [alpha, red, green, blue].map(hex2).joined()
        case .values(let values):
            return "values [" + values.map { line(for: $0) }.joined(separator: ", ") + "]"
        }
    }

    // MARK: - What a member number means

    /// The spelling of one member of a closed vocabulary, given the property
    /// key it was written under: `(4, "lineBreakMode")` is `tailTruncation`.
    ///
    /// The probe's one table, and it is a table of KEYS - `Prop`'s own members
    /// rather than literals, so a renamed property is a compile error here
    /// instead of a sidecar that quietly goes back to printing digits. The
    /// spellings come out of the library's enums, which is what keeps the two
    /// from ever disagreeing about a name.
    ///
    /// Nil where the probe cannot honestly answer, and all three cases are
    /// meant to print the bare number:
    ///
    ///   - a key that is not listed - an application's own vocabulary, or one
    ///     added to the library and not to this table, which is what
    ///     `testEveryEnumerationInASidecarIsSpelled` exists to catch;
    ///   - a member number the vocabulary does not have, which is a bug worth
    ///     seeing as a number;
    ///   - `aspect`, which is `Aspect` on an image and `Stretch` on a shape.
    ///     Two vocabularies, both numbered from 0, and the key alone cannot
    ///     part them - so it prints `enum 2` rather than a spelling that would
    ///     be wrong half the time. (`position` is the near miss that IS
    ///     answerable: a carousel's position is a plain number and never gets
    ///     here, so an enumeration under that key is a FlexLayout's.)
    private static func spelling(of member: Int32, under key: String) -> String? {
        switch key {
        // VisualElement, View and the text mixins.
        case Prop.horizontalOptions.name, Prop.verticalOptions.name:
            return spelled(member, as: LayoutOptions.self)
        case Prop.horizontalTextAlignment.name, Prop.verticalTextAlignment.name:
            return spelled(member, as: TextAlignment.self)
        case Prop.lineBreakMode.name:
            return spelled(member, as: LineBreakMode.self)
        case Prop.textTransform.name:
            return spelled(member, as: TextTransform.self)
        case Prop.safeAreaEdges.name:
            return spelled(member, as: SafeAreaRegions.self)

        // The inputs.
        case Prop.keyboard.name:
            return spelled(member, as: Keyboard.self)
        case Prop.returnType.name:
            return spelled(member, as: ReturnType.self)
        case Prop.clearButtonVisibility.name:
            return spelled(member, as: ClearButtonVisibility.self)
        case Prop.autoSize.name:
            return spelled(member, as: EditorAutoSizeOption.self)

        // Scrolling, and the pages.
        case Prop.orientation.name:
            return spelled(member, as: ScrollOrientation.self)
        case Prop.horizontalScrollBarVisibility.name, Prop.verticalScrollBarVisibility.name:
            return spelled(member, as: ScrollBarVisibility.self)
        case Prop.flyoutLayoutBehavior.name:
            return spelled(member, as: FlyoutLayoutBehavior.self)
        case Prop.modalPresentationStyle.name:
            return spelled(member, as: UIModalPresentationStyle.self)
        case Prop.order.name:
            return spelled(member, as: ToolbarItemOrder.self)

        // FlexLayout, whose family is numbered four different ways.
        case Prop.direction.name:
            return spelled(member, as: FlexDirection.self)
        case Prop.wrap.name:
            return spelled(member, as: FlexWrap.self)
        case Prop.justifyContent.name:
            return spelled(member, as: FlexJustify.self)
        case Prop.alignItems.name:
            return spelled(member, as: FlexAlignItems.self)
        case Prop.alignContent.name:
            return spelled(member, as: FlexAlignContent.self)
        case Prop.flexLayoutAlignSelf.name:
            return spelled(member, as: FlexAlignSelf.self)
        case Prop.position.name:
            return spelled(member, as: FlexPosition.self)

        // The swipe.
        case Prop.mode.name:
            return spelled(member, as: SwipeMode.self)
        case Prop.swipeBehaviorOnInvoked.name:
            return spelled(member, as: SwipeBehaviorOnInvoked.self)
        // The side a set of swipe items sits on is INTERNAL to the library -
        // the items are a slot rather than something an author names - so this
        // is the probe's own spelling of it, in Views/SwipeView.swift's order.
        // The same arrangement `dumpEnvironment` makes for the domain byte.
        case Prop.side.name:
            return spelled(member, amongst: ["left", "right", "top", "bottom"])

        // The shapes and the map.
        case Prop.strokeLineCap.name:
            return spelled(member, as: PenLineCap.self)
        case Prop.strokeLineJoin.name:
            return spelled(member, as: PenLineJoin.self)
        case Prop.fillRule.name:
            return spelled(member, as: FillRule.self)
        case Prop.indicatorsShape.name:
            return spelled(member, as: IndicatorShape.self)
        case Prop.mapType.name:
            return spelled(member, as: MapType.self)

        // The bit sets. MAUI's own bits, so the numbers come from the library
        // and only the member NAMES are written out - an OptionSet's members
        // are static properties, which nothing can enumerate.
        case Prop.fontAttributes.name:
            return spelled(member, asBitsOf: [
                ("none", FontAttributes.none.rawValue),
                ("bold", FontAttributes.bold.rawValue),
                ("italic", FontAttributes.italic.rawValue),
            ])
        case Prop.textDecorations.name:
            return spelled(member, asBitsOf: [
                ("none", TextDecorations.none.rawValue),
                ("underline", TextDecorations.underline.rawValue),
                ("strikethrough", TextDecorations.strikethrough.rawValue),
            ])
        case Prop.absoluteLayoutFlags.name:
            return spelled(member, asBitsOf: [
                ("none", AbsoluteLayoutFlags.none.rawValue),
                ("xProportional", AbsoluteLayoutFlags.xProportional.rawValue),
                ("yProportional", AbsoluteLayoutFlags.yProportional.rawValue),
                ("widthProportional", AbsoluteLayoutFlags.widthProportional.rawValue),
                ("heightProportional", AbsoluteLayoutFlags.heightProportional.rawValue),
                ("positionProportional", AbsoluteLayoutFlags.positionProportional.rawValue),
                ("sizeProportional", AbsoluteLayoutFlags.sizeProportional.rawValue),
                ("all", AbsoluteLayoutFlags.all.rawValue),
            ])
        case Prop.swipeDirection.name:
            return spelled(member, asBitsOf: [
                ("right", SwipeDirection.right.rawValue),
                ("left", SwipeDirection.left.rawValue),
                ("up", SwipeDirection.up.rawValue),
                ("down", SwipeDirection.down.rawValue),
                ("all", SwipeDirection.all.rawValue),
            ])

        default:
            return nil
        }
    }

    /// One member of a vocabulary the LIBRARY declares - read straight off the
    /// enum, so the probe cannot spell a case differently from the type that
    /// owns it. Nil for a number the vocabulary has no case for.
    private static func spelled<Vocabulary: RawRepresentable>(
        _ member: Int32,
        as vocabulary: Vocabulary.Type
    ) -> String? where Vocabulary.RawValue == Int32 {
        Vocabulary(rawValue: member).map { String(describing: $0) }
    }

    /// One member of a vocabulary the probe has to spell for itself, because
    /// the library keeps it internal - the names in declaration order, the
    /// number being the index. Nil for anything outside the list.
    private static func spelled(_ member: Int32, amongst names: [String]) -> String? {
        names.indices.contains(Int(member)) ? names[Int(member)] : nil
    }

    /// A BIT SET's bits, named: 3 under `fontAttributes` is `bold|italic`.
    ///
    /// A whole-set match comes first, so `AbsoluteLayoutFlags.all` reads as
    /// `all` rather than as the four bits that -1 happens to contain, and
    /// `positionProportional` beats `xProportional|yProportional` - both are
    /// names MAUI itself declares for that number. Failing that the single
    /// bits are named, and a bit no member accounts for gives up and answers
    /// nil: half a spelling would read as the whole of one.
    private static func spelled(
        _ bits: Int32,
        asBitsOf members: [(name: String, bits: Int32)]
    ) -> String? {
        if let whole = members.first(where: { $0.bits == bits }) { return whole.name }

        var covered: Int32 = 0
        var named: [String] = []

        for member in members where member.bits != 0
            && member.bits & (member.bits - 1) == 0
            && bits & member.bits == member.bits {
            named.append(member.name)
            covered |= member.bits
        }

        guard covered == bits, !named.isEmpty else { return nil }
        return named.joined(separator: "|")
    }

    /// One channel as two uppercase hex digits - so a colour reads in the
    /// sidecar the way it was written in the source, alpha first.
    private static func hex2(_ value: UInt8) -> String {
        let digits = Array("0123456789ABCDEF")
        return String([digits[Int(value >> 4)], digits[Int(value & 0xF)]])
    }

    /// A whole number without its ".0", everything else as Swift spells it.
    private static func spelled(_ number: Double) -> String {
        if number.isFinite, number == number.rounded(), abs(number) < 1e15 {
            return String(Int64(number))
        }
        return "\(number)"
    }

    // MARK: - The host's two channels

    /// One decoded reply: how an act came back.
    public enum WireReply: Equatable {
        /// The act ran, and these are its values - none for a method that
        /// returns nothing.
        case finished([PropValue])

        /// The act could not be performed, and this is why.
        case failed(String)
    }

    /// Decodes an event's payload - the probe's own reading of the bytes the
    /// host writes and the library reads, so a bug in either is a mismatch
    /// here rather than two halves agreeing on the same mistake. Empty bytes
    /// are the payload of an event with nothing to say.
    public static func decodePayload(_ bytes: [UInt8]) -> [PropValue] {
        guard !bytes.isEmpty else { return [] }

        var at = 0
        precondition(
            read(&at, bytes) == Wire.version,
            "wire version \(bytes[0]), this probe reads \(Wire.version)")

        let values = hostValues(&at, bytes)
        precondition(at == bytes.count, "the payload carries bytes past its values")
        return values
    }

    /// Decodes an act's outcome, both arms.
    public static func decodeReply(_ bytes: [UInt8]) -> WireReply {
        var at = 0
        precondition(
            read(&at, bytes) == Wire.version,
            "wire version \(bytes[0]), this probe reads \(Wire.version)")

        let ok = read(&at, bytes)
        let values = hostValues(&at, bytes)
        precondition(at == bytes.count, "the reply carries bytes past its values")

        if ok == 1 { return .finished(values) }

        precondition(values.count == 1, "a failure carries exactly one value, the reason")
        guard case .string(let reason) = values[0] else {
            preconditionFailure("a failure's reason is text")
        }
        return .failed(reason)
    }

    /// Decodes a host-raised event - the name the application registered,
    /// then the counted value list both host channels share.
    public static func decodeHostEvent(_ bytes: [UInt8]) -> (name: String, payload: [PropValue]) {
        var at = 0
        precondition(
            read(&at, bytes) == Wire.version,
            "wire version \(bytes[0]), this probe reads \(Wire.version)")

        let name = hostString(&at, bytes)
        let values = hostValues(&at, bytes)
        precondition(at == bytes.count, "the event carries bytes past its values")
        return (name, values)
    }

    /// Decodes a standard-environment push - the domain byte, then the
    /// counted value list every host channel shares.
    public static func decodeEnvironment(_ bytes: [UInt8]) -> (domain: UInt8, payload: [PropValue]) {
        var at = 0
        precondition(
            read(&at, bytes) == Wire.version,
            "wire version \(bytes[0]), this probe reads \(Wire.version)")

        let domain = read(&at, bytes)
        let values = hostValues(&at, bytes)
        precondition(at == bytes.count, "the push carries bytes past its values")
        return (domain, values)
    }

    /// The environment push's sidecar rendering: the domain by name - the
    /// probe's own spelling of the closed vocabulary - then one value per
    /// line.
    public static func dumpEnvironment(_ bytes: [UInt8]) -> String {
        let push = decodeEnvironment(bytes)

        let domains: [UInt8: String] = [
            1: "battery", 2: "connectivity", 3: "display", 4: "locale",
            5: "device", 6: "app", 7: "window",
        ]
        let name = domains[push.domain] ?? "domain \(push.domain)"

        return "environment \(name)\n"
            + push.payload.map { "  " + line(for: $0) + "\n" }.joined()
    }

    /// The host event's sidecar rendering: the name, then one value per line.
    ///
    /// NO values reads `(none)`, never `nothing`: `nothing` is a VALUE - the
    /// wire's own tag 12, an argument that is not there - and a list holding
    /// one is a different buffer from a list holding none. Two different
    /// buffers that rendered alike would lie to exactly the reader a sidecar
    /// exists for.
    public static func dumpHostEvent(_ bytes: [UInt8]) -> String {
        let event = decodeHostEvent(bytes)

        guard !event.payload.isEmpty else { return "event \"\(event.name)\"\n  (none)\n" }

        return "event \"\(event.name)\"\n"
            + event.payload.map { "  " + line(for: $0) + "\n" }.joined()
    }

    /// The payload's sidecar rendering, one value per line - and `(none)` for
    /// no values at all, told apart from the `nothing` VALUE as above.
    public static func dumpPayload(_ bytes: [UInt8]) -> String {
        let values = decodePayload(bytes)
        guard !values.isEmpty else { return "(none)\n" }
        return values.map { line(for: $0) + "\n" }.joined()
    }

    /// The reply's sidecar rendering: the arm, then its values.
    public static func dumpReply(_ bytes: [UInt8]) -> String {
        switch decodeReply(bytes) {
        case .finished(let values):
            return "finished\n" + values.map { "  " + line(for: $0) + "\n" }.joined()
        case .failed(let reason):
            return "failed \"\(reason)\"\n"
        }
    }

    /// One byte off a host-channel buffer, bounds-checked the probe's way.
    private static func read(_ at: inout Int, _ bytes: [UInt8]) -> UInt8 {
        precondition(at < bytes.count, "the buffer ends mid-value")
        defer { at += 1 }
        return bytes[at]
    }

    /// A length-prefixed string off a host-channel buffer - an event's name,
    /// or a string value inside the list.
    private static func hostString(_ at: inout Int, _ bytes: [UInt8]) -> String {
        func u16() -> Int {
            Int(read(&at, bytes)) | Int(read(&at, bytes)) << 8
        }

        let count = u16() | u16() << 16
        precondition(at + count <= bytes.count, "the buffer ends mid-string")
        defer { at += count }
        return String(decoding: bytes[at..<at + count], as: UTF8.self)
    }

    /// A counted value list, the shape both host channels share.
    ///
    /// Every arm `Wire.value(_:)` reads on the way IN, and no more: the host
    /// never sends a property token or a name, both of those riding a
    /// dictionary this side owns and the host only ever reads. A COLOUR it
    /// does send, a stopped or sampled colour flight answering with one, so
    /// the arm is here and a payload of four bytes is not four numbers.
    private static func hostValues(_ at: inout Int, _ bytes: [UInt8]) -> [PropValue] {
        func u16() -> Int {
            Int(read(&at, bytes)) | Int(read(&at, bytes)) << 8
        }

        func f64() -> Double {
            var bits: UInt64 = 0
            for shift in 0..<8 {
                bits |= UInt64(read(&at, bytes)) << (8 * shift)
            }
            return Double(bitPattern: bits)
        }

        func string() -> String {
            hostString(&at, bytes)
        }

        func i32() -> Int32 {
            Int32(bitPattern: UInt32(u16()) | UInt32(u16()) << 16)
        }

        func value() -> PropValue {
            switch read(&at, bytes) {
            case 1: return .bool(false)
            case 2: return .bool(true)
            case 3: return .number(f64())
            case 4: return .string(string())
            case 5: return .numbers((0..<u16()).map { _ in f64() })
            case 6: return .strings((0..<u16()).map { _ in string() })
            case 8:
                let red = read(&at, bytes)
                let green = read(&at, bytes)
                let blue = read(&at, bytes)
                return .color(red: red, green: green, blue: blue, alpha: read(&at, bytes))
            case 9: return .values((0..<u16()).map { _ in value() })
            case 10: return .enumeration(i32())
            case 12: return .nothing
            case let tag: preconditionFailure("unknown value tag \(tag)")
            }
        }

        return (0..<Int(read(&at, bytes))).map { _ in value() }
    }
}
