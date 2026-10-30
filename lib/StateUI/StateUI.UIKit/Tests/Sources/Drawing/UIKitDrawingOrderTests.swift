// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIUIKit
import UIKit
import XCTest

/// A layout's children stand back to front as it draws them, whatever passes of UIKit's layout come after.
@MainActor
final class UIKitDrawingOrderTests: XCTestCase {
    /// A PHASE LAYOUT'S FRONT VIEW STAYS IN FRONT AS UIKIT LAYS IT OUT AGAIN: the view its placements rank highest
    /// stands last, the views after it in the tree's order behind it.
    func testAPhaseLayoutsFrontViewStaysInFrontAsUIKitLaysItOutAgain() throws {
        let host = UIKitRenderer.running {
            PhaseLayout([0, 1, 2], phase: State(wrappedValue: 0.0).projectedValue) { _ in
                Rectangle()
                    .fill(.red)
            } placements: { _, _ in
                (0..<3).map { Placement(Rect(Double($0) * 50, 0, 80, 80), zIndex: $0 == 1 ? 2 : 0) }
            }
            .width(300)
            .height(100)
        }
        defer { host.finish() }
        let layout = try XCTUnwrap(host.views(UIKitZStackView.self).first { $0.items.count == 3 })
        layout.setNeedsLayout()
        layout.layoutIfNeeded()

        let order = layout.items.map { item in layout.subviews.firstIndex(of: item.view) ?? -1 }
        XCTAssertEqual(order.map { order.sorted().firstIndex(of: $0) }, [0, 2, 1], "the middle in front, the last behind it")
    }
}
