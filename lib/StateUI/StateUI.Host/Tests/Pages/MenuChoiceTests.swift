// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
import XCTest

/// How every host takes a menu's entry chosen: one standing checked or not turns the other way, any other is only
/// clicked.
@MainActor
final class MenuChoiceTests: XCTestCase {
    func testAnEntryChosenTurnsTheOtherWayFromHowItStands() throws {
        let runtime = HostRuntime.still()
        func entry(_ id: String, _ type: NodeType, on: Bool?) -> HostPatch {
            var entry = HostPatch(id: .manual(id), type: type)
            if let on { entry.properties = [.isOn: .bool(on)] }
            return entry
        }
        var menu = HostPatch(id: .manual("menu"), type: .contextMenu)
        menu.children = .arranged([
            entry("checked", .menuItem, on: true), entry("unchecked", .menuItem, on: false),
            entry("plain", .menuItem, on: nil),
        ])
        var root = HostPatch(id: .manual("root"), type: .text)
        root.children = .arranged([menu])
        runtime.tree.apply(root, complete: true)
        let entries = try XCTUnwrap(runtime.tree.root?.first(id: .manual("menu")))

        XCTAssertEqual(entries.first(id: .manual("checked"))?.turnsWhenChosen, false)
        XCTAssertEqual(entries.first(id: .manual("unchecked"))?.turnsWhenChosen, true)
        XCTAssertNil(entries.first(id: .manual("plain"))?.turnsWhenChosen, "an entry standing neither way is only clicked")
        XCTAssertEqual(MenuEntry.entries(of: entries).map(\.isOn), [true, false, nil])
    }

    /// An entry carries the shortcut its item states, for a host to show beside its words; a submenu and a line carry
    /// none.
    func testAnEntryCarriesItsItemsShortcut() throws {
        let runtime = HostRuntime.still()
        var save = HostPatch(id: .manual("save"), type: .menuItem)
        save.properties = [.keyboardShortcut: KeyboardShortcut("s", modifiers: [.primary, .shift]).propValue]
        var menu = HostPatch(id: .manual("menu"), type: .contextMenu)
        menu.children = .arranged([
            save, HostPatch(id: .manual("plain"), type: .menuItem), HostPatch(id: .manual("line"), type: .divider),
        ])
        var root = HostPatch(id: .manual("root"), type: .text)
        root.children = .arranged([menu])
        runtime.tree.apply(root, complete: true)
        let entries = try XCTUnwrap(runtime.tree.root?.first(id: .manual("menu")))

        XCTAssertEqual(
            MenuEntry.entries(of: entries).map(\.keyboardShortcut),
            [KeyboardShortcut("s", modifiers: [.primary, .shift]), nil, nil])
    }
}
