// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
import XCTest

/// Whether the board below shows its card - its detail otherwise - and how far its line is moved.
@MainActor private let cardShown = State(wrappedValue: true)
@MainActor private let lineShift = State(wrappedValue: 0.0, motion: .eased(.milliseconds(200), curve: .linear))
@MainActor private let board = Aim(VStack.self)

/// A scope whose card and detail are tied by one key, each coming and going by a transition, over a line a state
/// the host carries moves.
private struct Board: View {
    var body: some View {
        VStack {
            Text("line").translationX(lineShift.projectedValue)
            if cardShown.wrappedValue {
                Text("card")
                    .transition(Transition(enter: .opacity, exit: .opacity.combined(with: .translation(y: 12))))
                    .sharedTransition("card")
                    .id(7)
            } else {
                Text("detail")
                    .transition(.symmetric(.opacity))
                    .sharedTransition("card")
            }
        }
        .transitionScope("board")
        .motion(.eased(.milliseconds(200), curve: .linear))
        .aim(board)
    }
}

private struct BoardApplication: Application {
    var body: some Scene { WindowGroup { Board() } }
}

/// What a runtime holds returns to what it held: the core and the host layer together, through many rounds of a
/// view leaving by its exit, coming back as it leaves, leaving again and landing, a window closed under it.
/// Design: docs/design/host/benchmarks.md#what-a-runtime-holds
@MainActor
final class RuntimeHoldingsTests: XCTestCase {
    /// A native half held weakly: alive only while something still keeps it.
    private final class Made {
        weak var view: NoView?
        init(_ view: NoView) { self.view = view }
    }

    /// A runtime showing the board on a clock wound by hand, every half it made, and what each change came to.
    @MainActor
    private final class Bench {
        let clock = WoundClock()
        var runtime: HostRuntime?
        var made: [Made] = []
        var changes: [PresentationChange] = []

        /// What the runtime held half way through the last round's first exit.
        var midway: RuntimeHoldings?

        init() {
            cardShown.wrappedValue = true
            lineShift.projectedValue.journey.snap(to: 0)
            BoardApplication.register()
            runtime = HostRuntime(clock: clock, reducesMotion: { false }, makeNative: { [unowned self] _ in
                let view = NoView()
                view.keepsExits = true
                view.animatesProperties = true
                made.append(Made(view))
                return view
            }, log: { _ in })
            runtime?.connectWindow()
            step(0)
        }

        /// A turn, `milliseconds` later, and the frame of that time.
        func step(_ milliseconds: Double) {
            clock.time += milliseconds
            runtime?.pump.turn()
            runtime?.displayCycle.frame(now: clock.time)
            runtime?.pump.turn()
        }

        /// Frames until everything that moves has landed and every layout window is over.
        func rest() { for _ in 0..<6 { step(250) } }

        /// One round: the card leaves under a change as the line sets out, comes back half way, leaves again under
        /// a second change; then the line goes home and the card returns. `closing` closes the window as the
        /// first exit runs, and a window made anew shows the board again.
        func round(closing: Bool) throws {
            changes.append(try board.presentationChange {
                cardShown.wrappedValue = false
                lineShift.wrappedValue = 100
            })
            step(100)
            midway = runtime?.holdings
            if closing, let window = runtime?.tree.root?.windows.first {
                runtime?.userClosed(window)
                step(16)
                cardShown.wrappedValue = true
                lineShift.projectedValue.journey.snap(to: 0)
                runtime?.connectWindow()
                return rest()
            }
            cardShown.wrappedValue = true
            step(50)
            changes.append(try board.presentationChange { cardShown.wrappedValue = false })
            step(16)
            lineShift.wrappedValue = 0
            rest()
            cardShown.wrappedValue = true
            rest()
        }

        /// What stands held: the runtime's own counts, and the core's elements, runs and movements.
        var held: String {
            let tally = HostBoundary.tally
            return "\(runtime?.holdings.description ?? "no runtime"); elements \(tally.alive), runs \(tally.runs), "
                + "movements \(MotionRun.open), halves \(made.filter { $0.view != nil }.count)"
        }
    }

    /// A THOUSAND ROUNDS LEAVE NOTHING HELD: after each, every count stands where it stood after the first - the
    /// tree's indexes, the views kept leaving, the animations, the channels, the changes waiting, the hands, the
    /// clock, the core's elements, runs and movements, the native halves alive - every change was answered, and
    /// the runtime let go lets every half go.
    func testAThousandRoundsLeaveNothingHeld() throws {
        let bench = Bench()
        try bench.round(closing: false)
        let base = bench.held
        let (rest, midway) = (try XCTUnwrap(bench.runtime?.holdings), try XCTUnwrap(bench.midway))
        XCTAssertFalse(rest.holdsClock, "at rest, nothing holds the clock")
        XCTAssertEqual([rest.leaving, rest.animations, rest.changes], [0, 0, 0], "\(rest)")
        XCTAssertTrue(midway.holdsClock, "half way, the round moves")
        XCTAssertEqual(midway.leaving, 1, "the card is kept as it leaves")
        XCTAssertGreaterThan(midway.animations, 2, "the exit, the entry and the line's state travel")
        XCTAssertGreaterThan(midway.changes, 0, "and the change waits for them")

        for round in 1...1000 {
            try bench.round(closing: round % 50 == 0)
            guard bench.held == base else {
                return XCTFail("round \(round) left something held: \(bench.held), where \(base) stood")
            }
        }
        XCTAssertEqual(bench.changes.filter { $0.answered.settled == nil }.count, 0, "every change was answered")
        XCTAssertTrue(
            bench.changes.contains { $0.answered.settled == .settled }
                && bench.changes.contains { $0.answered.settled != .settled },
            "some rested and some were interrupted: the rounds moved something")

        bench.runtime?.ending()
        bench.runtime = nil
        XCTAssertEqual(bench.made.filter { $0.view != nil }.count, 0, "a runtime let go keeps no half")
    }
}
