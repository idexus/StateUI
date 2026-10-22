// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
@testable import StateUIWinUI
@testable import StateUIWinUIDriver
import StateUIConformance
import XCTest

/// Words in a stack as wide as they are, which travels on a 400 ms linear law as they change.
private struct SaidPage: View {
    let open: State<Bool>

    var body: some View {
        VStack {
            VStack {
                Text(open.wrappedValue ? "The popover shows" : "The popover is closed").fontSize(13).id("said")
            }
            .horizontalAlignment(.start)
            .id("stack")
        }
        .motion(.eased(.milliseconds(400), .linear))
        .verticalAlignment(.start)
    }
}

/// A stack's children travel to the places a patch gives them; one that joins fades in, one hidden fades out first.
final class WinUILayoutMotionTests: XCTestCase {
    /// A vertical stack of 100 x 40 labels in `order`, traveling on a 200 ms linear law; `hidden` fade out in 100 ms.
    private static func stack(_ order: [String], hidden: Set<String> = []) -> HostPatch {
        var stack = HostPatch(id: .manual("stack"), type: .vStack)
        stack.motion = HostLayoutMotion(motion: .eased(.milliseconds(200), .linear), lanes: .all)
        stack.children = .arranged(order.map { name in
            var row = HostPatch(id: .manual(name), type: .text)
            row.properties = [.text: .string(name), .width: .number(100), .height: .number(40)]
            row.properties[.isVisible] = .bool(!hidden.contains(name))
            row.motion = HostLayoutMotion(motion: .eased(.milliseconds(100), .linear), lanes: .all)
            return row
        })
        return stack
    }

    /// A label filling a stack whose width travels lays its words out at the width the stack is bound for: the
    /// stack lays its children out there, its own place traveling around them - measured at both widths in one
    /// pass, the words broke onto a second line and back, and WinUI's layout never settled.
    func testALabelInAStackThatTravelsKeepsItsWordsOnOneLine() throws {
        try onUIThread {
            let clock = TestClock()
            let open = State(wrappedValue: true)
            let host = WinUIRenderer.running(clock: clock) { SaidPage(open: open) }
            let said = try XCTUnwrap(host.view(id: .manual("said")))
            let stack = try XCTUnwrap(host.view(id: .manual("stack")))
            let line = said.laidOutFrame.height

            open.wrappedValue = false
            host.runtime.pump.turn()
            host.layOut()
            var (heights, widths) = ([said.laidOutFrame.height], [stack.laidOutFrame.width])
            for now in stride(from: 50, through: 800, by: 50) {
                clock.now = Double(now)
                host.frame()
                heights.append(said.laidOutFrame.height)
                widths.append(stack.laidOutFrame.width)
            }

            XCTAssertTrue(widths.contains { $0 > widths[0] + 1 && $0 < widths[widths.count - 1] - 1 }, "\(widths)")
            XCTAssertEqual(heights.max() ?? 0, line, accuracy: 0.5, "one line all the way: \(heights)")
        }
    }

    func testAChildAPatchMovesTravelsToItsNewPlace() throws {
        try onUIThread {
            let clock = TestClock()
            let host = WinUIRenderer.bare(clock: clock)
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
            let host = WinUIRenderer.bare(clock: clock)
            host.apply(Self.stack(["a"]))
            host.layOut()

            host.apply(Self.stack(["a", "b"]))
            host.layOut()
            let joined = try XCTUnwrap(host.view(id: .manual("b")))
            XCTAssertEqual(joined.drawnOpacity, 0, accuracy: 1e-6)

            clock.now = 100
            host.frame()
            XCTAssertEqual(joined.drawnOpacity, 0.5, accuracy: 1e-6)

            clock.now = 200
            host.frame()
            XCTAssertEqual(joined.drawnOpacity, 1, accuracy: 1e-6)
        }
    }

    func testWithLessMotionEveryChildArrives() throws {
        try onUIThread {
            let host = WinUIRenderer.bare(clock: TestClock(), reducesMotion: true)
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
            let host = WinUIRenderer.bare(clock: clock)
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
            XCTAssertEqual(first.drawnOpacity, 0.5, accuracy: 1e-6)
            XCTAssertEqual(second.frame.y, 40)

            clock.now = 100
            host.frame()
            XCTAssertFalse(first.isShown, "gone when the fade landed")
            XCTAssertEqual(first.drawnOpacity, 1, accuracy: 1e-6, "at the opacity the tree describes")
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
            let host = WinUIRenderer.bare(clock: clock)
            host.apply(Self.stack(["first", "second"]))
            let first = try XCTUnwrap(host.view(id: .manual("first")))
            host.layOut()

            host.apply(Self.stack(["first", "second"], hidden: ["first"]))
            clock.now = 50
            host.frame()
            host.apply(Self.stack(["first", "second"]))
            XCTAssertEqual(first.drawnOpacity, 0.5, accuracy: 1e-6, "up again from where the fade reached")

            clock.now = 150
            host.frame()
            XCTAssertEqual(first.drawnOpacity, 1, accuracy: 1e-6)
            XCTAssertTrue(first.isShown, "and never gone")
        }
    }

    /// A label whose width travels lays its words out at the width it is bound for: they keep the one line they fit
    /// there, never breaking at the widths its place passes through, and show whole.
    func testATextsWordsStandAtTheWidthItTravelsTo() throws {
        try onUIThread {
            let clock = TestClock()
            let host = WinUIRenderer.running(clock: clock) { LengtheningPage() }
            let label = try XCTUnwrap(host.views(WinUITextView.self).first)

            try XCTUnwrap(host.views(WinUIButtonView.self).first).invoke()
            host.runtime.pump.turn()
            host.layOut()
            clock.now += 100
            host.frame()
            let (place, words) = (label.placedFrame, label.laidOutFrame)
            let stack = try XCTUnwrap(host.views(WinUIStackView.self).first)
            let end = stack.pixels(at: [(place.x + words.width - 1, place.y + 1)])

            clock.now += 200
            host.frame()
            let bound = label.laidOutFrame
            XCTAssertLessThan(place.width, bound.width - 1, "its place on its way")
            XCTAssertEqual(words.width, bound.width, accuracy: 0.5, "its words at the width it is bound for")
            XCTAssertEqual(words.height, bound.height, accuracy: 0.5, "on the one line they fit there")
            XCTAssertEqual(end, [0xFFFF_0000], "shown whole, to the end of its box")
        }
    }
}

/// A label on red lengthened by a button, in a stack whose children travel for 200 ms.
private struct LengtheningPage: View {
    @State private var long = false

    var body: some View {
        VStack {
            Text(long ? "Text & typing" : "Text").background(.red).horizontalAlignment(.start)
            Button("Longer").onClicked { long = true }
        }
        .motion(.eased(.milliseconds(200), .linear))
        .width(300)
        .horizontalAlignment(.start)
        .verticalAlignment(.start)
    }
}
