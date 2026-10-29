// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
import XCTest

/// A pinch a view hears, as every host tells it: the platform's steps reach the handler as the spread since the
/// pinch began.
@MainActor
final class PinchHearingTests: XCTestCase {
    /// A PINCH IS TOLD FROM ITS START: steps of 1.2 and 1.5 reach the handler as 1.2 and 1.8, the end as the whole,
    /// and the next pinch starts again at 1.
    func testAPinchIsToldFromItsStart() throws {
        let (runtime, box) = try running()
        let middle = Point(0.5, 0.5)

        let steps: [(GesturePhase, Double)] = [(.began, 1), (.changed, 1.2), (.changed, 1.5), (.ended, 1), (.began, 1),
                                               (.changed, 2)]
        for (phase, scale) in steps { box.hear(.pinch(phase, scale: scale, at: middle), in: runtime) }
        runtime.pump.turn()

        XCTAssertEqual(told.map(\.scale), [1, 1.2, 1.8, 1.8, 1, 2])
    }

    /// A PINCH WHOSE BEGINNING NO PLATFORM TOLD BEGINS ITSELF: a trackpad's magnification may arrive as a step and an
    /// end alone; the handler hears it begin first, so the size it held then is known.
    func testAPinchWhoseBeginningNoPlatformToldBeginsItself() throws {
        let (runtime, box) = try running()
        let middle = Point(0.5, 0.5)

        for (phase, scale) in [(GesturePhase.changed, 1.02), (.ended, 1), (.changed, 1.5)] {
            box.hear(.pinch(phase, scale: scale, at: middle), in: runtime)
        }
        runtime.pump.turn()

        XCTAssertEqual(told.map(\.phase), [.began, .changed, .ended, .began, .changed])
        XCTAssertEqual(told.map(\.scale), [1, 1.02, 1.02, 1, 1.5])
    }

    /// A runtime of the page and its box.
    private func running() throws -> (HostRuntime, MountedElement) {
        told = []
        stateUIUseApp(PinchApplication())
        let runtime = HostRuntime(
            clock: PinchClock(), reducesMotion: { false }, makeNative: { _ in NoView() }, log: { _ in })
        runtime.connectWindow()
        runtime.pump.turn()
        return (runtime, try XCTUnwrap(runtime.tree.root?.first(id: .manual("box"))))
    }
}

/// What the box's pinch told, in order, its scale to a thousandth.
@MainActor private var told: [(phase: GesturePhase, scale: Double)] = []

/// A clock the test never winds.
@MainActor
private final class PinchClock: FrameClock {
    lazy var now: () -> Double = { 0 }
    var held = false
    var onFrame: ((Double) -> Void)?
}

private struct PinchApplication: Application {
    var body: some Scene {
        WindowGroup {
            Rectangle()
                .width(100)
                .height(100)
                .onPinchUpdated { pinch in told.append((pinch.phase, (pinch.scale * 1_000).rounded() / 1_000)) }
                .id("box")
        }
    }
}
