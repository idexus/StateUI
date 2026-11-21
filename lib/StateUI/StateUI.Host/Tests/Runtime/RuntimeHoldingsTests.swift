// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
import XCTest

/// What a runtime holds returns to what it held: the core and the host layer together, through many rounds of a
/// view leaving by its exit, coming back as it leaves, leaving again and landing, a window closed under it.
/// Design: docs/design/host/benchmarks.md#what-a-runtime-holds
@MainActor
final class RuntimeHoldingsTests: XCTestCase {
    /// The board, what the runtime held half way through the last round's first exit, and every change made.
    private lazy var bench = BoardBench()
    private var midway: RuntimeHoldings?
    private var changes: [PresentationChange] = []

    /// One round: the card leaves under a change as the line sets out, comes back half way, leaves again under a
    /// second change; then the line goes home and the card returns. `closing` closes the window as the first exit
    /// runs, and a window made anew shows the board again.
    private func round(closing: Bool) throws {
        let (shown, shift) = (bench.shown, bench.shift)
        changes.append(try bench.scope.presentationChange {
            shown.wrappedValue = false
            shift.wrappedValue = 100
        })
        bench.step(100)
        midway = bench.runtime?.holdings
        if closing {
            bench.close()
            bench.step(16)
            shown.wrappedValue = true
            shift.projectedValue.journey.snap(to: 0)
            bench.open()
            return bench.rest()
        }
        shown.wrappedValue = true
        bench.step(50)
        changes.append(try bench.scope.presentationChange { shown.wrappedValue = false })
        bench.step(16)
        shift.wrappedValue = 0
        bench.rest()
        shown.wrappedValue = true
        bench.rest()
    }

    /// A THOUSAND ROUNDS LEAVE NOTHING HELD: after each, every count stands where it stood after the first - the
    /// tree's indexes, the views kept leaving, the animations, the channels, the changes waiting, the hands, the
    /// clock, the core's elements, runs and movements, the native halves alive - every change was answered, and
    /// the runtime let go lets every half go.
    func testAThousandRoundsLeaveNothingHeld() throws {
        try round(closing: false)
        let base = bench.held
        let (rest, midway) = (try XCTUnwrap(bench.runtime?.holdings), try XCTUnwrap(midway))
        XCTAssertFalse(rest.holdsClock, "at rest, nothing holds the clock")
        XCTAssertEqual([rest.leaving, rest.animations, rest.changes], [0, 0, 0], "\(rest)")
        XCTAssertTrue(midway.holdsClock, "half way, the round moves")
        XCTAssertEqual(midway.leaving, 1, "the card is kept as it leaves")
        XCTAssertGreaterThan(midway.animations, 1, "the exit and the line's state travel")
        XCTAssertGreaterThan(midway.changes, 0, "and the change waits for them")

        for number in 1...1000 {
            try round(closing: number % 50 == 0)
            guard bench.held == base else {
                return XCTFail("round \(number) left something held: \(bench.held), where \(base) stood")
            }
        }
        XCTAssertEqual(changes.filter { $0.answered.settled == nil }.count, 0, "every change was answered")
        XCTAssertTrue(
            changes.contains { $0.answered.settled == .settled }
                && changes.contains { $0.answered.settled != .settled },
            "some rested and some were interrupted: the rounds moved something")

        bench.runtime?.ending()
        bench.runtime = nil
        XCTAssertEqual(bench.halves, 0, "a runtime let go keeps no half")
    }
}
