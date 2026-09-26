// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIGTK
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIGTK
import XCTest

final class GTKButtonViewTests: XCTestCase {
    /// A button's caption takes the font and colour the tree gives it, and its box the fill, the outline and the
    /// corners, drawn in the fill.
    func testAButtonTakesItsWordsAndItsBox() throws {
        try onUIThread {
            let host = GTKRenderer.running {
                VStack {
                    Button("Save")
                        .fontSize(20)
                        .fontAttributes(.bold)
                        .textColor(Color("#FFFFFF"))
                        .background(Color("#0000FF"))
                        .stroke(Color("#FF0000"))
                        .strokeWidth(2)
                        .shape(.roundedRectangle(10))
                        .padding(16, 11)
                }
            }
            let button = try XCTUnwrap(host.views(GTKButtonView.self).first)
            let label = try XCTUnwrap(gtk_button_get_child(button.widget.of(GtkButton.self)))
            let said = try XCTUnwrap(gtk_label_get_attributes(label.opaque)).kinds
            host.layOut()
            let (width, height) = (button.frame.width, button.frame.height)

            XCTAssertTrue(said.contains(PANGO_ATTR_ABSOLUTE_SIZE.rawValue), "the font's size")
            XCTAssertTrue(said.contains(PANGO_ATTR_WEIGHT.rawValue), "bold")
            XCTAssertTrue(said.contains(PANGO_ATTR_FOREGROUND.rawValue), "the words' colour")
            XCTAssertNotEqual(gtk_widget_has_css_class(button.widget, "stateui-box-f0000FFFF-sFF0000FF-w2-r10"), 0)
            XCTAssertNotEqual(gtk_widget_has_css_class(button.widget, "stateui-padding-11-16-11-16"), 0)
            let fill = try XCTUnwrap(button.pixels(at: [(8, height / 2)]).first)
            XCTAssertTrue(near(fill, 0xFF00_00FF), "filled in the fill, \(width) by \(height): \(String(fill, radix: 16))")
        }
    }

    /// A button the tree says nothing of stands as the platform's own.
    func testAButtonWithNothingSaidIsThePlatformsOwn() throws {
        try onUIThread {
            let host = GTKRenderer.running { VStack { Button("Plain") } }
            let button = try XCTUnwrap(host.views(GTKButtonView.self).first)
            let label = try XCTUnwrap(gtk_button_get_child(button.widget.of(GtkButton.self)))

            XCTAssertEqual(gtk_label_get_attributes(label.opaque).map(\.kinds) ?? [], [])
            XCTAssertFalse(GTKTestHost.classes(of: button.widget).contains { $0.hasPrefix("stateui-") })
        }
    }
}

private extension OpaquePointer {
    /// The types of a Pango attribute list's attributes.
    var kinds: [UInt32] {
        let first = pango_attr_list_get_attributes(self)
        var kinds: [UInt32] = []
        var each = first
        while let node = each {
            kinds.append(node.pointee.data.assumingMemoryBound(to: PangoAttribute.self).pointee.klass.pointee.type.rawValue)
            each = node.pointee.next
        }
        g_slist_free_full(first) { pango_attribute_destroy($0?.assumingMemoryBound(to: PangoAttribute.self)) }
        return kinds
    }
}
