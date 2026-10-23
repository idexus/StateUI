// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIUIKit
@_spi(Host) import StateUIConformance
import XCTest

/// A change that travels, as UIKit draws it frame by frame: the host layer walks the value, and the view stands where
/// the frame says.
@MainActor
final class UIKitMotionTests: XCTestCase {
    /// A label whose width travels lays its words out at the width it is bound for: midway, its view is already as
    /// wide as it lands, so words that fit there on one line never break at the widths its place passes through.
    @MainActor
    func testATextsWordsStandAtTheWidthItTravelsTo() throws {
        let clock = TestClock()
        let long = State(wrappedValue: false)
        let host = UIKitRenderer.running(clock: clock) {
            VStack {
                Text(long.wrappedValue ? "Text & typing" : "Text").horizontalAlignment(.start).id("caption")
            }
            .motion(.eased(.milliseconds(200), .linear))
            .width(300)
            .horizontalAlignment(.start)
            .verticalAlignment(.start)
        }
        defer { host.finish() }
        let label = try XCTUnwrap(Self.view(of: "caption", in: host))
        let start = label.bounds.width

        long.wrappedValue = true
        host.runtime.pump.turn()
        host.layOut()
        clock.now = 100
        host.frame()
        host.layOut()
        let midway = label.bounds.width
        clock.now = 200
        host.frame()
        host.layOut()

        XCTAssertGreaterThan(label.bounds.width, start + 1, "the caption grew")
        XCTAssertEqual(midway, label.bounds.width, accuracy: 0.5, "its words at the width it is bound for")
    }

    /// A button whose width travels as its words change lays them out at the width it is bound for, as a label does:
    /// midway it is already as wide as it lands, so its words never break onto a second line on the way.
    @MainActor
    func testAButtonsWordsStandAtTheWidthItTravelsTo() throws {
        let clock = TestClock()
        let enabled = State(wrappedValue: true)
        let host = UIKitRenderer.running(clock: clock) {
            VStack {
                Button(enabled.wrappedValue ? "Enabled" : "Disabled").horizontalAlignment(.center).id("button")
            }
            .motion(.eased(.milliseconds(200), .linear))
            .width(300)
            .verticalAlignment(.start)
        }
        defer { host.finish() }
        let button = try XCTUnwrap(Self.view(of: "button", in: host))
        let start = button.bounds.width

        enabled.wrappedValue = false
        host.runtime.pump.turn()
        host.layOut()
        clock.now = 100
        host.frame()
        host.layOut()
        let midway = button.bounds.width
        clock.now = 200
        host.frame()
        host.layOut()

        XCTAssertGreaterThan(button.bounds.width, start + 1, "the button grew")
        XCTAssertEqual(midway, button.bounds.width, accuracy: 0.5, "its words at the width it is bound for")
    }

    /// A rectangle whose fill and width change under a motion stands halfway at half its time, and lands - the
    /// Gallery's Motion sample.
    @MainActor
    func testAColorAndAWidthTravelHalfwayAndLand() throws {
        let clock = TestClock()
        let wide = State(wrappedValue: false)
        let host = UIKitRenderer.running(clock: clock) {
            VStack {
                Rectangle()
                    .fill(wide.wrappedValue ? Color(red: 255, green: 0, blue: 0) : Color(red: 0, green: 0, blue: 255))
                    .width(wide.wrappedValue ? 300 : 100)
                    .height(60)
                    .horizontalAlignment(.start)
                    .motion(.eased(.milliseconds(1000), .linear))
                    .id("box")
            }
        }
        defer { host.finish() }
        let box = try XCTUnwrap(Self.view(of: "box", in: host) as? UIKitShapeView)
        XCTAssertEqual(box.bounds.width, 100, accuracy: 0.5)

        wide.wrappedValue = true
        host.runtime.pump.turn()
        clock.now = 500
        host.frame()
        host.layOut()
        XCTAssertEqual(box.bounds.width, 200, accuracy: 1, "halfway across")
        let halfway = try XCTUnwrap(Self.components(of: box))
        XCTAssertEqual(halfway.red, 0.5, accuracy: 0.05, "halfway to red")
        XCTAssertEqual(halfway.blue, 0.5, accuracy: 0.05, "halfway from blue")

        clock.now = 1000
        host.frame()
        host.layOut()
        XCTAssertEqual(box.bounds.width, 300, accuracy: 0.5, "landed")
        XCTAssertEqual(try XCTUnwrap(Self.components(of: box)).red, 1, accuracy: 0.01)
    }

    /// A row joining a standing stack fades in while the row below it slides down to make room, both halfway at half
    /// their time.
    @MainActor
    func testARowJoiningFadesInWhileTheOneBelowSlides() throws {
        let clock = TestClock()
        let joined = State(wrappedValue: false)
        let host = UIKitRenderer.running(clock: clock) {
            VStack {
                if joined.wrappedValue {
                    Rectangle()
                        .fill(Color(red: 255, green: 0, blue: 0))
                        .height(40)
                        .id("joining")
                }
                Rectangle()
                    .fill(Color(red: 0, green: 0, blue: 255))
                    .height(40)
                    .id("below")
            }
            .motion(.eased(.milliseconds(1000), .linear))
        }
        defer { host.finish() }
        let below = try XCTUnwrap(Self.view(of: "below", in: host))
        let start = below.frame.minY

        joined.wrappedValue = true
        host.runtime.pump.turn()
        host.layOut()
        clock.now = 500
        host.frame()
        host.layOut()
        let joining = try XCTUnwrap(Self.view(of: "joining", in: host))
        XCTAssertEqual(joining.alpha, 0.5, accuracy: 0.05, "halfway in")
        XCTAssertEqual(below.frame.minY - start, 20, accuracy: 2, "halfway down")

        clock.now = 1000
        host.frame()
        host.layOut()
        XCTAssertEqual(joining.alpha, 1, accuracy: 0.01)
        XCTAssertEqual(below.frame.minY - start, 40, accuracy: 1)
    }

    /// A row hidden fades where it stands, then its stack closes over it - and every layout around the stack follows
    /// the stack's new size: the view below the stack comes up as far as the row was tall.
    @MainActor
    func testARowFadedOutClosesEveryLayoutAroundIt() throws {
        let clock = TestClock()
        let shown = State(wrappedValue: true)
        let host = UIKitRenderer.running(clock: clock) {
            VStack {
                VStack {
                    Rectangle()
                        .fill(Color(red: 255, green: 0, blue: 0))
                        .height(40)
                        .isVisible(shown.wrappedValue)
                    Rectangle()
                        .fill(Color(red: 0, green: 255, blue: 0))
                        .height(40)
                }
                .spacing(0)
                Rectangle()
                    .fill(Color(red: 0, green: 0, blue: 255))
                    .height(40)
                    .id("below")
            }
            .spacing(0)
            .motion(.eased(.milliseconds(1000), .linear))
        }
        defer { host.finish() }
        let below = try XCTUnwrap(Self.view(of: "below", in: host))
        let start = below.frame.minY

        shown.wrappedValue = false
        host.runtime.pump.turn()
        host.layOut()
        var risen: [Double] = []
        for now in stride(from: 250, through: 4000, by: 250) {
            clock.now = Double(now)
            host.frame()
            host.layOut()
            risen.append(start - below.frame.minY)
        }

        XCTAssertEqual(risen.last ?? 0, 40, accuracy: 1, "the view below the stack came up as the row went")
        XCTAssertTrue(risen.contains { $0 > 1 && $0 < 39 }, "on its way, not at once: \(risen)")
    }

    /// A label filling a stack whose width travels lays its words out at the width the stack is bound for: the
    /// stack lays its children out there, its own place traveling around them - the words never break onto a second
    /// line on the way, as the Popover sample's did as its popover closed.
    @MainActor
    func testALabelInAStackThatTravelsKeepsItsWordsOnOneLine() throws {
        let clock = TestClock()
        let open = State(wrappedValue: true)
        let host = UIKitRenderer.running(clock: clock) {
            VStack {
                Text(open.wrappedValue ? "The popover shows" : "The popover is closed").fontSize(13).id("said")
            }
            .horizontalAlignment(.start)
            .verticalAlignment(.start)
        }
        defer { host.finish() }
        let said = try XCTUnwrap(Self.view(of: "said", in: host))
        let line = said.bounds.height

        open.wrappedValue = false
        host.runtime.pump.turn()
        host.layOut()
        var heights = [said.bounds.height]
        for now in stride(from: 50, through: 800, by: 50) {
            clock.now = Double(now)
            host.frame()
            host.layOut()
            heights.append(said.bounds.height)
        }

        XCTAssertEqual(heights.max() ?? 0, line, accuracy: 0.5, "one line all the way: \(heights)")
    }

    /// The fill the rectangle draws, as red, green and blue.
    @MainActor
    private static func components(of box: UIKitShapeView) -> (red: Double, green: Double, blue: Double)? {
        guard let fill = box.fillForTesting.lineColor else { return nil }
        var (red, green, blue, alpha) = (CGFloat(0), CGFloat(0), CGFloat(0), CGFloat(0))
        guard fill.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return nil }
        return (red, green, blue)
    }

    /// The view of the element of `id` in the host's tree.
    @MainActor
    private static func view(of id: String, in host: UIKitRenderer) -> UIView? {
        func find(_ element: MountedElement) -> MountedElement? {
            element.id == .manual(id) ? element : element.children.lazy.compactMap(find).first
        }
        return host.runtime.tree.root.flatMap(find).flatMap { ($0.native as? UIKitElement)?.view }
    }
}
