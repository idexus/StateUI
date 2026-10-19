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
        let offset = State(wrappedValue: Point(0, 0))
        let host = UIKitRenderer.running {
            VStack {
                ScrollView { Rectangle().fill(.steelBlue).width(120).height(3000) }
                    .scrollOffset(offset.projectedValue)
                    .height(400)
                Text("\(Int(offset.projectedValue.journey.value.y)) down")
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
}
