// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@testable import StateUIAppKit
import XCTest

/// The menu bar an AppKit application stands with.
final class AppKitMenuBarTests: XCTestCase {
    /// Edit holds the text commands a field answers - AppKit routes ⌘C, ⌘V and ⌘Z through the menu bar's key
    /// equivalents, so without them a field copies, pastes and undoes nothing.
    @MainActor
    func testTheMenuBarHoldsTheTextCommandsAFieldAnswers() throws {
        let main = StateUIAppKit.mainMenu(newScene: nil)
        XCTAssertEqual(main.items.map(\.title).dropFirst(), ["File", "Edit", "Window"])

        let edit = try XCTUnwrap(main.item(withTitle: "Edit")?.submenu)
        let commands = edit.items.filter { !$0.isSeparatorItem }.map { item in
            let shift = item.keyEquivalentModifierMask.contains(.shift) ? "⇧" : ""
            return "\(shift)\(item.keyEquivalent) \(item.action.map(NSStringFromSelector) ?? "")"
        }
        XCTAssertEqual(commands, ["z undo:", "⇧z redo:", "x cut:", "c copy:", "v paste:", " delete:", "a selectAll:"])
    }
}
#endif
