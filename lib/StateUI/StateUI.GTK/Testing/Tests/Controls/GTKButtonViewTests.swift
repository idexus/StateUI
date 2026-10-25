// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CGTKTesting
import CStateUIGTK
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIGTK
@testable import StateUIGTKDriver
import XCTest

@MainActor
final class GTKButtonViewTests: XCTestCase {
    /// GTK's criticals said while a test ran - a call on a widget gone among them.
    nonisolated(unsafe) private static var criticals = 0

    /// A button holding a menu opened as it is held lets the menu go as it leaves: its popover, its actions and its
    /// place in the menus shown - once, GTK saying nothing of a popover let go twice.
    func testAHeldMenuLeavesWithItsButton() {
        Self.criticals = 0
        let heard = g_log_set_handler(
            "Gtk", GLogLevelFlags(rawValue: 1 << 3), { _, _, _, _ in GTKButtonViewTests.criticals += 1 },
            nil)
        defer { g_log_remove_handler("Gtk", heard) }
        onUIThread {
            let shown = State(wrappedValue: true)
            let host = GTKRenderer.running {
                VStack {
                    if shown.wrappedValue {
                        Button("Save").menu(.held) { MenuItem("Save as") }
                    }
                }
            }
            host.settle { GTKContextMenu.shownCount > 0 }
            let menus = GTKContextMenu.shownCount

            shown.wrappedValue = false
            host.settle { host.views(GTKButtonView.self).isEmpty && GTKContextMenu.shownCount < menus }
            XCTAssertEqual(GTKContextMenu.shownCount, menus - 1, "the held menu outlived its button")
        }
        XCTAssertEqual(Self.criticals, 0, "GTK said a critical as the button left")
    }

    /// A button's menu and its context menu each run their own items: GTK finds an item's action by its group's name
    /// on the widget, and two menus under one name would run each other's.
    func testAButtonsMenuAndItsContextMenuRunTheirOwnItems() throws {
        try onUIThread {
            var heard: [String] = []
            let driver = GTKDriver()
            let tree = driver.start(clock: nil, reducesMotion: false) {
                Button("Share")
                    .menu { MenuItem("Mail").onClicked { heard.append("mail") }.id("mail") }
                    .contextMenu { MenuItem("Delete").onClicked { heard.append("delete") }.id("delete") }
            }
            let root = try XCTUnwrap(tree.root)

            try driver.chooseMenuItem(try XCTUnwrap(root.first(id: .manual("delete"))))
            driver.renderer?.settle { !heard.isEmpty }
            try driver.chooseMenuItem(try XCTUnwrap(root.first(id: .manual("mail"))))
            driver.renderer?.settle { heard.count == 2 }

            XCTAssertEqual(heard, ["delete", "mail"])
        }
    }

    /// A button's caption takes the font and color the tree gives it, and its box the fill, the outline and the
    /// corners, drawn in the fill.
    func testAButtonTakesItsWordsAndItsBox() throws {
        try onUIThread {
            let host = GTKRenderer.running {
                VStack {
                    Button("Save")
                        .fontSize(20)
                        .fontWeight(.bold)
                        .textColor(Color(hex: 0xFFFFFF))
                        .background(Color(hex: 0x0000FF))
                        .stroke(Color(hex: 0xFF0000))
                        .lineWidth(2)
                        .shape(.roundedRectangle(10))
                        .padding(horizontal: 16, vertical: 11)
                }
            }
            let button = try XCTUnwrap(host.views(GTKButtonView.self).first)
            let label = try XCTUnwrap(gtk_button_get_child(button.widget.of(GtkButton.self)))
            let said = try XCTUnwrap(gtk_label_get_attributes(label.opaque)).kinds
            host.layOut()
            let (width, height) = (button.frame.width, button.frame.height)

            XCTAssertTrue(said.contains(PANGO_ATTR_SIZE.rawValue), "the font's size, in points the text scale applies to")
            XCTAssertTrue(said.contains(PANGO_ATTR_WEIGHT.rawValue), "bold")
            XCTAssertTrue(said.contains(PANGO_ATTR_FOREGROUND.rawValue), "the words' color")
            XCTAssertNotEqual(gtk_widget_has_css_class(button.widget, "stateui-box-f0000FFFF-sFF0000FF-w2-r10"), 0)
            XCTAssertNotEqual(gtk_widget_has_css_class(button.widget, "stateui-padding-11-16-11-16"), 0)
            let fill = try XCTUnwrap(button.pixels(at: [(8, height / 2)]).first)
            XCTAssertTrue(near(fill, 0xFF00_00FF), "filled in the fill, \(width) by \(height): \(String(fill, radix: 16))")
        }
    }

    /// A button opening a menu and a split button wear their box as one face: the fill from edge to edge, no button
    /// of the theme's standing inside it.
    func testAMenuButtonsBoxIsOneFace() {
        onUIThread {
            let host = GTKRenderer.running {
                VStack {
                    Button("Share").menu { MenuItem("Mail") }
                        .background(Color(hex: 0x0000FF))
                        .padding(horizontal: 16, vertical: 11)
                    Button("Save").onClicked {}.menu { MenuItem("Save as") }
                        .background(Color(hex: 0x0000FF))
                        .padding(horizontal: 16, vertical: 11)
                }
                .horizontalAlignment(.start)
            }
            host.layOut()
            for button in host.views(GTKButtonView.self) {
                let height = button.frame.height
                // At the edge, then inside the room the padding keeps above the words and below them.
                let middle = button.frame.width / 2
                let colors = button.pixels(at: [(3, height / 2), (middle, 13), (middle, height - 13)])
                let said = "\(button.text): \(colors.map { String($0, radix: 16) })"
                XCTAssertTrue(near(colors[0], 0xFF00_00FF), said)
                // The theme's button would lighten its own part of the face.
                for color in colors.dropFirst() {
                    for shift: UInt32 in [0, 8, 16, 24] {
                        XCTAssertLessThanOrEqual(abs(Int(color >> shift & 0xFF) - Int(colors[0] >> shift & 0xFF)), 3, said)
                    }
                }
            }
        }
    }

    /// A button holding a menu stands as tall as a plain one beside it, the platform's own or the same box and
    /// padding given to each.
    func testAMenuButtonStandsAsTallAsAPlainOne() {
        onUIThread {
            let host = GTKRenderer.running {
                HStack {
                    Button("Go").onClicked {}
                    Button("Share").menu { MenuItem("Mail") }
                    Button("Save").onClicked {}.menu { MenuItem("Save as") }
                    Button("Go").onClicked {}.background(Color(hex: 0x0000FF)).lineWidth(0).shape(.roundedRectangle(10))
                        .padding(horizontal: 16, vertical: 11)
                    Button("Share").menu { MenuItem("Mail") }
                        .background(Color(hex: 0x0000FF)).lineWidth(0).shape(.roundedRectangle(10))
                        .padding(horizontal: 16, vertical: 11)
                    Button("Save").onClicked {}.menu { MenuItem("Save as") }
                        .background(Color(hex: 0x0000FF)).lineWidth(0).shape(.roundedRectangle(10))
                        .padding(horizontal: 16, vertical: 11)
                }
                .horizontalAlignment(.start)
                .verticalAlignment(.start)
            }
            host.layOut()
            let heights = host.views(GTKButtonView.self).map(\.frame.height)
            XCTAssertEqual(Set(heights.prefix(3)).count, 1, "the platform's own: \(heights)")
            XCTAssertEqual(Set(heights.suffix(3)).count, 1, "with a box and padding: \(heights)")
        }
    }

    /// A see-through button draws its outline alone: nothing inside it, neither a fill nor a shadow.
    func testASeeThroughButtonDrawsOnlyItsOutline() throws {
        try onUIThread {
            let host = GTKRenderer.running {
                VStack {
                    Button("Quiet")
                        .background(Color(red: 0, green: 0, blue: 0, alpha: 0))
                        .stroke(Color(hex: 0xFFFFFF))
                        .lineWidth(2)
                        .shape(.roundedRectangle(8))
                        .padding(horizontal: 16, vertical: 11)
                }
            }
            let button = try XCTUnwrap(host.views(GTKButtonView.self).first)
            host.layOut()
            let height = button.frame.height

            let (edge, inside) = try (XCTUnwrap(button.pixels(at: [(0.5, height / 2)]).first),
                                      XCTUnwrap(button.pixels(at: [(6, height / 2)]).first))
            XCTAssertTrue(near(edge, 0xFFFF_FFFF), "its outline: \(String(edge, radix: 16))")
            XCTAssertEqual(inside >> 24, 0, "nothing inside: \(String(inside, radix: 16))")
        }
    }

    /// A wide button's picture stands beside its words in its middle, as a narrow one's does: the two are centered
    /// together, never laid from its leading edge.
    func testAWideButtonsPictureStandsBesideItsWordsInItsMiddle() throws {
        try onUIThread {
            let host = GTKRenderer.running {
                VStack { Button("Media").icon(ImageSource("test_dot.png")).horizontalAlignment(.fill) }
            }
            let button = try XCTUnwrap(host.views(GTKButtonView.self).first)
            let picture = try XCTUnwrap(button.picture?.widget)
            let words = try XCTUnwrap(button.captionLabel.map { GTKWidget($0) })
            host.settle { button.frame.width > 200 }

            var (left, right) = (graphene_rect_t(), graphene_rect_t())
            XCTAssertNotEqual(gtk_widget_compute_bounds(picture, button.widget, &left), 0)
            XCTAssertNotEqual(gtk_widget_compute_bounds(words, button.widget, &right), 0)
            let middle = Double(left.origin.x + right.origin.x + right.size.width) / 2
            let room = Double(gtk_widget_get_width(button.widget))
            XCTAssertEqual(middle, room / 2, accuracy: 1, "the picture \(left) and the words \(right) across \(room)")
        }
    }

    /// A button with a picture is named by its words, shown or out of sight: no label GTK made for its words before
    /// the picture came still names it.
    func testAButtonWithAPictureIsNamedByItsWords() throws {
        try onUIThread {
            let host = GTKRenderer.running {
                VStack {
                    Button("Media").icon(ImageSource("test_dot.png")).showsText(false)
                    Button("Layout").icon(ImageSource("test_dot.png"))
                }
            }
            let buttons = host.views(GTKButtonView.self)
            XCTAssertEqual(buttons.count, 2)
            for button in buttons {
                XCTAssertEqual(
                    gtk_test_accessible_has_relation(button.widget.opaque, GTK_ACCESSIBLE_RELATION_LABELLED_BY), 0,
                    "no label let go names \(button.text)")
            }
            let alone = stateui_test_accessible_property_is_words(
                UnsafeMutableRawPointer(buttons[0].widget.opaque), Int32(GTK_ACCESSIBLE_PROPERTY_LABEL.rawValue), "Media")
            XCTAssertNil(alone.map { String(cString: $0) }, "the picture alone named by its words out of sight")
            g_free(alone)
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
