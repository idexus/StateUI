// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
@testable import StateUIGTK
import StateUIConformance
import XCTest

/// A stack's children travel to the places a patch gives them; one that joins fades in, one hidden fades out first.
final class GTKLayoutMotionTests: XCTestCase {
    /// A vertical stack of 100 x 40 labels in `order`, travelling on a 200 ms linear law; `hidden` fade out in 100 ms.
    private static func stack(_ order: [String], hidden: Set<String> = []) -> HostPatch {
        var stack = HostPatch(id: .manual("stack"), type: .vStack)
        stack.motion = HostLayoutMotion(motion: .eased(200, .linear), lanes: .all)
        stack.children = .arranged(order.map { name in
            var row = HostPatch(id: .manual(name), type: .label)
            row.properties = [.text: .string(name), .width: .number(100), .height: .number(40)]
            row.properties[.isVisible] = .bool(!hidden.contains(name))
            row.motion = HostLayoutMotion(motion: .eased(100, .linear), lanes: .all)
            return row
        })
        return stack
    }

    func testAChildAPatchMovesTravelsToItsNewPlace() throws {
        try onUIThread {
            let clock = TestClock()
            let host = GTKRenderer.bare(clock: clock)
            host.apply(Self.stack(["a", "b"]))
            let moved = try XCTUnwrap(host.view(id: .manual("b")))
            host.layOut()
            XCTAssertEqual(moved.frame.y, 40, "the first arrangement is an arrival")

            host.apply(Self.stack(["b", "a"]))
            host.layOut()
            XCTAssertEqual(moved.frame.y, 40, "a child starts from where it stood")

            clock.now = 100
            host.frame()
            XCTAssertEqual(moved.frame.y, 20, "halfway through a linear 200 ms animation")

            clock.now = 200
            host.frame()
            XCTAssertEqual(moved.frame.y, 0, "and it lands exactly")
            XCTAssertFalse(host.runtime.animator.isMoving)
        }
    }

    func testAChildThatJoinsAStandingStackFadesIn() throws {
        try onUIThread {
            let clock = TestClock()
            let host = GTKRenderer.bare(clock: clock)
            host.apply(Self.stack(["a"]))
            host.layOut()

            host.apply(Self.stack(["a", "b"]))
            host.layOut()
            let joined = try XCTUnwrap(host.view(id: .manual("b")))
            XCTAssertEqual(joined.drawnOpacity, 0, accuracy: GTKView.opacityStep)

            clock.now = 100
            host.frame()
            XCTAssertEqual(joined.drawnOpacity, 0.5, accuracy: GTKView.opacityStep)

            clock.now = 200
            host.frame()
            XCTAssertEqual(joined.drawnOpacity, 1, accuracy: GTKView.opacityStep)
        }
    }

    func testWithLessMotionEveryChildArrives() throws {
        try onUIThread {
            let host = GTKRenderer.bare(clock: TestClock(), reducesMotion: true)
            host.apply(Self.stack(["a", "b"]))
            host.layOut()

            host.apply(Self.stack(["b", "a"]))
            host.layOut()

            XCTAssertEqual(try XCTUnwrap(host.view(id: .manual("b"))).frame.y, 0)
            XCTAssertFalse(host.runtime.animator.isMoving)
        }
    }

    /// The hidden row fades where it stands, keeping its room; once it has gone, the row below travels up.
    func testAStackClosesOverARowOnceItsFadeLands() throws {
        try onUIThread {
            let clock = TestClock()
            let host = GTKRenderer.bare(clock: clock)
            host.apply(Self.stack(["first", "second"]))
            let first = try XCTUnwrap(host.view(id: .manual("first")))
            let second = try XCTUnwrap(host.view(id: .manual("second")))
            host.layOut()
            XCTAssertEqual(second.frame.y, 40)

            host.apply(Self.stack(["first", "second"], hidden: ["first"]))
            host.layOut()
            XCTAssertTrue(first.isShown, "still there, on its way out")

            clock.now = 50
            host.frame()
            XCTAssertEqual(first.drawnOpacity, 0.5, accuracy: GTKView.opacityStep)
            XCTAssertEqual(second.frame.y, 40)

            clock.now = 100
            host.frame()
            XCTAssertFalse(first.isShown, "gone when the fade landed")
            XCTAssertEqual(first.drawnOpacity, 1, accuracy: GTKView.opacityStep, "at the opacity the tree describes")
            XCTAssertEqual(second.frame.y, 40, "the row below starts once it has gone")

            clock.now = 200
            host.frame()
            XCTAssertEqual(second.frame.y, 20, "and travels into its place")

            clock.now = 300
            host.frame()
            XCTAssertEqual(second.frame.y, 0)
        }
    }

    func testARowShownAgainMidFadeComesBackFromWhereItStands() throws {
        try onUIThread {
            let clock = TestClock()
            let host = GTKRenderer.bare(clock: clock)
            host.apply(Self.stack(["first", "second"]))
            let first = try XCTUnwrap(host.view(id: .manual("first")))
            host.layOut()

            host.apply(Self.stack(["first", "second"], hidden: ["first"]))
            clock.now = 50
            host.frame()
            host.apply(Self.stack(["first", "second"]))
            XCTAssertEqual(first.drawnOpacity, 0.5, accuracy: GTKView.opacityStep, "up again from where the fade reached")

            clock.now = 150
            host.frame()
            XCTAssertEqual(first.drawnOpacity, 1, accuracy: GTKView.opacityStep)
            XCTAssertTrue(first.isShown, "and never gone")
        }
    }
}
