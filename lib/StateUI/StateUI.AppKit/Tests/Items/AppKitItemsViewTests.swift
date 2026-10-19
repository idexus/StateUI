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

@MainActor
final class AppKitItemsViewTests: XCTestCase {
    /// A chosen item lays the platform's accent over the page at a fifth of its strength, as every host's list shows
    /// the user's choice; an item at rest lays nothing.
    @MainActor
    func testAChosenItemShowsTheAccentOverThePage() throws {
        let renderer = autoreleasepool { AppKitRenderer.running { ChoosingPage() } }
        defer { renderer.closeForTesting() }
        let items = try XCTUnwrap(renderer.nativeViews(AppKitItemsView.self).first)
        for _ in 0..<100 {
            guard items.collection.visibleItems().isEmpty else { break }
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
    /// A group added before the others brings its own header, and every other group keeps its own: a group is known
    /// by its name, not its place.
    @MainActor
    func testAGroupAddedOnTopBringsItsOwnHeader() throws {
        let days = State(wrappedValue: ["Yesterday"])
        let renderer = autoreleasepool {
            AppKitRenderer.running {
                ItemsView(groups: days.wrappedValue.map { day in
                    Section([day + " note"]) { Text($0) }.id(day).header(Text(day))
                })
                .width(300).height(400)
            }
        }
        defer { renderer.closeForTesting() }
        let items = try XCTUnwrap(renderer.nativeViews(AppKitItemsView.self).first)
        func texts(in view: NSView) -> [String] {
            ((view as? AppKitTextView)?.stringValue).map { [$0] } ?? view.subviews.flatMap(texts)
        }
        func headers() -> [String] {
            let headers = items.collection.visibleSupplementaryViews(ofKind: AppKitItemsLayout.header)
            return headers.sorted { $0.frame.minY < $1.frame.minY }.map { texts(in: $0).joined() }
        }
        func settle(until done: () -> Bool) {
            for _ in 0..<100 {
                guard !done() else { break }
                RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.01))
                renderer.runtime.pump.turn()
                renderer.windowsForTesting.first?.window?.layoutIfNeeded()
            }
        }
        settle { headers() == ["Yesterday"] }

        days.wrappedValue = ["Today", "Yesterday"]
        settle { headers() == ["Today", "Yesterday"] }

        XCTAssertEqual(headers(), ["Today", "Yesterday"])
    }
}
#endif
