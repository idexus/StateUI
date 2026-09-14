// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import XCTest
@_spi(Host) @testable import StateUI

/// The deterministic wire encoding exposed to foreign-language native hosts.
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

    func testPropertiesAreSortedSoTwoRendersCanBeCompared() {
        let node = Node(type: "Label", props: [
            "text": .string("hi"),
            "fontSize": .number(20),
            "background": Color.white.propValue,
        ])

        let keys = message(node).root.props.map(\.key)
        XCTAssertEqual(keys, keys.sorted())
    }

    func testANumberCrossesAsItsOwnBits() {
        XCTAssertEqual(
            props(of: message(Node(type: "Label", props: ["fontSize": .number(20.5)])).root)["fontSize"],
            .number(20.5))
    }

    func testAValueMadeOfPartsTravelsAsItsParts() {
        XCTAssertEqual(
            props(of: message(Node(type: "Label", props: ["padding": .numbers([1, 2, 3, 4])])).root)["padding"],
            .numbers([1, 2, 3, 4]))
        XCTAssertEqual(
            props(of: message(Node(type: "Picker", props: ["options": .strings(["a", "b"])])).root)["options"],
            .strings(["a", "b"]))
    }

    func testAStringsLengthIsCountedInBytesNotCharacters() {
        let value = "say \"hi\",\n\tor do not - zażółć 🙂"
        XCTAssertNotEqual(value.count, value.utf8.count)
        XCTAssertEqual(
            props(of: message(Node(type: "Label", props: ["text": .string(value)])).root)["text"],
            .string(value))
    }

    func testAnIdentitySaysWhichKindItIs() {
        XCTAssertEqual(message(label("hi")).root.identity, .number(1))
        XCTAssertEqual(message(label("hi", id: "row")).root.identity, .name("row"))
    }

    func testANameIsAnnouncedOncePerSession() {
        let dictionary = WireDictionary()
        let names = WireNames()
        let differ = Differ()

        func bytes(_ node: Node) -> [UInt8] {
            Wire.encode(
                differ.reconcile(nil, with: node).patch,
                generation: 1,
                dictionary: dictionary)
        }

        let first = bytes(label("hi"))
        let second = bytes(label("again"))
        _ = WireProbe.decodeMessage(first, names: names)

        XCTAssertEqual(WireProbe.decodeMessage(second, names: names).root.type, "Label")
        XCTAssertLessThan(second.count, first.count)
    }

    func testEveryNameUpToTheCeilingIsNumberedOnce() {
        let dictionary = WireDictionary()
        var issued: Set<UInt16> = []

        for number in 1 ... Int(UInt16.max) {
            issued.insert(dictionary.id(of: "name\(number)"))
        }

        XCTAssertEqual(issued.count, Int(UInt16.max))
        XCTAssertTrue(issued.contains(UInt16.max))
        XCTAssertFalse(issued.contains(0))
        XCTAssertEqual(dictionary.id(of: "name1"), 1)
    }

    func testACountThatFitsIsWrittenAsItIs() {
        XCTAssertEqual(Wire.count(0, of: "x") as UInt16, 0)
        XCTAssertEqual(Wire.count(65_535, of: "x") as UInt16, 65_535)
        XCTAssertEqual(Wire.count(255, of: "x") as UInt8, 255)
    }

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

    func testEveryTokenIsSpelledLikeItsMember() throws {
        var wrong: [String] = []

        for (vocabulary, member, spelling) in try tokens() {
            let expected = vocabulary == "NodeType" ? member.capitalizedFirst : member
            if spelling != expected {
                wrong.append("\(vocabulary).\(member) is written \"\(spelling)\", not \"\(expected)\"")
            }
        }

        XCTAssertEqual(wrong, [])
    }

    /// Every name the Swift side can send is a member on the MAUI host's side,
    /// spelled the same - and every member there is a name this side sends.
    ///
    /// The one guard that reads both languages, and the only thing that can:
    /// a name leaves here as a token and arrives there as a lookup, so a name
    /// with no member on the far side is not a compile error anywhere - it is
    /// a property that quietly does nothing, or an act that answers "unknown
    /// command" to a handler that was awaiting it. The other way round, a
    /// member left behind by a token that was removed is a capability the host
    /// goes on realizing for nothing. The host maps a name to a member by
    /// camelCasing the member, capitalizing it for a node type.
    func testTheTokensAndTheHostsMembersAreTheSameNames() throws {
        let vocabularies = [
            ("NodeType", "Protocol/SwiftNodeType.cs"),
            ("Prop", "Protocol/SwiftProp.cs"),
            ("Event", "Protocol/SwiftEvent.cs"),
            ("Act", "Protocol/SwiftAct.cs"),
        ]

        let host = try Fixtures.mauiSources()
        var missing: [String] = []
        var stranded: [String] = []
        var checked = 0

        for (vocabulary, file) in vocabularies {
            let declared = try tokens().filter { $0.vocabulary == vocabulary }.map(\.member)
            XCTAssertFalse(declared.isEmpty, "no \(vocabulary) was read from Core/Tokens.swift")

            guard let enumeration = host.first(where: { $0.path.hasSuffix(file) })?.text else {
                XCTFail("\(file) was not found in the MAUI host")
                continue
            }

            // A member is a line of the shape `Focus = 16,`. Reading the
            // ASSIGNMENT is what keeps a `<summary>` naming a method from
            // counting as a declaration.
            let members = Set(
                enumeration.split(separator: "\n")
                    .map { $0.trimmed }
                    .filter { $0.contains(" = ") && $0.hasSuffix(",") }
                    .compactMap { $0.split(separator: " ").first.map(String.init) })

            checked += declared.count
            missing += declared
                .filter { !members.contains($0.capitalizedFirst) }
                .map { "\(vocabulary).\($0)" }

            // `None` is each enumeration's zero - the absence of a member,
            // which no token names.
            let named = Set(declared.map(\.capitalizedFirst)).union(["None"])
            stranded += members.subtracting(named).sorted().map { "\(vocabulary).\($0)" }
        }

        XCTAssertGreaterThan(checked, 300, "the scan read almost nothing")
        XCTAssertEqual(missing, [], "declared in Core/Tokens.swift with no member in the MAUI host")
        XCTAssertEqual(stranded, [], "a member in the MAUI host for a name Core/Tokens.swift does not declare")
    }

    /// Every act the MAUI host has a MEMBER for also has an ARM in `Perform`.
    /// A member with no arm falls to the application's registry and then
    /// answers "unknown command" to a handler awaiting a name the LIBRARY
    /// ships, and nothing in either language failed to compile.
    func testEveryActMemberHasAnArmInPerform() throws {
        let host = try Fixtures.mauiSources()

        guard let enumeration = host.first(where: { $0.path.hasSuffix("Protocol/SwiftAct.cs") })?.text,
              let session = host.first(where: { $0.path.hasSuffix("Rendering/StateUISession.cs") })?.text
        else {
            return XCTFail("SwiftAct.cs or StateUISession.cs was not found in the MAUI host")
        }

        let members = enumeration.split(separator: "\n")
            .map { $0.trimmed }
            .filter { $0.contains(" = ") && $0.hasSuffix(",") }
            .compactMap { $0.split(separator: " ").first.map(String.init) }
            .filter { $0 != "None" }

        XCTAssertGreaterThan(members.count, 10, "too few members to be reading the right file")
        XCTAssertEqual(
            members.filter { !session.contains("case SwiftAct.\($0):") }, [],
            "members of SwiftAct with no `case` in StateUISession.Perform")
    }

    /// A placement crosses as a RUN OF DOUBLES with no field markers on it -
    /// the host reads it by stride - so the two sides' idea of how many
    /// numbers a view takes is the whole of that contract. The shade's absence
    /// is the one number an opacity cannot be, so the host's threshold sits
    /// strictly between what this side writes for "no shade" and the nought a
    /// view wearing none of one answers.
    func testThePlacementStrideIsTheSameOnBothSides() throws {
        guard let channels = try Fixtures.mauiSources()
            .first(where: { $0.path.hasSuffix("Rendering/MotionTargets.cs") })?.text
        else {
            return XCTFail("MotionTargets.cs was not found in the MAUI host")
        }

        func number(_ declaration: String) -> Double? {
            guard let line = channels.split(separator: "\n").map({ $0.trimmed })
                .first(where: { $0.hasPrefix(declaration) })
            else { return nil }

            return Double(line.drop(while: { $0 != "=" }).dropFirst()
                .prefix(while: { $0 != ";" }).trimmed)
        }

        XCTAssertEqual(number("internal const int Fields"), Double(PackedPlacement.fields))

        let threshold = try XCTUnwrap(
            number("internal const double Unshaded"), "MotionTargets.cs names no shade threshold")

        XCTAssertGreaterThan(threshold, PackedPlacement.unshaded)
        XCTAssertLessThan(threshold, 0)
    }

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

            let declaration = code.dropFirst("static let ".count)
            guard let equals = declaration.range(of: " = "),
                  let opens = declaration.range(of: "(\""),
                  let closes = declaration.range(of: "\")", options: .backwards)
            else {
                XCTFail("Core/Tokens.swift has an unreadable declaration: \(code)")
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
    fileprivate var capitalizedFirst: String {
        guard let first else { return String(self) }
        return first.uppercased() + String(dropFirst())
    }

    fileprivate var trimmed: String {
        trimmingCharacters(in: .whitespaces)
    }
}

