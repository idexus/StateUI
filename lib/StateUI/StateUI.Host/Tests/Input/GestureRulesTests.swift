// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
import XCTest

/// What a view listens for of the user's input, and a pinch's steps, the same on every host.
@MainActor
final class GestureRulesTests: XCTestCase {
    /// A view listens for what its handlers and channels ask: taps for a tap handler, a press dragged for a pan's
    /// channel - one pointer's alone - the pointer and a pinch for theirs, nothing for none.
    func testAViewListensForWhatItsHandlersAsk() throws {
        let runtime = HostRuntime.still()
        func view(_ id: String, _ properties: [Prop: HostValue], _ events: [Event: Int32]) -> HostPatch {
            var view = HostPatch(id: .manual(id), type: .vStack)
            view.properties = properties
            view.events = .replace(events)
            return view
        }
        var root = HostPatch(id: .manual("root"), type: .vStack)
        root.children = .arranged([
            view("tapped", [:], [.tapped: 1, .pinchUpdated: 2]),
            view("panned", [.panXChannel: .number(7)], [.pointerMoved: 3]),
            view("twoFingers", [.panXChannel: .number(7), .panTouchCount: .number(2)], [:]),
            view("deaf", [:], [:]),
        ])
        runtime.tree.apply(root, complete: true)
        func hearing(_ id: String) throws -> Hearing { try XCTUnwrap(runtime.tree.root?.first(id: .manual(id))).hearing }

        XCTAssertEqual(try hearing("tapped"), [.taps, .pinches])
        XCTAssertEqual(try hearing("panned"), [.drags, .pointer])
        XCTAssertEqual(try hearing("twoFingers"), [], "a pan of more than one pointer is not recognized")
        XCTAssertEqual(try hearing("deaf"), [])
    }

    /// Each step of a pinch is its scale since the last, 1 as it begins and ends; where it stands is a share of the
    /// view, its middle where the toolkit says no point.
    func testAPinchSaysEachStepsScaleSinceTheLast() {
        var pinch = PinchStep()
        XCTAssertEqual(pinch.step(.started, scale: 1), 1)
        XCTAssertEqual(pinch.step(.running, scale: 2), 2)
        XCTAssertEqual(pinch.step(.running, scale: 3), 1.5)
        XCTAssertEqual(pinch.step(.completed, scale: 3), 1)
        XCTAssertEqual(PinchStep.share(of: Point(x: 50, y: 10), width: 100, height: 40), Point(x: 0.5, y: 0.25))
        XCTAssertEqual(PinchStep.share(of: nil, width: 100, height: 40), Point(x: 0.5, y: 0.5))
    }
}
