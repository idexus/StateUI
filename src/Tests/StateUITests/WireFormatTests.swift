// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The wire format, one rule at a time - each read back through the probe, so
// what is pinned is what actually crossed, not a spelling.

import Foundation
import StateUIWireProbe
import XCTest
@testable import StateUI

final class WireFormatTests: XCTestCase {
    private func message(
        _ node: Node,
        dictionary: WireDictionary = WireDictionary(),
        names: WireNames = WireNames()
    ) -> (generation: Int, complete: Bool, root: WireProbe.WireNode) {
        let differ = Differ()
        return WireProbe.decodeMessage(
            Wire.encode(differ.reconcile(nil, with: node).patch, generation: 1, dictionary: dictionary),
            names: names)
    }

    private func props(of node: WireProbe.WireNode) -> [String: PropValue] {
        Dictionary(uniqueKeysWithValues: node.props.map { ($0.key, $0.value) })
    }

    func testAMessageCarriesItsGeneration() {
        XCTAssertEqual(message(label("hi")).generation, 1)
    }

    /// Sorted in the writer, preserved by the reader - it makes diffs between
    /// two renders meaningful and the fixture sidecars stable.
    func testPropertiesAreSortedSoTwoRendersCanBeCompared() {
        let node = Node(type: "Label", props: [
            "text": .string("hi"),
            "fontSize": .number(20),
            "backgroundColor": Color.white.propValue,
        ])

        let keys = message(node).root.props.map(\.key)
        XCTAssertEqual(keys, keys.sorted(), "properties are written in name order")
    }

    /// A number is a double's own bits, whole or not - nothing is formatted on
    /// the way out and nothing parsed on the way in.
    func testANumberCrossesAsItsOwnBits() {
        XCTAssertEqual(
            props(of: message(Node(type: "Label", props: ["fontSize": .number(20)])).root)["fontSize"],
            .number(20))

        XCTAssertEqual(
            props(of: message(Node(type: "Label", props: ["fontSize": .number(20.5)])).root)["fontSize"],
            .number(20.5))
    }

    /// A value made of parts travels as its parts, under a tag that says which
    /// kind they are and a count that says how many - never as text with a
    /// separator in it. A list of MIXED kinds is `.values`, which is what a
    /// brush, a grid length and a drawing ride; BrushTests holds that one.
    func testAValueMadeOfPartsTravelsAsItsParts() {
        XCTAssertEqual(
            props(of: message(Node(type: "Label", props: ["padding": .numbers([1, 2, 3, 4])])).root)["padding"],
            .numbers([1, 2, 3, 4]))

        XCTAssertEqual(
            props(of: message(Node(type: "Picker", props: ["itemsSource": .strings(["a", "b"])])).root)["itemsSource"],
            .strings(["a", "b"]))
    }

    /// A string's length is counted in BYTES of UTF-8, not in characters, so
    /// text arrives whole whatever it holds and nothing is ever escaped.
    ///
    /// The literal is what makes that checkable: `zażółć 🙂` is eight
    /// characters and seventeen bytes, so a writer counting characters would
    /// under-state the length and every value after this one would be read
    /// from the middle of it. The quotes and the newline cost nothing to keep
    /// and say the other half - that no character is special here.
    func testAStringsLengthIsCountedInBytesNotCharacters() {
        let text = "say \"hi\",\n\tor do not - zażółć 🙂"

        XCTAssertEqual(text.count, 31)
        XCTAssertEqual(text.utf8.count, 38, "the two counts differ, which is the point")

        XCTAssertEqual(
            props(of: message(Node(type: "Label", props: ["text": .string(text)])).root)["text"],
            .string(text))
    }

    func testAnIdentitySaysWhichKindItIs() {
        XCTAssertEqual(
            message(label("hi")).root.identity, .number(1),
            "the renderer's own is a number")
        XCTAssertEqual(
            message(label("hi", id: "row")).root.identity, .name("row"),
            "the author's is a NAME - its own arm, which is what keeps "
                + #".id("12") out of the renderer's own numbering"#)
    }

    /// A name is announced ONCE per session: the first message that uses it
    /// carries the pair, and every message after rides the number alone. The
    /// probe's `names +N` line in a sidecar is this section's count.
    func testANameIsAnnouncedOncePerSession() {
        let dictionary = WireDictionary()
        let names = WireNames()

        let differ = Differ()
        func bytes(_ node: Node) -> [UInt8] {
            Wire.encode(differ.reconcile(nil, with: node).patch, generation: 1, dictionary: dictionary)
        }

        let first = bytes(label("hi"))
        let second = bytes(label("again"))

        // The second message reuses the first's names, so its announcement
        // section is EMPTY - it must still decode, through what the first
        // taught. (Each reconcile(nil,...) is its own differ walk; the
        // dictionary is the session's and spans them.)
        _ = WireProbe.decodeMessage(first, names: names)
        let again = WireProbe.decodeMessage(second, names: names)
        XCTAssertEqual(again.root.type, "Label")

        // And the section's size says so: version+complete+generation is 6
        // bytes, an empty announcement section 2 - a second message is
        // smaller than the first by exactly its education.
        XCTAssertLessThan(second.count, first.count)
    }

    /// A name id is the reader's ONLY handle on a name, so a session issues
    /// every number the wire has for one exactly once and never comes back
    /// round to a number it has already given away.
    ///
    /// A vocabulary an author NAMES - a style key, a font family, a visual
    /// state - rides the same dictionary a property key does, so this ceiling
    /// is reachable by an application that builds those out of its own data
    /// rather than from a fixed set. It ends the process with a sentence
    /// saying so, which is the only honest answer: the numbers cannot be
    /// renumbered mid-session and issuing one twice would rename half a tree
    /// with nothing on the wire able to notice.
    func testEveryNameUpToTheCeilingIsNumberedOnce() {
        let dictionary = WireDictionary()
        var issued: Set<UInt16> = []

        for number in 1 ... Int(UInt16.max) {
            issued.insert(dictionary.id(of: "name\(number)"))
        }

        XCTAssertEqual(issued.count, Int(UInt16.max), "a number was issued twice")
        XCTAssertTrue(issued.contains(UInt16.max), "the last number the wire has went unused")
        XCTAssertFalse(issued.contains(0), "zero is not a name")

        // And a name already numbered keeps its number however full it is.
        XCTAssertEqual(dictionary.id(of: "name1"), 1)
    }

    /// A list's length is written in a fixed number of bits, and a count that
    /// fits is written as it stands - the guard is the sentence for one that
    /// does not, never a clamp that would write a shorter list than was meant.
    func testACountThatFitsIsWrittenAsItIs() {
        XCTAssertEqual(Wire.count(0, of: "x") as UInt16, 0)
        XCTAssertEqual(Wire.count(65_535, of: "x") as UInt16, 65_535)
        XCTAssertEqual(Wire.count(255, of: "x") as UInt8, 255)
    }

    /// The same tree through a fresh dictionary is the same bytes, to the
    /// byte - what lets a fixture BE the contract with no table behind it.
    func testTheSameTreeWritesTheSameBytesEveryTime() {
        func bytes() -> [UInt8] {
            let differ = Differ()
            return Wire.encode(
                differ.reconcile(nil, with: label("hi")).patch,
                generation: 1,
                dictionary: WireDictionary())
        }

        XCTAssertEqual(bytes(), bytes())
    }

    /// The sources of this library spell no wire name out: every node type,
    /// property key, event and act is a TOKEN, and Core/Tokens.swift is
    /// deliberately the one place the spellings exist. Comment lines are the
    /// exception - doc examples teach the literal escape, which is public
    /// API. Source-read, so it can only under-report.
    ///
    /// Read TWICE, because each pass sees what the other cannot. The first
    /// reads line by line and can therefore name the line; a call WRAPPED over
    /// two of them slips straight past it - `setValue(` on one line and
    /// `"safeAreaEdges",` on the next, or a `props: ["key":` split at the
    /// bracket. So the second pass takes the file's code with the whitespace
    /// removed, where a wrapped call reads exactly as a written-out one does.
    /// It cannot name a line, which is why the first pass stays.
    func testTheSourcesSpellNoNames() throws {
        let literals = [
            "setValue(\"", "Node(type: \"", "type: \"", "type == \"",
            "addHandler(\"", "onEvent(\"", "props[\"", "props: [\"",
            "events[\"", "events: [\"", "case \"",
            "NodeType(\"", "Prop(\"", "Event(\"", "Act(\"",
            "stateUICall(\"", "stateUISend(\"",
        ]

        for (path, text) in try Fixtures.allSources()
        where !path.hasSuffix("Core/Tokens.swift") {
            // The macro declarations name their implementation types in
            // #externalMacro(type:) - Swift's own syntax, not the wire's.
            if path.hasSuffix("Core/StateClass.swift") { continue }

            let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
                .map { $0.drop(while: { $0 == " " }) }
                .filter { !$0.hasPrefix("//") }

            var named: Set<String> = []

            for (number, code) in lines.enumerated() {
                for literal in literals where code.contains(literal) {
                    named.insert(literal)
                    XCTFail("""
                        \(path):\(number + 1) spells a name out - '\(literal)…' - \
                        where a token from Core/Tokens.swift belongs
                        """)
                }
            }

            let packed = lines.joined().filter { !$0.isWhitespace }

            for literal in literals where !named.contains(literal) {
                XCTAssertFalse(
                    packed.contains(literal.filter { !$0.isWhitespace }),
                    """
                    \(path) spells a name out over more than one line - \
                    '\(literal)…' - where a token from Core/Tokens.swift belongs
                    """)
            }
        }
    }

    // MARK: - One name, spelled once

    /// A token's string is its own member name - and nothing else.
    ///
    /// `static let fontSize = Prop("fontSize")`, never `Prop("FontSize")` and
    /// never `Prop("font_size")`. A node type is the one that differs, and
    /// differs by a rule rather than a judgement: it names a CLASS, so it is
    /// the member capitalized.
    ///
    /// Worth a test because the two halves of the declaration are read by
    /// different readers - the member by everything in this library, the string
    /// by the renderer - so a mismatch is invisible on both sides and shows up
    /// only as a property that silently does nothing. A third spelling is the
    /// same failure one step worse: `Act("VisualElement.Focus")` under `.focus`
    /// would put a hand-written table back between the two names.
    func testEveryTokenIsSpelledLikeItsMember() throws {
        var wrong: [String] = []

        for (vocabulary, member, spelling) in try tokens() {
            let expected = vocabulary == "NodeType" ? member.capitalizedFirst : member

            if spelling != expected {
                wrong.append(
                    "\(vocabulary).\(member) is written \"\(spelling)\", not \"\(expected)\"")
            }
        }

        XCTAssertEqual(wrong, [], """
            These tokens are spelled differently from the member holding them:

            \(wrong.joined(separator: "\n"))

            A token IS its name. Where the two can differ they eventually do,
            and the difference is only ever visible as a name that reaches
            nothing on the other side.
            """)
    }

    /// Every name the Swift side can send is a member on the renderer's side,
    /// spelled the same.
    ///
    /// The one guard that reads both languages, and the only thing that can:
    /// a name leaves here as a token and arrives there as a lookup, so a
    /// name with no member on the far side is not a compile error anywhere -
    /// it is a property that quietly does nothing, or an act that answers
    /// "unknown command" to a handler that was awaiting it.
    ///
    /// Names only. Whether the member has a CASE in `Perform` is the C# side's
    /// own business, and its switch is exhaustive over the enum.
    func testEveryTokenHasAMemberOnTheOtherSide() throws {
        // One test for all four vocabularies, because they are one rule: a
        // name is announced by number, resolved to a member as the
        // announcement is read, and dispatched on from then on. A vocabulary
        // whose member is missing falls to that enum's `None` - an unknown
        // node type draws the red marker, an unknown property is ignored, an
        // unknown event never fires, an unknown act answers "unknown command".
        let vocabularies = [
            ("NodeType", "Protocol/SwiftNodeType.cs"),
            ("Prop", "Protocol/SwiftProp.cs"),
            ("Event", "Protocol/SwiftEvent.cs"),
            ("Act", "Protocol/SwiftAct.cs"),
        ]

        let runtime = try Fixtures.runtimeSources()
        var missing: [String] = []
        var checked = 0

        for (vocabulary, file) in vocabularies {
            let declared = try tokens()
                .filter { $0.vocabulary == vocabulary }
                .map(\.member)

            XCTAssertFalse(declared.isEmpty, "no \(vocabulary) was read from Core/Tokens.swift")

            guard let enumeration = runtime.first(where: { $0.path.hasSuffix(file) })?.text else {
                XCTFail("\(file) was not found beside the renderer")
                continue
            }

            // A member is a line of the shape `Focus = 16,`. Reading the
            // ASSIGNMENT is what keeps a `<summary>` naming the MAUI method
            // from counting as a declaration.
            let members = Set(
                enumeration.split(separator: "\n")
                    .map { $0.trimmed }
                    .filter { $0.contains(" = ") && $0.hasSuffix(",") }
                    .compactMap { $0.split(separator: " ").first.map(String.init) })

            checked += declared.count
            missing += declared
                .filter { !members.contains($0.capitalizedFirst) }
                .map { "\(vocabulary).\($0)" }
        }

        XCTAssertGreaterThan(checked, 300, "the scan read almost nothing")

        XCTAssertEqual(missing, [], """
            These tokens are declared in Core/Tokens.swift and have no member \
            on the C# side:

            \(missing.joined(separator: "\n"))

            The renderer maps a name to a member by camelCasing the member \
            (capitalizing it, for a NodeType), so a token without one reaches \
            that vocabulary's `None` and is quietly ignored. Nothing fails to \
            compile in either language.
            """)
    }

    /// Every act the renderer has a MEMBER for also has an ARM in `Perform`.
    ///
    /// The far end of `testEveryTokenHasAMemberOnTheOtherSide`, and the failure
    /// it catches is the quieter of the two: a member with no arm falls to
    /// `Perform`'s `default`, which consults the application's act registry and
    /// then answers "unknown command" to a handler that was awaiting it. Swift
    /// throws, the app author reads a message about a name the LIBRARY ships,
    /// and nothing in either language failed to compile.
    ///
    /// Read from Swift because only this side can see both languages -
    /// `Fixtures.runtimeSources()` - and because the C# tests have no locator
    /// for the runtime's own sources, only for `src/Tests/fixtures`.
    /// A placement crosses as a RUN OF DOUBLES with no field markers on it -
    /// the host reads it by stride - so the two sides' idea of how many numbers
    /// a view takes is the whole of that contract, and nothing else would fail
    /// if they disagreed: every view after the first would simply wear its
    /// neighbour's numbers.
    ///
    /// The shade's absence is read the same way and is the one number an
    /// opacity cannot be, so the host's threshold has to sit strictly between
    /// what this side writes for "no shade" and the nought a view wearing none
    /// of one answers.
    func testThePlacementStrideIsTheSameOnBothSides() throws {
        let runtime = try Fixtures.runtimeSources()

        guard let channels = runtime
            .first(where: { $0.path.hasSuffix("Rendering/Channels.cs") })?.text
        else {
            return XCTFail("Channels.cs was not found beside the renderer")
        }

        func number(_ declaration: String, in text: String) -> Double? {
            guard let line = text.split(separator: "\n")
                .map({ $0.trimmed })
                .first(where: { $0.hasPrefix(declaration) })
            else { return nil }

            return Double(line
                .drop(while: { $0 != "=" })
                .dropFirst()
                .prefix(while: { $0 != ";" })
                .trimmed)
        }

        XCTAssertEqual(
            number("private const int Fields", in: channels),
            Double(PackedPlacement.fields),
            "the host reads a placement by stride, and this is the stride")

        let threshold = try XCTUnwrap(
            number("private const double Unshaded", in: channels),
            "Channels.cs names no shade threshold")

        XCTAssertGreaterThan(threshold, PackedPlacement.unshaded, """
            what this side writes for a layout with no shade has to fall BELOW \
            the host's threshold, or a shade is looked for where there is none
            """)

        XCTAssertLessThan(threshold, 0, """
            a view wearing none of a shade the layout HAS answers nought, and \
            nought must read as a shade
            """)
    }

    func testEveryActMemberHasAnArmInPerform() throws {
        let runtime = try Fixtures.runtimeSources()

        guard let enumeration = runtime.first(where: { $0.path.hasSuffix("Protocol/SwiftAct.cs") })?.text,
              let session = runtime.first(where: { $0.path.hasSuffix("Rendering/StateUISession.cs") })?.text
        else {
            return XCTFail("SwiftAct.cs or StateUISession.cs was not found beside the renderer")
        }

        let members = enumeration.split(separator: "\n")
            .map { $0.trimmed }
            .filter { $0.contains(" = ") && $0.hasSuffix(",") }
            .compactMap { $0.split(separator: " ").first.map(String.init) }
            // `None` is the ABSENCE of an arm - the name a registration answers,
            // or nobody. An arm for it would be an arm for every unknown act.
            .filter { $0 != "None" }

        XCTAssertGreaterThan(members.count, 10, "too few members to be reading the right file")

        let armless = members.filter { !session.contains("case SwiftAct.\($0):") }

        XCTAssertEqual(armless, [], """
            These are members of SwiftAct and have no `case` in \
            StateUISession.Perform:

            \(armless.joined(separator: "\n"))

            An act with a member and no arm reaches `default`, is looked for \
            among the application's registrations, and is answered as an \
            unknown command - to a Swift handler that was awaiting it.
            """)
    }

    // MARK: - The sidecars stay worth reading

    /// Every member number a sidecar prints under a property KEY is printed
    /// with its spelling beside it - `lineBreakMode: enum tailTruncation(4)`,
    /// never a bare `enum 4`.
    ///
    /// This is the guard on the probe's vocabulary table, and it is here
    /// rather than in the probe because it reads the OUTPUT: a table entry
    /// that was never added, or one whose vocabulary stopped covering a number
    /// the library sends, shows up as digits in the one artifact a human reads
    /// to review a format change. No spelling crosses the wire, so the sidecar
    /// is where the spelling has to come back, or the review of every change
    /// is a review of numbers.
    ///
    /// What it reads is the one shape a property line has, `key: enum N`, and
    /// `unspellable` below is the only way through it. A number with no key
    /// over it carries no key ON THE WIRE either - an act's positional
    /// argument, an event's payload, a value nested in a list - so there is
    /// nothing to look one up by and the digits are all there is to print.
    ///
    /// A member INSIDE a `values [...]` is that second case even when the list
    /// itself sits under a key: `stroke: values [enum 1, color FFD3D3D3]` is a
    /// brush, whose parts are told apart by position, and the first part's
    /// vocabulary is the brush's rather than `stroke`'s. So a list's members
    /// print bare and this guard does not see them.
    func testEveryEnumerationInASidecarIsSpelled() throws {
        // The properties whose vocabulary the KEY cannot name. `aspect` is
        // `Aspect` on an image and `Stretch` on a shape - both numbered from
        // 0, so half of any spelling would be a lie, and digits are the honest
        // answer. Anything added here needs a reason of that kind.
        let unspellable: Set<String> = ["aspect"]

        var bare: [String] = []
        var read = 0

        let root = Fixtures.directory

        guard let walk = FileManager.default.enumerator(atPath: root.path) else {
            return XCTFail("no fixtures were found at \(root.path)")
        }

        for case let name as String in walk where name.hasSuffix(".txt") {
            let path = name.replacingOccurrences(of: "\\", with: "/")
            let text = try String(contentsOf: root.appendingPathComponent(name), encoding: .utf8)
            read += 1

            for (number, line) in text.split(separator: "\n").enumerated() {
                let code = line.trimmed

                // `<key>: <value>` is the one shape a property line has, and
                // the FIRST colon is the one that separates them - a colon
                // inside the text of a string belongs to the value.
                if let separator = code.range(of: ": ") {
                    let key = String(code[..<separator.lowerBound])
                    let value = code[separator.upperBound...]

                    // A spelled one reads `enum tailTruncation(4)`, which is
                    // not a number; a bare one is nothing but digits.
                    if !key.contains(" "), value.hasPrefix("enum "),
                       Int(value.dropFirst("enum ".count)) != nil,
                       !unspellable.contains(key) {
                        bare.append("\(path):\(number + 1) \(key) - \(code)")
                    }
                }

                // The other member number in a dump: the curve a walk follows,
                // which the probe prints as `cubicOut(5)` when it knows it and
                // as `easing 5` when it does not.
                if code.contains(" flies over "), code.contains(" easing ") {
                    bare.append("\(path):\(number + 1) easing - \(code)")
                }
            }
        }

        XCTAssertGreaterThan(read, 50, "too few sidecars to be reading src/Tests/fixtures")

        XCTAssertEqual(bare, [], """
            These sidecar lines print a member number with no spelling beside it:

            \(bare.joined(separator: "\n"))

            The property's vocabulary belongs in WireProbe's `spelling(of:under:)`,
            so that a reviewer reads `enum tailTruncation(4)` and not `enum 4`.
            Regenerate the fixtures afterwards - STATEUI_UPDATE_FIXTURES=1
            swift test --package-path src/Tests - and read the diff.
            """)
    }

    /// Every `static let <member> = <Vocabulary>("<spelling>")` in Tokens.swift.
    ///
    /// Source-read, like every other guard here, and deliberately literal: it
    /// recognizes the one shape the file is allowed to use, so a declaration
    /// written any other way is reported as unreadable rather than skipped.
    private func tokens() throws -> [(vocabulary: String, member: String, spelling: String)] {
        let text = try String(
            contentsOf: Fixtures.sources.appendingPathComponent("Core/Tokens.swift"),
            encoding: .utf8)

        var found: [(vocabulary: String, member: String, spelling: String)] = []
        var vocabulary = ""

        for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let code = line.trimmed

            if code.hasPrefix("public extension "), code.hasSuffix(" {") {
                vocabulary = String(code.dropFirst("public extension ".count).dropLast(2))
                continue
            }

            if code == "}" {
                vocabulary = ""
                continue
            }

            guard !vocabulary.isEmpty, code.hasPrefix("static let ") else { continue }

            // static let `switch` = NodeType("Switch")
            let declaration = code.dropFirst("static let ".count)

            guard let equals = declaration.range(of: " = "),
                  let opens = declaration.range(of: "(\""),
                  let closes = declaration.range(of: "\")", options: .backwards)
            else {
                XCTFail("Core/Tokens.swift has a declaration this test cannot read: \(code)")
                continue
            }

            let member = declaration[..<equals.lowerBound]
                .trimmingCharacters(in: CharacterSet(charactersIn: "`"))

            found.append((
                vocabulary: vocabulary,
                member: member,
                spelling: String(declaration[opens.upperBound..<closes.lowerBound])))
        }

        return found
    }
}

extension StringProtocol {
    /// The same name with its first character upper-cased - a member's name as
    /// the class or enum member it stands for on the other side. Not
    /// `capitalized`, which lower-cases the rest and would make `GoBack` of
    /// `goBack` into `Goback`.
    fileprivate var capitalizedFirst: String {
        guard let first else { return String(self) }
        return first.uppercased() + String(dropFirst())
    }

    /// The line without its indentation, so a declaration reads the same
    /// wherever it sits. On `StringProtocol` because a `split` yields
    /// `Substring` and every guard here reads a file that way.
    fileprivate var trimmed: String {
        trimmingCharacters(in: .whitespaces)
    }
}
