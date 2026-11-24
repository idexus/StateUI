// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIUIKit
import UIKit
import XCTest

/// UIKit's scroller under an offset the tree carries.
final class UIKitScrollViewTests: XCTestCase {
    /// A stretch past the scroller's edge while the user holds it - the rubber band - stands as the user pulls it,
    /// though what it reports lays the page out again each frame: the scroller's frame, the same, is not set again,
    /// which would pull it back within reach.
    @MainActor
    func testAStretchPastTheEdgeStandsAsTheUserPullsIt() throws {
        let offset = State(wrappedValue: Point(x: 0, y: 0))
        let host = UIKitRenderer.running {
            VStack {
                ScrollView {
                    Rectangle()
                        .fill(.steelBlue)
                        .width(120)
                        .height(3000)
                }
                    .scrollOffset(offset.projectedValue)
                    .height(400)
                Text("\(Int(offset.projectedValue.journey.sample?.value.y ?? 0)) down")
            }
        }
        defer { host.finish() }
        let scroller = try XCTUnwrap(host.views(UIKitScrollView.self).first?.scroller)
        host.settle { scroller.contentSize.height > 0 }

        scroller.delegate?.scrollViewWillBeginDragging?(scroller)
        for y in stride(from: -5.0, through: -40.0, by: -5.0) {
            scroller.contentOffset = CGPoint(x: 0, y: y)
            host.frame()
            host.settle { false }
            XCTAssertEqual(scroller.contentOffset.y, y, accuracy: 0.001, "the stretch stands where the user pulled it")
        }
        XCTAssertEqual(offset.wrappedValue.y, -40, accuracy: 0.001, "and the state follows it")
    }

    /// A SCROLLER KEEPING ITS SIDES CLEAR lays what it scrolls down between them: a page's scroller let under a
    /// phone's sides in landscape stood its content as wide as the screen, moved in by the left side, past the right.
    @MainActor
    func testAScrollerKeepingItsSidesClearLaysItsContentBetweenThem() throws {
        let host = UIKitRenderer.running {
            VStack { ScrollView { Rectangle().fill(.steelBlue).height(2000) }.width(400).height(300) }
        }
        defer { host.finish() }
        let view = try XCTUnwrap(host.views(UIKitScrollView.self).first)
        host.settle { view.scroller.contentSize.width > 0 }
        XCTAssertEqual(view.scroller.contentSize.width, 400, "as wide as the scroller, keeping nothing clear")

        view.keepClear(Clearance(top: 20, left: 40, bottom: 30, right: 30))
        view.layoutIfNeeded()
        XCTAssertEqual(view.scroller.contentSize.width, 330, "as wide as the room between its sides")
        XCTAssertEqual(view.scroller.contentSize.height, 2000, "as tall as it is, scrolling under the top and foot")
    }

    /// A DRAG TAKES THE KEYBOARD DOWN WITH IT: a scroller's and a list's, the keyboard following the finger down -
    /// the road out of an editor, whose return starts a new line.
    /// Design: docs/design/types/keyboard.md#the-keyboard-down
    @MainActor
    func testADragTakesTheKeyboardDownWithIt() throws {
        let host = UIKitRenderer.running {
            VStack {
                ScrollView { Text("A page") }.height(200)
                ItemsView(0..<3) { Text("Row \($0)") }.height(200)
            }
        }
        defer { host.finish() }
        let scroller = try XCTUnwrap(host.views(UIKitScrollView.self).first?.scroller)
        let list = try XCTUnwrap(host.views(UIKitItemsView.self).first?.collection)

        XCTAssertEqual([scroller.keyboardDismissMode, list.keyboardDismissMode], [.interactive, .interactive])
    }
}
