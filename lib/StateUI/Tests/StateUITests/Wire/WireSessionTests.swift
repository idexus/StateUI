// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The deterministic session of `DeterminismTests`, encoded the way the MAUI
// host reads it: every name-keyed field in name order, and every name
// announced once, by the first message that uses it.

import XCTest
@_spi(Host) @testable import StateUI

final class WireSessionTests: XCTestCase {
    /// The session's renders encoded as one host hears them: generations
    /// counting from one, one dictionary of names.
    private func encoded() -> [(name: String, bytes: [UInt8])] {
        let dictionary = WireDictionary()

        return DeterminismTests.session().enumerated().map { index, message in
            (message.name, Wire.encode(
                message.patch, generation: Int32(index + 1), complete: message.complete,
                dictionary: dictionary))
        }
    }

    /// Every node's properties and handlers ride in NAME ORDER, which is what
    /// makes two messages the same bytes and readably diffable in review.
    func testEveryNodeWritesItsPropertiesInNameOrder() {
        let names = WireNames()

        for message in encoded() {
            let decoded = WireProbe.decodeMessage(message.bytes, names: names)

            walk(decoded.root) { node in
                XCTAssertEqual(
                    node.props.map(\.key), node.props.map(\.key).sorted(),
                    "\(node.type) wrote its properties out of order in \(message.name)")

                XCTAssertEqual(
                    node.events.map(\.name), node.events.map(\.name).sorted(),
                    "\(node.type) wrote its handlers out of order in \(message.name)")

                // The other three name-keyed fields, for the same reason: each
                // is written from a Dictionary, and Swift salts a Dictionary
                // with its own storage address.
                XCTAssertEqual(
                    node.transitions.map(\.property), node.transitions.map(\.property).sorted(),
                    "\(node.type) wrote its motions out of order in \(message.name)")

                XCTAssertEqual(
                    node.cleared, node.cleared.sorted(),
                    "\(node.type) wrote its cleared properties out of order in \(message.name)")

                XCTAssertEqual(
                    (node.driven ?? []).map(\.property), (node.driven ?? []).map(\.property).sorted(),
                    "\(node.type) wrote its driven properties out of order in \(message.name)")
            }
        }
    }

    /// TWO motions on ONE element ride in name order - the case the session
    /// never reaches, and the one the sort exists for: a Dictionary with a
    /// single entry is sorted whatever the comparator does.
    func testTwoMotionsOnOneElementRideInNameOrder() {
        let differ = Differ()
        let dictionary = WireDictionary()

        func panel(_ opacity: Double, _ colour: String) -> Node {
            Border { Label("x") }
                .opacity(opacity)
                .background(Color(colour))
                .id("panel")
                .body
        }

        let first = differ.reconcile(nil, with: panel(1, "#000000"), styles: nil)
        let opening = Wire.encode(first.patch, generation: 1, dictionary: dictionary)

        let second = differ.reconcile(first.node, with: panel(0.25, "#FFFFFF"), styles: nil)
        let bytes = Wire.encode(second.patch, generation: 2, dictionary: dictionary)

        let names = WireNames()
        _ = WireProbe.decodeMessage(opening, names: names)

        var motions: [[String]] = []

        walk(WireProbe.decodeMessage(bytes, names: names).root) { node in
            if !node.transitions.isEmpty {
                motions.append(node.transitions.map(\.property))
            }
        }

        let travelling = motions.first { $0.count >= 2 }

        XCTAssertNotNil(
            travelling,
            "no element carried two motions, so the order this test is about was never written")

        XCTAssertEqual(
            travelling, travelling?.sorted(),
            "two motions on one element came out in Dictionary order, which Swift salts per storage")
    }

    /// A name is announced ONCE in a session, by the first message that uses
    /// it, and every later message speaks the number. Announcing one LATE -
    /// after a message already used the number - is unreadable, and is what
    /// `WireNames.resolve` traps on while `testEveryNodeWritesItsPropertiesInNameOrder`
    /// decodes.
    func testEveryNameIsAnnouncedExactlyOnceInASession() {
        var announced: [Int: String] = [:]
        var order: [Int] = []

        for message in encoded() {
            for entry in Self.announcements(in: message.bytes) {
                XCTAssertNil(
                    announced[entry.id],
                    "#\(entry.id) was announced again in \(message.name), as \(entry.name)")

                announced[entry.id] = entry.name
                order.append(entry.id)
            }
        }

        XCTAssertEqual(
            order, Array(1...order.count),
            "the numbers are handed out one after another, so a gap is a name lost")

        XCTAssertEqual(
            Set(announced.values).count, announced.count,
            "and no name was numbered twice under different ids")
    }

    /// The message head, read on its own by a second spelling of the layout,
    /// so a writer's mistake is a failure instead of two halves agreeing on it.
    private static func announcements(in bytes: [UInt8]) -> [(id: Int, name: String)] {
        var at = 0

        func u8() -> Int {
            defer { at += 1 }
            return Int(bytes[at])
        }

        func u16() -> Int { u8() | u8() << 8 }

        func u32() -> Int { u16() | u16() << 16 }

        XCTAssertEqual(u8(), Int(Wire.version), "the envelope starts with the version")
        _ = u8()                            // complete
        _ = u32()                           // generation

        return (0..<u16()).map { _ in
            let id = u16()
            let length = u32()
            let name = String(decoding: bytes[at..<(at + length)], as: UTF8.self)
            at += length
            return (id: id, name: name)
        }
    }

    /// Every node in a decoded message, itself included.
    private func walk(_ node: WireProbe.WireNode, _ body: (WireProbe.WireNode) -> Void) {
        body(node)

        for child in node.children {
            walk(child, body)
        }
    }
}
