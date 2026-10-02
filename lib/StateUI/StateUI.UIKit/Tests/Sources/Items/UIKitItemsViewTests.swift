// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIUIKit
import XCTest

/// Three items, the first chosen.
private struct ChoosingPage: ContentView {
    @State private var chosen: Int? = 0

    var content: some View {
        ItemsView(0..<3) { Text("Item \($0)").padding(12) }
            .selection($chosen)
            .width(300).height(400)
    }
}

final class UIKitItemsViewTests: XCTestCase {
    /// A cell at rest shows the page through it, as every host's list does; a chosen one shows the user's choice in
    /// the platform's accent, UIKit's tint, laid over the page.
    @MainActor
    func testACellAtRestHasNoBackgroundOfItsOwn() throws {
        let host = UIKitRenderer.running { ChoosingPage() }
        defer { host.finish() }
        let items = try XCTUnwrap(host.views(UIKitItemsView.self).first)
        host.settle { items.collection.visibleCells.count == 3 }

        let cells = items.collection.visibleCells.sorted { $0.frame.minY < $1.frame.minY }
        XCTAssertEqual(cells.count, 3)
        func alpha(_ cell: UICollectionViewCell) -> CGFloat {
            var alpha: CGFloat = 0
            cell.backgroundConfiguration?.resolvedBackgroundColor(for: cell.tintColor)
                .resolvedColor(with: cell.traitCollection).getRed(nil, green: nil, blue: nil, alpha: &alpha)
            return alpha
        }
        XCTAssertGreaterThan(alpha(cells[0]), 0, "the chosen item shows the choice")
        XCTAssertEqual(
            cells[0].backgroundConfiguration?.backgroundColor, cells[0].tintColor.withAlphaComponent(0.2),
            "the choice in the accent")
        XCTAssertEqual(alpha(cells[1]), 0, "an item at rest draws a background")
        XCTAssertEqual(alpha(cells[2]), 0, "an item at rest draws a background")
    }
}
