// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// What a host across the Wire realizes, told to the core through the export:
// the bytes a host writes, fixed by a fixture and its sidecar, read into the
// same knowledge a Swift host's registry gives.

import XCTest
@_spi(Host) @testable import StateUI

final class RealizationWireTests: XCTestCase {
    override func tearDown() {
        StateUIHost.setRealization(HostRealization())
        super.tearDown()
    }

    /// A realization crosses and reads back whole - elements and members
    /// alike.
    func testARealizationReadsBackAsItWasWritten() {
        XCTAssertEqual(Wire.decodeRealization(Wire.encodeRealization(Self.sample)), Self.sample)
    }

    /// The bytes are the same whatever order the realization was gathered
    /// in: sets are written sorted, the wire's rule.
    func testTheSameRealizationIsTheSameBytes() {
        let reversed = HostRealization(
            elements: Set(Self.sample.elements.reversed()),
            members: Set(Self.sample.members.reversed()))

        XCTAssertEqual(Wire.encodeRealization(reversed), Wire.encodeRealization(Self.sample))
    }

    /// What the export reads is what the core then answers from.
    func testTheExportTellsTheCoreWhatTheHostRealizes() {
        XCTAssertEqual(send(Wire.encodeRealization(Self.sample)), 0)

        XCTAssertTrue(StateUIHost.realizes(LabelContract.self))
        XCTAssertTrue(StateUIHost.realizes(LabelContract.maximumLines))
        XCTAssertFalse(StateUIHost.realizes(ButtonContract.self))
    }

    /// A buffer that will not read is refused whole with -1 - version skew,
    /// said rather than half read - and the core keeps what it knew.
    func testAnUnreadableBufferIsRefusedAndChangesNothing() {
        XCTAssertEqual(send(Wire.encodeRealization(Self.sample)), 0)

        XCTAssertEqual(send([99, 1, 2, 3]), -1)
        XCTAssertEqual(send(Array(Wire.encodeRealization(Self.sample).dropLast())), -1)

        XCTAssertTrue(StateUIHost.realizes(LabelContract.self))
    }

    /// The layout a host writes, fixed among the buffers a host writes -
    /// fixtures/payloads, where C#'s writer is held to the same bytes.
    func testTheRealizationCrossesAsItsFixtureSays() throws {
        let bytes = Wire.encodeRealization(Self.sample)

        try Fixtures.check(bytes, sidecar: Self.sidecar(of: Self.sample), against: "payloads/realization")
    }

    // MARK: - Support

    /// A host realizing a label, its maximum lines, the font size it wears and
    /// the gallery's traffic light with the event it raises.
    private static let sample = HostRealization(
        elements: ["Label", "Gallery.TrafficLight"],
        members: [
            HostRealizedMember(element: "Label", owner: "Label", member: "maximumLines"),
            HostRealizedMember(element: "Label", owner: "FontElement", member: "fontSize"),
            HostRealizedMember(element: "Gallery.TrafficLight", owner: "Gallery.TrafficLight", member: "lampTapped"),
        ])

    /// The readable half: one line per element, its members under it.
    private static func sidecar(of realization: HostRealization) -> String {
        var lines: [String] = []

        for element in realization.elements.sorted() {
            lines.append(element)

            for member in realization.members.filter({ $0.element == element })
                .sorted(by: { ($0.owner, $0.member) < ($1.owner, $1.member) }) {
                lines.append("  \(member.owner).\(member.member)")
            }
        }

        return lines.joined(separator: "\n") + "\n"
    }

    /// Sends a buffer through the real export and answers what it answered.
    private func send(_ bytes: [UInt8]) -> Int32 {
        bytes.withUnsafeBufferPointer { buffer in
            stateui_set_realization_wire(buffer.baseAddress, Int32(buffer.count))
        }
    }
}
