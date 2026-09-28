// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIGTK
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
