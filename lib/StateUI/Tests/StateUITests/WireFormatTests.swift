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

