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

    /// The list's own header stands throughout a change of its items that moves every row: AppKit takes its own
    /// boundary views down while it animates a change, and a section's stand.
    @MainActor
    func testTheListsHeaderStandsWhileItsRowsMove() throws {
        let numbers = State(wrappedValue: Array(0..<1_000))
        let renderer = autoreleasepool {
            AppKitRenderer.running {
                ItemsView(numbers.wrappedValue) { Text("Row \($0)").padding(10) }
                    .header(Text("Rows").padding(8))
                    .width(300).height(500)
            }
        }
        defer { renderer.closeForTesting() }
        let items = try XCTUnwrap(renderer.nativeViews(AppKitItemsView.self).first)
        func header() -> AppKitItemSupplement? {
            items.collection.visibleSupplementaryViews(ofKind: AppKitItemsLayout.listHeader).first as? AppKitItemSupplement
        }
        func step() {
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.01))
            renderer.runtime.pump.turn()
            renderer.windowsForTesting.first?.window?.layoutIfNeeded()
        }
        for _ in 0..<100 {
            guard header()?.holding.shown == nil || items.collection.visibleItems().count < 5 else { break }
            step()
        }
        XCTAssertNotNil(header()?.holding.shown, "the header stands at rest")

        numbers.wrappedValue = [999] + Array(0..<999)
        var gone: [Int] = []
        for index in 0..<40 {
            step()
            if header().map({ $0.holding.shown == nil || $0.isHidden }) ?? true { gone.append(index) }
        }

        XCTAssertEqual(gone, [], "the steps the header was gone in")
    }

    /// A header the list gains stands above its rows, and one it loses leaves.
    @MainActor
    func testAHeaderTheListGainsStandsAndOneItLosesLeaves() throws {
        let headed = State(wrappedValue: false)
        let renderer = autoreleasepool {
            AppKitRenderer.running {
                let list = ItemsView(0..<3) { Text("Row \($0)") }
                (headed.wrappedValue ? list.header(Text("Rows")) : list).width(300).height(400)
            }
        }
        defer { renderer.closeForTesting() }
        let items = try XCTUnwrap(renderer.nativeViews(AppKitItemsView.self).first)
        func texts(in view: NSView) -> [String] {
            ((view as? AppKitTextView)?.stringValue).map { [$0] } ?? view.subviews.flatMap(texts)
        }
        func shown() -> [String] {
            let headers = items.collection.visibleSupplementaryViews(ofKind: AppKitItemsLayout.listHeader)
            let rows = items.collection.visibleItems().map(\.view)
            return (headers + rows).filter { !$0.isHidden }.sorted { $0.frame.minY < $1.frame.minY }
                .map { texts(in: $0).joined() }
        }
        func settle(until done: () -> Bool) {
            for _ in 0..<100 {
                guard !done() else { break }
                RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.01))
                renderer.runtime.pump.turn()
                renderer.windowsForTesting.first?.window?.layoutIfNeeded()
            }
        }
        settle { shown() == ["Row 0", "Row 1", "Row 2"] }

        headed.wrappedValue = true
        settle { shown() == ["Rows", "Row 0", "Row 1", "Row 2"] }
        XCTAssertEqual(shown(), ["Rows", "Row 0", "Row 1", "Row 2"])
        XCTAssertTrue(renderer.nativeViews(AppKitItemsView.self).first === items, "the same list gains the header")

        headed.wrappedValue = false
        settle { shown() == ["Row 0", "Row 1", "Row 2"] }
        XCTAssertEqual(shown(), ["Row 0", "Row 1", "Row 2"])
    }
}
#endif
