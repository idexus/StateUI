// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIUIKit
import XCTest

/// A button holding a menu says so: UIKit's own indicator where a tap opens the menu, an arrow of its own where the
/// tap is the button's - UIKit draws no split button.
@MainActor
final class UIKitButtonMenuTests: XCTestCase {
    /// A button whose tap opens its menu wears an arrow pointing down after its words - a mark, the whole button
    /// taking the tap - not UIKit's up-and-down indicator, which says a choice.
    func testAButtonOpeningAMenuWearsAnArrowDown() throws {
        let host = UIKitRenderer.running {
            Button("Share").menu { MenuItem("Mail") }.padding(horizontal: 16, vertical: 8)
        }
        defer { host.finish() }

        let button = try XCTUnwrap(host.views(UIKitButtonView.self).first)
        XCTAssertTrue(button.showsMenuAsPrimaryAction)
        XCTAssertNotEqual(button.configuration?.indicator, .popup)
        button.frame = CGRect(x: 0, y: 0, width: 140, height: 44)
        button.layoutIfNeeded()
        let arrow = try XCTUnwrap(button.subviews.compactMap { $0 as? UIButton }.first)
        XCTAssertFalse(arrow.isUserInteractionEnabled, "the button takes the tap")
        XCTAssertNil(arrow.menu)
        XCTAssertEqual(arrow.frame.maxX, button.bounds.maxX - 16, accuracy: 0.5, "inside the padding: \(arrow.frame)")
    }

    /// A split button's tap is its own, and an arrow at its trailing edge - a button of its own, inside the room the
    /// button keeps for it - opens the menu with a tap.
    func testASplitButtonsArrowOpensItsMenu() throws {
        let host = UIKitRenderer.running {
            Button("Save").onClicked {}.menu {
                MenuItem("Save as")
                MenuItem("Save a copy")
            }
        }
        defer { host.finish() }

        let button = try XCTUnwrap(host.views(UIKitButtonView.self).first)
        XCTAssertFalse(button.showsMenuAsPrimaryAction, "the tap is the button's own")
        button.frame = CGRect(x: 0, y: 0, width: 160, height: 44)
        button.layoutIfNeeded()
        let arrow = try XCTUnwrap(button.subviews.compactMap { $0 as? UIButton }.first { $0.menu != nil })
        XCTAssertTrue(arrow.showsMenuAsPrimaryAction)
        XCTAssertEqual(arrow.menu?.children.map(\.title), ["Save as", "Save a copy"])
        XCTAssertEqual(arrow.frame.maxX, button.bounds.maxX, accuracy: 0.5, "\(arrow.frame)")
        XCTAssertGreaterThanOrEqual(
            button.configuration?.contentInsets.trailing ?? 0, arrow.frame.width, "the words keep clear of the arrow")
    }

    /// A held button keeps its tap and offers its menu as UIKit opens a button's held, with no arrow; a button whose
    /// tap opens its menu may leave its arrow out.
    func testAHeldButtonAndAButtonWithoutItsArrow() throws {
        let host = UIKitRenderer.running {
            VStack {
                Button("Save").onClicked {}.menu(.held) { MenuItem("Save as") }
                Button().icon(.icon(.more)).menu { MenuItem("Mail") }.showsMenuArrow(false)
            }
        }
        defer { host.finish() }

        let buttons = host.views(UIKitButtonView.self)
        XCTAssertFalse(buttons[0].showsMenuAsPrimaryAction, "the tap is the button's own")
        XCTAssertEqual(buttons[0].menu?.children.map(\.title), ["Save as"], "the menu held")
        XCTAssertFalse(buttons[0].subviews.contains { $0 is UIButton }, "no arrow")
        XCTAssertTrue(buttons[1].showsMenuAsPrimaryAction)
        XCTAssertFalse(buttons[1].subviews.contains { $0 is UIButton }, "the arrow left out")
    }

    /// An icon alone opening a menu is placed with room for its arrow, which stands clear of the picture.
    func testAnIconAlonesArrowStandsClearOfIt() throws {
        let shows = State(wrappedValue: true)
        let host = UIKitRenderer.running {
            HStack {
                Button().icon(.icon(.more)).menu { MenuItem("Mail") }.showsMenuArrow(shows.wrappedValue)
                    .background(Color(hex: 0x8E6BF0)).shape(.capsule).padding(horizontal: 16, vertical: 11)
                Button().icon(.icon(.more)).menu { MenuItem("Mail") }.showsMenuArrow(false)
                    .background(Color(hex: 0x8E6BF0)).shape(.capsule).padding(horizontal: 16, vertical: 11)
                Switch(shows.projectedValue)
            }
            .horizontalAlignment(.start)
            .verticalAlignment(.start)
        }
        defer { host.finish() }
        host.layOut()

        let buttons = host.views(UIKitButtonView.self)
        let (with, without) = (buttons[0].frame.size, buttons[1].frame.size)
        XCTAssertEqual(with.width - without.width, 18, accuracy: 0.5, "the mark's room: \(with) and \(without)")
        let arrow = try XCTUnwrap(buttons[0].subviews.compactMap { $0 as? UIButton }.first)
        let picture = try XCTUnwrap(buttons[0].imageView)
        XCTAssertLessThanOrEqual(picture.frame.maxX, arrow.frame.minX, "\(picture.frame) beside \(arrow.frame)")
    }

    /// Taking a view's context menu away leaves the button's own menu standing: UIKit opens it through an
    /// interaction of the button's own.
    func testTakingAContextMenuAwayLeavesTheButtonsOwnMenu() throws {
        let offered = State(wrappedValue: true)
        let host = UIKitRenderer.running {
            Button("Share").menu { MenuItem("Mail") }
                .contextMenu { if offered.wrappedValue { MenuItem("Copy") } }
        }
        defer { host.finish() }
        let button = try XCTUnwrap(host.views(UIKitButtonView.self).first)
        let own = try XCTUnwrap(button.contextMenuInteraction, "the button's own")
        XCTAssertEqual(button.interactions.filter { $0 is UIContextMenuInteraction }.count, 2, "and the view's")

        offered.wrappedValue = false
        host.settle { button.interactions.filter { $0 is UIContextMenuInteraction }.count < 2 }

        XCTAssertTrue(button.interactions.contains { $0 === own }, "the button's own menu stays")
    }

    /// Taking a picker's context menu away leaves the picker opening its choices: UIKit opens them through an
    /// interaction of the picker's own, made once.
    func testTakingAContextMenuAwayLeavesThePickerOpening() throws {
        let offered = State(wrappedValue: true)
        let size = State<String?>(wrappedValue: nil)
        let host = UIKitRenderer.running {
            Picker(["Small", "Large"], selection: size.projectedValue)
                .contextMenu { if offered.wrappedValue { MenuItem("Copy") } }
        }
        defer { host.finish() }
        let picker = try XCTUnwrap(host.views(UIKitPickerView.self).first)
        let own = try XCTUnwrap(picker.contextMenuInteraction, "the picker's own")

        offered.wrappedValue = false
        host.settle { picker.interactions.filter { $0 is UIContextMenuInteraction && $0 !== own }.isEmpty }

        XCTAssertTrue(picker.interactions.contains { $0 === own }, "the picker still opens its choices")
        XCTAssertTrue(picker.interactions.filter { $0 is UIContextMenuInteraction && $0 !== own }.isEmpty)
    }
}
