// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIConformance
@_spi(Host) import StateUIHost
@testable import StateUIUIKit
import XCTest

/// The hand over a layout as UIKit's pan tells it, and the press it begins with.
final class UIKitHandTests: XCTestCase {
    /// What a layout's handler was told, a class so the closure that writes it is not walked for state.
    private final class Told {
        var items: [Int] = []
    }

    /// A FIRST MOVE UIKIT LEAVES TO THE PAGE IS NO HOLD: a press on a layout whose views are taken by a long press,
    /// moved across it - its pan declining it, so no move of it is told after - lifts no view, however long it
    /// stays down.
    @MainActor
    func testAFirstMoveLeftToThePageIsNoHold() throws {
        let (clock, told) = (TestClock(), Told())
        let host = UIKitRenderer.running(clock: clock) {
            MotionLayout([0, 1, 2], parameters: State(wrappedValue: 0.0).projectedValue) { _ in
                Rectangle()
                    .fill(.red)
            } placements: { _, at in
                (0..<3).map { Placement(Rect((Double($0) - at) * 100, 0, 80, 80)) }
            }
            .axis(\.self, input: .scroll(.horizontal), range: 0...2, snaps: .every(1))
            .itemDrag(begins: .longPress)
            .onItemDragged { told.items.append($0.item) }
            .width(300)
            .height(100)
        }
        defer { host.finish() }
        let element = try XCTUnwrap(host.runtime.tree.root?.first(type: .motionLayout))
        let listening = try XCTUnwrap((element.native as? UIKitElement)?.listening)

        // The finger goes down on the first view, as the pan tells it, then moves down two icons' height.
        listening.hand(.began, moved: .zero, point: Point(x: 40, y: 40))
        XCTAssertFalse(listening.handBegins(first: Point(x: 2, y: 40)), "UIKit leaves it to the page")
        for _ in 0..<40 {
            clock.now += 16
            host.frame()
        }

        XCTAssertEqual(told.items, [], "no view lifted")
    }
}
