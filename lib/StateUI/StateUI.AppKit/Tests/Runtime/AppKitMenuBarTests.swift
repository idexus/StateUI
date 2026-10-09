// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI
@testable import StateUIAppKit
import XCTest

/// The menu bar an AppKit application stands with.
@MainActor
final class AppKitMenuBarTests: XCTestCase {
    /// Edit holds the text commands a field answers - AppKit routes ⌘C, ⌘V and ⌘Z through the menu bar's key
    /// equivalents, so without them a field copies, pastes and undoes nothing.
    @MainActor
    func testTheMenuBarHoldsTheTextCommandsAFieldAnswers() throws {
        let main = StateUIAppKit.mainMenu(newWindow: nil)
        XCTAssertEqual(main.items.map(\.title).dropFirst(), ["File", "Edit", "Window"])

        let edit = try XCTUnwrap(main.item(withTitle: "Edit")?.submenu)
        let commands = edit.items.filter { !$0.isSeparatorItem }.map { item in
            let shift = item.keyEquivalentModifierMask.contains(.shift) ? "⇧" : ""
            return "\(shift)\(item.keyEquivalent) \(item.action.map(NSStringFromSelector) ?? "")"
        }
        XCTAssertEqual(commands, ["z undo:", "⇧z redo:", "x cut:", "c copy:", "v paste:", " delete:", "a selectAll:"])
    }

    /// A page's menus join the bar by identity, whatever their captions: a standard menu joins the platform's own as a
    /// section after its entries, one the platform keeps none of stands where the platform puts it, any other before
    /// Window; an entry the tree disables stays disabled there, and the bar is as it was once the menus go.
    @MainActor
    func testAPagesMenusJoinTheBarByIdentity() throws {
        let renderer = AppKitRenderer.running {
            Text("Page").menuBar {
                Menu("Plik") {
                    MenuItem("Eksportuj").id("export")
                    MenuItem("Zapisz").isEnabled(false).id("save")
                }
                .id(StandardMenu.file)
                Menu("Pomoc") { MenuItem("Podręcznik") }.id(StandardMenu.help)
                Menu("Widok") { MenuItem("Powiększ") }.id(StandardMenu.view)
                Menu("Format") { MenuItem("Pogrub") }
            }
        }
        defer { renderer.closeForTesting() }
        let main = StateUIAppKit.mainMenu(newWindow: nil)
        let controller = try XCTUnwrap(renderer.windowsForTesting.first)

        renderer.installPageMenus(controller.pageMenus, into: main)
        XCTAssertEqual(Array(main.items.map(\.title).dropFirst()), ["File", "Edit", "Widok", "Format", "Window", "Pomoc"])
        let file = try XCTUnwrap(main.items[1].submenu)
        XCTAssertEqual(file.items.map { $0.isSeparatorItem ? "-" : $0.title }, ["New Window", "-", "Eksportuj", "Zapisz"])
        file.update()
        XCTAssertEqual(file.items.suffix(2).map(\.isEnabled), [true, false], "enabled as the tree says")

        renderer.installPageMenus([], into: main)
        XCTAssertEqual(Array(main.items.map(\.title).dropFirst()), ["File", "Edit", "Window"])
        XCTAssertEqual(file.items.map(\.title), ["New Window"])
    }
}
#endif
