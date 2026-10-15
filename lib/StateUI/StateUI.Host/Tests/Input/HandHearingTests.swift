// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
import XCTest

/// A layout a hand moves, as every host hears it: the hand and the wheel said as the toolkit tells them reach the
/// layout's run, a throw goes on to the target nearest its end, and a wheel is let go by a frame that finds it still.
@MainActor
final class HandHearingTests: XCTestCase {
    /// A LAYOUT A HAND MOVES HEARS THE HAND, and nothing else of it: the run moves with it, and let go with speed it
    /// travels on to the target nearest where the throw would end.
    func testALayoutAHandMovesHearsTheHand() throws {
        let (runtime, clock) = running()
        let ring = try ring(in: runtime)

        XCTAssertEqual(ring.hearing, [.hand])

        ring.hear(.hand(.began, moved: .zero, speed: nil), in: runtime)
        ring.hear(.hand(.changed, moved: Point(-140, 0), speed: nil), in: runtime)
        frames(runtime, clock, until: 32)
        XCTAssertEqual(handed.last ?? 0, 1.4, accuracy: 0.001, "the run where the hand holds it")

        // 1,000 points a second to the left is 10 cards a second: about a card and a third on.
        ring.hear(.hand(.ended, moved: .zero, speed: Point(-1_000, 0)), in: runtime)
        frames(runtime, clock, until: 6_000)
        XCTAssertEqual(handed.last ?? 0, 3, accuracy: 0.001, "the target nearest where the throw would end")
    }

    /// A WHEEL IS LET GO BY A FRAME THAT FINDS IT STILL: it tells no lift, so the runtime's frames pace it, and the
    /// run travels on to the nearest target.
    func testAWheelIsLetGoByAFrameThatFindsItStill() throws {
        let (runtime, clock) = running()
        let ring = try ring(in: runtime)

        ring.hear(.wheel(Point(-140, 0)), in: runtime)
        frames(runtime, clock, until: 64)
        XCTAssertTrue(runtime.handPace.isOpen, "a wheel moving is open")
        XCTAssertEqual(handed.last ?? 0, 1.4, accuracy: 0.001)

        frames(runtime, clock, until: 1_000)
        XCTAssertFalse(runtime.handPace.isOpen, "let go once it stood still")
        XCTAssertEqual(handed.last ?? 0, 1, accuracy: 0.001, "and the run on the nearest card")
    }

    /// Display frames until `end`, sixteen milliseconds apart, the clock standing at each.
    private func frames(_ runtime: HostRuntime, _ clock: HandClock, until end: Double) {
        while clock.time < end {
            clock.time += 16
            runtime.displayCycle.frame(now: clock.time)
            runtime.pump.turn()
        }
    }

    private func running() -> (HostRuntime, HandClock) {
        handed = []
        stateUIUseApp(HandApplication())
        let clock = HandClock()
        let runtime = HostRuntime(clock: clock, reducesMotion: { false }, makeNative: { _ in NoView() }, log: { _ in })
        runtime.connectWindow()
        runtime.pump.turn()
        try? ring(in: runtime).reportFrame([0, 0, 300, 200, 0, 0, 0, 0], in: runtime)
        frames(runtime, clock, until: 16)
        return (runtime, clock)
    }

    /// The page's layout, where the tree mounted it.
    private func ring(in runtime: HostRuntime) throws -> MountedElement {
        try XCTUnwrap(runtime.tree.root?.first(type: .layoutEngine))
    }
}

/// Where the run stood each time its arithmetic was handed the phase.
@MainActor private var handed: [Double] = []

/// A clock the test winds.
@MainActor
private final class HandClock: FrameClock {
    var time = 0.0
    lazy var now: () -> Double = { [unowned self] in time }
    var held = false
    var onFrame: ((Double) -> Void)?
}

private struct HandPage: View {
    @State private var turn = 0.0

    var body: some View {
        LayoutEngine([0, 1, 2, 3, 4]) { Text("\($0)") } placements: { _, phase in
            handed.append(phase)
            return (0..<5).map { _ in Placement(Rect(0, 0, 10, 10)) }
        }
        .phase($turn)
        .input(.scroll(.horizontal, pointsPerUnit: 100))
        .snapTargets([0, 1, 2, 3, 4])
        .motion(.eased(.milliseconds(200), .linear))
    }
}

private struct HandApplication: Application {
    var body: some Scene { WindowGroup { HandPage() } }
}
