// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIAppKit
import XCTest

/// Three items, the first chosen.
private struct ChoosingPage: View {
    @State private var chosen: Int? = 0

    var body: some View {
        ItemsView(0..<3) { Text("Item \($0)").padding(12) }
            .selection($chosen)
            .width(300).height(400)
    }
}

final class AppKitItemsViewTests: XCTestCase {
    /// A chosen item lays the platform's accent over the page at a fifth of its strength, as every host's list shows
    /// the user's choice; an item at rest lays nothing.
    @MainActor
    func testAChosenItemShowsTheAccentOverThePage() throws {
        let renderer = autoreleasepool { AppKitRenderer.running { ChoosingPage() } }
        defer { renderer.closeForTesting() }
        let items = try XCTUnwrap(renderer.nativeViews(AppKitItemsView.self).first)
        for _ in 0..<100 where items.collection.visibleItems().isEmpty {
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.01))
            renderer.runtime.pump.turn()
            renderer.windowsForTesting.first?.window?.layoutIfNeeded()
        }

        let cells = items.collection.visibleItems()
            .compactMap { $0.view as? AppKitItemCellView }
            .sorted { $0.frame.minY < $1.frame.minY }
        XCTAssertEqual(cells.count, 3)
        XCTAssertEqual(cells.first?.fill, NSColor.controlAccentColor.withAlphaComponent(0.2), "the choice in the accent")
        XCTAssertEqual(cells.dropFirst().map(\.fill), [nil, nil], "an item at rest lays a colour")
    }
}
#endif
