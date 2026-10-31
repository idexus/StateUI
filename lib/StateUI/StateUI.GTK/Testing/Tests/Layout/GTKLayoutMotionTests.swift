// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
@testable import StateUIGTK
@testable import StateUIGTKDriver
import CStateUIGTK
import StateUIConformance
import XCTest

/// A caption whose words a button lengthens, in a stack 300 wide traveling on a 200 ms linear law.
private struct LengtheningPage: View {
    @State private var long = false

    var body: some View {
        VStack {
            Text(long ? "Text & typing" : "Text").horizontalAlignment(.start)
            Button("Longer").onClicked { long = true }
        }
        .motion(.eased(.milliseconds(200), .linear))
        .width(300)
        .horizontalAlignment(.start)
        .verticalAlignment(.start)
    }
}

/// A button whose words a state lengthens, in the middle of a stack whose children travel for 200 ms.
private struct SwitchedPage: View {
    let on: State<Bool>

    var body: some View {
        VStack {
            Button(on.wrappedValue ? "On" : "Switched off").horizontalAlignment(.center)
        }
        .motion(.eased(.milliseconds(200), .linear))
        .width(300)
        .verticalAlignment(.start)
    }
}

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
@MainActor
final class GTKLayoutMotionTests: XCTestCase {
    /// A label whose words lengthen stands at the width they need from the start: they keep the one line they fit
    /// where it is bound, never breaking at the widths its place passes through.
    func testATextsWordsStandAtTheWidthTheyNeed() throws {
        try onUIThread {
            let clock = TestClock()
            let host = GTKRenderer.running(clock: clock) { LengtheningPage() }
            let label = try XCTUnwrap(host.views(GTKTextView.self).first)

            try XCTUnwrap(host.views(GTKButtonView.self).first).click()
            host.runtime.pump.turn()
            host.layOut()
            clock.now += 100
            host.frame()

            var natural: Int32 = 0
            gtk_widget_measure(label.widget, GTK_ORIENTATION_HORIZONTAL, -1, nil, &natural, nil, nil)
            XCTAssertEqual(gtk_widget_get_width(label.widget), natural, "midway, its words at the width they need")
        }
    }

    /// A button whose new words need more than its box keeps showing its former words while the box grows, and
    /// shows the new ones as it lands.
    func testAButtonsGrownWordsShowOnceItsBoxHoldsThem() throws {
        try onUIThread {
            let clock = TestClock()
            let on = State(wrappedValue: true)
            let host = GTKRenderer.running(clock: clock) { SwitchedPage(on: on) }
            host.layOut()
            let button = try XCTUnwrap(host.views(GTKButtonView.self).first)
            @MainActor func said() -> String {
                button.captionLabel.map { String(cString: gtk_label_get_text($0)) } ?? ""
            }
            let start = Double(gtk_widget_get_width(button.widget))

            on.wrappedValue = false
            host.runtime.pump.turn()
            host.layOut()
            clock.now += 100
            host.frame()
            let (midway, saidMidway) = (Double(gtk_widget_get_width(button.widget)), said())
            clock.now += 100
            host.frame()
            let end = Double(gtk_widget_get_width(button.widget))

            XCTAssertEqual(saidMidway, "On", "midway, its former words")
            XCTAssertEqual(midway, (start + end) / 2, accuracy: 1.5, "in a box halfway grown")
            XCTAssertEqual(said(), "Switched off", "and the new ones as it lands")
            XCTAssertGreaterThan(end, start + 10)
        }
    }

    /// A label filling a stack whose width travels lays its words out at the width the stack is bound for: the
    /// stack lays its children out there, its own place traveling around them - the words never break onto a second
    /// line on the way, as the Popover sample's did as its popover closed.
    func testALabelInAStackThatTravelsKeepsItsWordsOnOneLine() throws {
        try onUIThread {
            let clock = TestClock()
            let open = State(wrappedValue: true)
            let host = GTKRenderer.running(clock: clock) { SaidPage(open: open) }
            host.layOut()
            let said = try XCTUnwrap(host.view(id: .manual("said")))
            let stack = try XCTUnwrap(host.view(id: .manual("stack")))
            let line = gtk_widget_get_height(said.widget)

            open.wrappedValue = false
            host.runtime.pump.turn()
            host.layOut()
            var (heights, widths) = ([gtk_widget_get_height(said.widget)], [gtk_widget_get_width(stack.widget)])
            for now in stride(from: 50, through: 800, by: 50) {
                clock.now = Double(now)
                host.frame()
                heights.append(gtk_widget_get_height(said.widget))
                widths.append(gtk_widget_get_width(stack.widget))
            }

            XCTAssertTrue(widths.contains { $0 > widths[0] + 1 && $0 < widths[widths.count - 1] - 1 }, "\(widths)")
            XCTAssertEqual(heights.max() ?? 0, line, "one line all the way: \(heights)")
        }
    }

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
