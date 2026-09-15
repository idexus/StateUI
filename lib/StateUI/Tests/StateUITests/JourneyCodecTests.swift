// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import XCTest
@testable import StateUI

/// The lanes a walked value crosses in, and the batch every value crosses in,
/// held for every runtime that reads the Wire: `journey-lanes.txt` and
/// `state-batches.txt` are written from this side's own `JourneyLanes` and
/// `StateBatch`, and the MAUI host's `JourneyCodecTests.cs` reads both.
final class JourneyCodecTests: XCTestCase {
    /// Every journey in the table lies in the lanes the fixture holds.
    func testTheFixtureHoldsTheLanesThisSideWrites() throws {
        try Self.check("journey-lanes.txt", Self.journeyTable())
    }

    /// Every batch in the table lies in the bytes the fixture holds.
    func testTheFixtureHoldsTheBatchesThisSideWrites() throws {
        try Self.check("state-batches.txt", Self.batchTable())
    }

    /// A batch reads back as the writes it was made of.
    func testABatchReadsBackAsItsEntries() {
        for writes in Self.batches {
            let (read, complete) = StateBatch.decode(StateBatch.encode(writes))

            XCTAssertTrue(complete)
            XCTAssertEqual(read, writes)
        }
    }

    /// A batch cut short keeps every write before the cut, and says it was cut.
    func testABatchCutShortKeepsWhatCameBeforeTheCut() throws {
        let writes = try XCTUnwrap(Self.batches.last)
        let (read, complete) = StateBatch.decode(Array(StateBatch.encode(writes).dropLast()))

        XCTAssertFalse(complete)
        XCTAssertEqual(read, Array(writes.dropLast()))
    }

    // MARK: - The journeys

    private static func journeyTable() -> String {
        var lines = [
            "# Walked values as they lie in their lanes: where the value is, where it is",
            "# going, how fast (per second), the law's three lanes, the waiter and the",
            "# stops. Written by JourneyCodecTests.swift from JourneyLanes with",
            "# STATEUI_UPDATE_FIXTURES=1; read by JourneyCodecTests.cs.",
            "#",
            "# journey <width> value <lanes> destination <lanes> velocity <lanes>",
            "#   law <none|inherited|eased|spring|custom> <milliseconds> <curve|damping>",
            "#   waiter <id> stops <count> lanes <lanes>",
        ]

        lines.append(journey(
            0.25, to: 1.0, speed: 0.0, .eased(250, .sineInOut), waiter: -3))
        lines.append(journey(
            1.0, to: 1.0, speed: 0.0, .inherited, stops: 2))
        lines.append(journey(
            0.5, to: 0.0, speed: -2.5, .spring(response: 400, damping: 0.6), stops: 1))
        lines.append(journey(
            point(10, 20), to: point(30, -40), speed: point(5, -5), .none))
        lines.append(journey(
            rect(0, 0, 100, 50), to: rect(10, 20, 200, 80), speed: rect(0, 0, 0, 0),
            .custom, waiter: -7))
        lines.append(journey(
            rect(1, 2, 3, 4), to: rect(4, 3, 2, 1), speed: rect(-1, 1, -1, 1),
            .spring(response: 250, damping: 1), waiter: -1, stops: 5))

        return lines.joined(separator: "\n") + "\n"
    }

    /// One journey's line: its parts as this side holds them, and its lanes.
    private static func journey<Value: Walked>(
        _ value: Value,
        to destination: Value,
        speed velocity: Value,
        _ motion: Motion,
        waiter completion: Double = 0,
        stops stopped: Double = 0
    ) -> String {
        var lanes = JourneyLanes(value, motion: motion)
        lanes.destination = destination
        lanes.velocity = velocity
        lanes.completion = completion
        lanes.stopped = stopped

        return "journey \(Value.lanes)"
            + " value \(list(numbers(value)))"
            + " destination \(list(numbers(destination)))"
            + " velocity \(list(numbers(velocity)))"
            + " law \(law(motion))"
            + " waiter \(completion) stops \(stopped)"
            + " lanes \(list(numbers(lanes)))"
    }

    /// A law as the table names it, from the motion itself.
    private static func law(_ motion: Motion) -> String {
        if motion.isInherited { return "inherited 0 0.0" }
        if motion.isCustom { return "custom 0 0.0" }
        if motion.law == .eased && motion.millis == 0 { return "none 0 0.0" }

        return motion.law == .spring
            ? "spring \(motion.millis) \(motion.factor)"
            : "eased \(motion.millis) \(Double(motion.curve.rawValue))"
    }

    private static func numbers<Value: StateValue>(_ value: Value) -> [Double] {
        guard case .lanes(let lanes) = value.carried else { return [] }
        return lanes
    }

    private static func point(_ x: Double, _ y: Double) -> Point {
        Point(carried: .lanes([x, y]))!
    }

    private static func rect(_ x: Double, _ y: Double, _ width: Double, _ height: Double) -> Rect {
        Rect(carried: .lanes([x, y, width, height]))!
    }

    // MARK: - The batches

    /// Batches of every shape a crossing has: none, one, several, a number past
    /// sixteen bits, a mask past thirty-two, text, and a value with no bytes.
    private static let batches: [[StateBatch.Write]] = [
        [],
        [write(1, mask: 0b1, .lanes([0.5]))],
        [
            write(2, mask: 0b111, JourneyLanes(0.25, motion: .eased(250, .sineInOut)).carried),
            write(9, mask: 1, .text("héllo")),
        ],
        [
            write(3, mask: (1 << 40) | 1, .lanes([10, 20, 200, 80])),
            write(70_000, mask: ~0, .lanes([1, -2])),
            write(12, mask: 0, .text("")),
        ],
    ]

    private static func write(_ number: Int32, mask: UInt64, _ carried: StateCarried) -> StateBatch.Write {
        StateBatch.Write(number: number, mask: mask, bytes: StateImage.bytes(of: carried))
    }

    private static func batchTable() -> String {
        var lines = [
            "# Batches of state values as they cross a host's boundary, both ways:",
            "# [count: U16], then per write [number: I32][mask: U64][length: U32] and the",
            "# bytes, little-endian. Written by JourneyCodecTests.swift from StateBatch",
            "# with STATEUI_UPDATE_FIXTURES=1; read and written by JourneyCodecTests.cs.",
            "#",
            "# batch <bytes>",
            "# write <number> <mask> <bytes, or - for none>",
            "# cut <the last batch less its last byte> keeps <writes>",
        ]

        for writes in batches {
            lines.append("batch \(hex(StateBatch.encode(writes)))")

            for write in writes {
                let bytes = write.bytes.isEmpty ? "-" : hex(write.bytes)
                lines.append("write \(write.number) \(hex(mask: write.mask)) \(bytes)")
            }
        }

        if let last = batches.last {
            let cut = Array(StateBatch.encode(last).dropLast())
            let kept = StateBatch.decode(cut).writes.count
            lines.append("cut \(hex(cut)) keeps \(kept)")
        }

        return lines.joined(separator: "\n") + "\n"
    }

    private static func hex(_ bytes: [UInt8]) -> String {
        bytes.map { byte in
            let digits = String(byte, radix: 16)
            return byte < 16 ? "0" + digits : digits
        }.joined()
    }

    private static func hex(mask: UInt64) -> String {
        let digits = String(mask, radix: 16)
        return String(repeating: "0", count: 16 - digits.count) + digits
    }

    // MARK: - The check

    private static func list(_ values: [Double]) -> String {
        values.map { "\($0)" }.joined(separator: ",")
    }

    private static func check(_ name: String, _ written: String) throws {
        let fixture = Fixtures.directory.appendingPathComponent(name)

        if Fixtures.updating {
            try written.write(to: fixture, atomically: true, encoding: .utf8)
            return
        }

        let expected = try String(contentsOf: fixture, encoding: .utf8)

        XCTAssertEqual(
            expected, written,
            """
            \(name) no longer holds what this side writes. If the layout changed \
            on purpose, run the tests again with STATEUI_UPDATE_FIXTURES=1 and \
            read the diff of \(name).
            """)
    }
}
