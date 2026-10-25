// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
import XCTest

/// A view that hears taps, pressed as a button on every host: its pressed state lit while the press stands over it,
/// a tap where the press lets go over it, none where it lets go away or a hold takes it.
@MainActor
final class ButtonPressHearingTests: XCTestCase {
    private let size = LayoutSize(width: 100, height: 40)

    func testAPressLetGoOverTheViewTapsAndLightsItWhileOver() throws {
        let (runtime, row) = try running()

        row.hear(.press(.began, at: Point(50, 20), size: size, byFinger: true), in: runtime)
        settle(runtime)
        XCTAssertEqual(states, ["Pressed"], "lit as it is pressed")
        row.hear(.press(.changed, at: Point(50, 90), size: size, byFinger: true), in: runtime)
        settle(runtime)
        row.hear(.press(.changed, at: Point(50, 30), size: size, byFinger: true), in: runtime)
        settle(runtime)
        row.hear(.press(.ended, at: Point(50, 30), size: size, byFinger: true), in: runtime)
        settle(runtime)

        XCTAssertEqual(states, ["Pressed", "Normal", "Pressed", "Normal"], "out as it leaves, lit as it comes back")
        XCTAssertEqual(taps, 1, "let go over the view: a tap")
    }

    func testAPressLetGoAwayTapsNothing() throws {
        let (runtime, row) = try running()

        row.hear(.press(.began, at: Point(50, 20), size: size, byFinger: true), in: runtime)
        row.hear(.press(.changed, at: Point(50, 90), size: size, byFinger: true), in: runtime)
        row.hear(.press(.ended, at: Point(50, 90), size: size, byFinger: true), in: runtime)
        settle(runtime)

        XCTAssertEqual(taps, 0)
        XCTAssertEqual(states.last, "Normal")
    }

    func testAHoldTakesThePress() throws {
        let (runtime, row) = try running()

        row.hear(.press(.began, at: Point(50, 20), size: size, byFinger: true), in: runtime)
        row.hear(.hold, in: runtime)
        row.hear(.press(.ended, at: Point(50, 20), size: size, byFinger: true), in: runtime)
        settle(runtime)

        XCTAssertEqual(taps, 0, "a held press is no tap")
        XCTAssertEqual(held, 1)
        XCTAssertEqual(states.last, "Normal")
    }

    private func settle(_ runtime: HostRuntime) {
        for _ in 0..<5 { runtime.pump.turn() }
    }

    private func running() throws -> (HostRuntime, MountedElement) {
        (taps, held, states) = (0, 0, [])
        stateUIUseApp(RowApplication())
        let runtime = HostRuntime.still()
        runtime.connectWindow()
        runtime.pump.turn()
        return (runtime, try XCTUnwrap(runtime.tree.root?.first(id: .manual("row"))))
    }
}

@MainActor private var taps = 0
@MainActor private var held = 0
@MainActor private var states: [String] = []

private struct RowApplication: Application {
    var body: some Scene {
        WindowGroup {
            ZStack { Text("Row") }
                .onTapped { @MainActor in taps += 1 }
                .onHeld { @MainActor in held += 1 }
                .visualState(.pressed) { $0.background(.green) }
                .onVisualStateChanged { @MainActor state in states.append(state.name) }
                .id("row")
        }
    }
}
