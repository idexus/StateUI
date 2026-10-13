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
}
