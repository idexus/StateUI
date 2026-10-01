// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIGTK
@testable import StateUIGTKDriver
import CStateUIGTK
import XCTest

final class GTKItemsViewTests: XCTestCase {
    /// A row stands as tall as its entry, so only the rows its view holds are shown: at their least, a StateUI
    /// panel's nothing, every row GTK binds would stand in view at once.
    func testARowStandsAsTallAsItsEntry() throws {
        try onUIThread {
            let host = GTKRenderer.running {
                VStack { ItemsView(0..<100) { Label("Item \($0)").padding(12) }.width(300).height(300) }
            }
            let list = try XCTUnwrap(host.views(GTKItemsView.self).first)
            host.settle { list.shownRows.contains(42) }
            let rows = list.shownRows

            XCTAssertEqual(rows.count, 7, "as many as 300 holds")
            XCTAssertEqual(Set(rows), [42], "each as tall as its entry")
        }
    }
}

extension GTKItemsViewTests {
    /// A collection paints nothing behind its rows of its own, a list and a grid alike: what stands under it shows.
    func testACollectionShowsWhatStandsUnderIt() throws {
        try onUIThread {
            let host = GTKRenderer.running {
                VStack {
                    ItemsView(0..<1) { Label("Item \($0)").padding(12) }.width(300).height(200)
                    ItemsView(0..<1) { Label("Tile \($0)").padding(12) }.itemsLayout(.grid(minimumItemWidth: 100)).width(300).height(200)
                }
            }
            let collections = host.views(GTKItemsView.self)
            host.settle { collections.allSatisfy { $0.shownRows.count == 1 } }

            for collection in collections {
                let pixel = try XCTUnwrap(collection.pixels(at: [(150, 190)]).first)
                XCTAssertEqual(pixel >> 24, 0, "nothing painted beneath the rows: \(String(pixel, radix: 16))")
            }
        }
    }

    /// The item chosen is shaded in the colour of the words around it, a list's row and a grid's tile alike: no hue
    /// of its own beside the page it stands on.
    func testTheChosenItemIsShadedInItsWordsColour() throws {
        try onUIThread {
            let (row, tile) = (State<Int?>(wrappedValue: 1), State<Int?>(wrappedValue: 1))
            let host = GTKRenderer.running {
                VStack {
                    ItemsView(0..<3) { Label("Item \($0)").padding(12) }.selection(row.projectedValue)
                        .width(300).height(200)
                    ItemsView(0..<3) { Label("Tile \($0)").padding(12) }.selection(tile.projectedValue)
                        .itemsLayout(.grid(minimumItemWidth: 100)).width(300).height(200)
                }
            }
            let collections = host.views(GTKItemsView.self)
            host.settle { collections.allSatisfy { $0.shownRows.count == 3 } }

            for (collection, point) in zip(collections, [(150.0, 69.0), (150.0, 24.0)]) {
                let pixel = try XCTUnwrap(collection.pixels(at: [point]).first)
                let (red, green, blue) = (pixel >> 16 & 0xFF, pixel >> 8 & 0xFF, pixel & 0xFF)
                XCTAssertGreaterThan(pixel >> 24, 0, "shaded: \(String(pixel, radix: 16))")
                XCTAssertTrue(red == green && green == blue, "in the words' colour: \(String(pixel, radix: 16))")
            }
        }
    }

    /// A row is named by what its entry says (`MountedElement.spokenWords`): the screen reader reads a row by its
    /// name alone.
    func testARowIsNamedByWhatItsEntrySays() throws {
        try onUIThread {
            let host = GTKRenderer.running {
                VStack { ItemsView(0..<3) { Label("Item \($0)").padding(12) }.width(300).height(300) }
            }
            let list = try XCTUnwrap(host.views(GTKItemsView.self).first)
            let names = {
                list.made.compactMap { row, cell in
                    cell.identity.map { _ in gtk_list_item_get_accessible_label(row).map { String(cString: $0) } ?? "" }
                }.sorted()
            }
            host.settle { names() == ["Item 0", "Item 1", "Item 2"] }

            XCTAssertEqual(names(), ["Item 0", "Item 1", "Item 2"])
        }
    }
}

private extension GTKItemsView {
    /// The heights of the rows GTK shows, in order.
    var shownRows: [Int32] {
        var scrolled = gtk_widget_get_first_child(widget)
        while let each = scrolled, g_type_check_instance_is_a(each.of(GTypeInstance.self), gtk_scrolled_window_get_type()) == 0 {
            scrolled = gtk_widget_get_first_child(each)
        }
        guard let scrolled, let list = gtk_scrolled_window_get_child(scrolled.opaque) else { return [] }
        var rows: [Int32] = []
        var row = gtk_widget_get_first_child(list)
        while let each = row {
            if gtk_widget_get_mapped(each) != 0 { rows.append(gtk_widget_get_height(each)) }
            row = gtk_widget_get_next_sibling(each)
        }
        return rows
    }
}
