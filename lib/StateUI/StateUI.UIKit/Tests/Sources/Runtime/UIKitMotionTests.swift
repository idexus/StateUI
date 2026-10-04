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
            .motion(.eased(200, .linear))
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

    /// A colour box whose colour and width change under a motion stands halfway at half its time, and lands - the
    /// Gallery's Motion sample.
    @MainActor
    func testAColourAndAWidthTravelHalfwayAndLand() throws {
        let clock = TestClock()
        let wide = State(wrappedValue: false)
        let host = UIKitRenderer.running(clock: clock) {
            VStack {
                ColorBox()
                    .color(wide.wrappedValue ? Color(red: 255, green: 0, blue: 0) : Color(red: 0, green: 0, blue: 255))
                    .width(wide.wrappedValue ? 300 : 100)
                    .height(60)
                    .horizontalAlignment(.start)
                    .motion(.eased(1000, .linear))
                    .id("box")
            }
        }
        defer { host.finish() }
        let box = try XCTUnwrap(Self.view(of: "box", in: host) as? UIKitColorBoxView)
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
                    ColorBox().color(Color(red: 255, green: 0, blue: 0)).height(40).id("joining")
                }
                ColorBox().color(Color(red: 0, green: 0, blue: 255)).height(40).id("below")
            }
            .motion(.eased(1000, .linear))
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

    /// The fill the colour box draws, as red, green and blue.
    @MainActor
    private static func components(of box: UIKitColorBoxView) -> (red: Double, green: Double, blue: Double)? {
        guard let fill = (box.layer as? CAShapeLayer)?.fillColor.map(UIColor.init(cgColor:)) else { return nil }
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
