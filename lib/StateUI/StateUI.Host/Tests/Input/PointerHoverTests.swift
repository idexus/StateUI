// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
import XCTest

/// The pointer as every host takes it: a mouse or a pen comes over a view, moves over it and leaves it; a finger
/// presses and lets go, and hovers over nothing - as a platform made for the finger tells it.
@MainActor
final class PointerHoverTests: XCTestCase {
    func testAFingerHoversOverNothing() throws {
        let (runtime, view) = try running()

        view.hear(.pointer(.pointerEntered, Point(4, 4), byFinger: true), in: runtime)
        view.hear(.pointer(.pointerMoved, Point(6, 4), byFinger: true), in: runtime)
        view.hear(.pointer(.pointerPressed, Point(6, 4), byFinger: true), in: runtime)
        view.hear(.pointer(.pointerReleased, Point(6, 40), byFinger: true), in: runtime)
        view.hear(.pointer(.pointerExited, Point(6, 40), byFinger: true), in: runtime)
        for _ in 0..<5 { runtime.pump.turn() }

        XCTAssertEqual(heard, ["pressed", "released"], "a finger presses and lets go, and hovers over nothing")
    }

    func testAMouseComesOverMovesAndLeaves() throws {
        let (runtime, view) = try running()

        view.hear(.pointer(.pointerEntered, Point(4, 4)), in: runtime)
        view.hear(.pointer(.pointerMoved, Point(6, 4)), in: runtime)
        view.hear(.pointer(.pointerExited, Point(6, 40)), in: runtime)
        for _ in 0..<5 { runtime.pump.turn() }

        XCTAssertEqual(heard, ["entered", "moved", "exited"])
    }

    private func running() throws -> (HostRuntime, MountedElement) {
        heard = []
        stateUIUseApp(PointerApplication())
        let runtime = HostRuntime.still()
        runtime.connectWindow()
        runtime.pump.turn()
        return (runtime, try XCTUnwrap(runtime.tree.root?.first(id: .manual("view"))))
    }
}

/// What the view heard of the pointer, in order.
@MainActor private var heard: [String] = []

private struct PointerApplication: Application {
    var body: some Scene {
        WindowGroup {
            Text("Over")
                .onPointerEntered { @MainActor in heard.append("entered") }
                .onPointerMoved { @MainActor _ in heard.append("moved") }
                .onPointerExited { @MainActor in heard.append("exited") }
                .onPointerPressed { @MainActor _ in heard.append("pressed") }
                .onPointerReleased { @MainActor _ in heard.append("released") }
                .id("view")
        }
    }
}
