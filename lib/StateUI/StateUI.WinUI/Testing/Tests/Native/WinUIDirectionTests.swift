// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIWinUI
@testable import StateUIWinUIDriver
@_spi(Host) import StateUIConformance
import XCTest

/// A view laid out right to left on WinUI: a control writes its own way; a layout's places are the host layer's and a
/// drawing is never turned, so both stand left to right in WinUI.
final class WinUIDirectionTests: XCTestCase {
    private static let red: UInt32 = 0xFFFF_0000
    private static let blue: UInt32 = 0xFF00_00FF

    /// A control takes the direction its element inherits, and turns with it; the layout holding it stays left to
    /// right in WinUI.
    func testAControlWritesInItsElementsDirection() throws {
        try onUIThread {
            let direction = State(wrappedValue: LayoutDirection.rightToLeft)
            let host = WinUIRenderer.running {
                VStack {
                    Label("Words")
                    Button("Go")
                    TextField()
                    CheckBox()
                    Slider()
                }
                .layoutDirection(direction.wrappedValue)
            }
            let driver = WinUIDriver()
            let views = host.views(WinUIView.self)
            let controls = views.filter { !($0 is WinUILayoutView) }
            let flows = { try controls.map { try driver.read($0, "flowDirection") } }
            XCTAssertEqual(controls.count, 5)
            XCTAssertEqual(try flows(), ["1", "1", "1", "1", "1"], "every control right to left")
            let layouts = try views.filter { $0 is WinUILayoutView }.map { try driver.read($0, "flowDirection") }
            XCTAssertEqual(Set(layouts), ["0"], "every layout left to right")

            direction.wrappedValue = .leftToRight
            host.settle { (try? flows()) == ["0", "0", "0", "0", "0"] }
            XCTAssertEqual(try flows(), ["0", "0", "0", "0", "0"], "every control turned back")
        }
    }

    /// A row right to left fills from the right by the host layer's arithmetic alone: WinUI mirrors none of its
    /// places a second time.
    func testARowRightToLeftFillsFromTheRight() throws {
        let colours = try drawnRightToLeft(at: [(90, 10), (70, 10), (10, 10)]) {
            HStack {
                Rectangle().fill(Color("#FF0000")).width(20).height(20)
                Rectangle().fill(Color("#0000FF")).width(20).height(20)
            }
            .spacing(0)
        }
        XCTAssertEqual(colours, [Self.red, Self.blue, 0])
    }

    /// A picture and a figure in a row right to left are drawn as they are, not mirrored.
    func testADrawingRightToLeftIsNotTurned() throws {
        let picture = try drawnRightToLeft(at: [(65, 10), (95, 10)]) {
            HStack { Image("test_halves.svg").width(40).height(20) }
        }
        XCTAssertEqual(picture, [Self.red, Self.blue], "the picture's red half still at its left")

        let figure = try drawnRightToLeft(at: [(95, 15), (65, 15)]) {
            HStack { Path("M 0 0 L 10 0 L 10 10 Z").fill(Color("#FF0000")).width(40).height(40) }
        }
        XCTAssertEqual(figure, [Self.red, 0], "the triangle's corner still at its right")
    }

    /// The driver reads by the host's own (`WinUIDriver.standsLeftToRight`) the direction of exactly the elements
    /// whose views stand left to right, and of every other element WinUI's own.
    func testTheDriverReadsByTheHostExactlyTheViewsStandingLeftToRight() throws {
        try onUIThread {
            WinUIBackends.registered
            let unmade = WinUIRealization.unmade
            for element in Specimens.wearing(VisualElementContract.self) where !unmade.contains(element) {
                let host = WinUIRenderer.running { Specimens.page(element) }
                let specimen = host.runtime.tree.root?.first(id: .manual("specimen"))
                let view = try XCTUnwrap((specimen?.native as? WinUIElement)?.view, element)
                XCTAssertEqual(view.directionHolder != nil, !WinUIDriver.standsLeftToRight.contains(element), element)
            }
        }
    }

    /// The colours at `points` of `content` laid out right to left in a room 100 wide, read off the layout holding it.
    private func drawnRightToLeft(
        at points: [(Double, Double)], _ content: @escaping @Sendable () -> any View
    ) throws -> [UInt32] {
        try onUIThread {
            let host = WinUIRenderer.running {
                VStack { ModifiedContent(node: content().body).width(100).layoutDirection(.rightToLeft) }
                    .horizontalAlignment(.start)
                    .verticalAlignment(.start)
            }
            let stack = try XCTUnwrap(host.views(WinUIStackView.self).first)
            host.settle { stack.pixels(at: [points[0]]) != [0] }
            return stack.pixels(at: points)
        }
    }
}
