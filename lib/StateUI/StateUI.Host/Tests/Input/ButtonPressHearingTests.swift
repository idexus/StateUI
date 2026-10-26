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

    /// A FINGER'S PRESS IN A SCROLLER LIGHTS THE ROW ONLY ONCE IT HAS STOOD A MOMENT, as it may still begin a scroll:
    /// a scroll taking it before lights nothing; a mouse's press lights the row at once.
    func testAFingersPressInAScrollerWaitsToLightTheRow() throws {
        let (runtime, row) = try running(ScrolledRowApplication())
        let now = runtime.clock.now()

        row.hear(.press(.began, at: Point(50, 20), size: size, byFinger: true), in: runtime)
        settle(runtime)
        XCTAssertEqual(states, [], "not lit at once")
        runtime.handPace.pace(now: now + ButtonPress.scrollerWait, in: runtime)
        settle(runtime)
        XCTAssertEqual(states, ["Pressed"], "lit once it stood")
        row.hear(.press(.ended, at: Point(50, 20), size: size, byFinger: true), in: runtime)
        settle(runtime)
        XCTAssertEqual(taps, 1)

        states = []
        row.hear(.press(.began, at: Point(50, 20), size: size, byFinger: true), in: runtime)
        row.hear(.press(.cancelled, at: Point(50, 20), size: size, byFinger: true), in: runtime)
        runtime.handPace.pace(now: now + 1, in: runtime)
        settle(runtime)
        XCTAssertEqual(states, [], "a scroll took it before it lit")

        row.hear(.press(.began, at: Point(50, 20), size: size, byFinger: false), in: runtime)
        settle(runtime)
        XCTAssertEqual(states, ["Pressed"], "a mouse's press lights at once")
    }

    private func settle(_ runtime: HostRuntime) {
        for _ in 0..<5 { runtime.pump.turn() }
    }

    private func running(_ application: some Application = RowApplication()) throws -> (HostRuntime, MountedElement) {
        (taps, held, states) = (0, 0, [])
        stateUIUseApp(application)
        let runtime = HostRuntime.still()
        runtime.connectWindow()
        runtime.pump.turn()
        return (runtime, try XCTUnwrap(runtime.tree.root?.first(id: .manual("row"))))
    }
}

@MainActor private var taps = 0
@MainActor private var held = 0
@MainActor private var states: [String] = []

/// The row standing in a scroller.
private struct ScrolledRowApplication: Application {
    var body: some Scene {
        WindowGroup {
            ScrollView {
                ZStack { Text("Row") }
                    .onTapped { @MainActor in taps += 1 }
                    .visualState(.pressed) { $0.background(.green) }
                    .onVisualStateChanged { @MainActor state in states.append(state.name) }
                    .id("row")
            }
        }
    }
}

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
