// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
import XCTest

/// How every host takes a menu's entry chosen: a setting's turns the other way from how it stands, one that acts is
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
            entry("checked", .menuToggle, on: true), entry("unchecked", .menuToggle, on: false),
            entry("plain", .menuItem, on: nil),
        ])
        var root = HostPatch(id: .manual("root"), type: .text)
        root.children = .arranged([menu])
        runtime.tree.apply(root, complete: true)
        let entries = try XCTUnwrap(runtime.tree.root?.first(id: .manual("menu")))

        XCTAssertEqual(entries.first(id: .manual("checked"))?.turnsWhenChosen, false)
        XCTAssertEqual(entries.first(id: .manual("unchecked"))?.turnsWhenChosen, true)
        XCTAssertNil(entries.first(id: .manual("plain"))?.turnsWhenChosen, "an entry that acts is clicked")
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
            save, HostPatch(id: .manual("plain"), type: .menuItem),
            HostPatch(id: .manual("line"), type: .menuSeparator),
        ])
        var root = HostPatch(id: .manual("root"), type: .text)
        root.children = .arranged([menu])
        runtime.tree.apply(root, complete: true)
        let entries = try XCTUnwrap(runtime.tree.root?.first(id: .manual("menu")))

        XCTAssertEqual(
            MenuEntry.entries(of: entries).map(\.keyboardShortcut),
            [KeyboardShortcut("s", modifiers: [.primary, .shift]), nil, nil])
    }

    /// What an entry says changes with anything it shows - its check, its destructive mark, its picture, its words -
    /// and with the element it answers, which an entry standing in another's place with the same words does not.
    func testWhatAnEntrySaysIsAllItShowsAndTheElementItAnswers() throws {
        let runtime = HostRuntime.still()
        func tree(_ properties: [Prop: HostValue], id: String = "save") -> [MenuEntry.Said] {
            var save = HostPatch(id: .manual(id), type: .menuItem)
            save.properties = [.text: .string("Save")].merging(properties) { $1 }
            var menu = HostPatch(id: .manual("menu"), type: .contextMenu)
            menu.children = .arranged([save])
            var root = HostPatch(id: .manual("root"), type: .text)
            root.children = .arranged([menu])
            runtime.tree.apply(root, complete: true)
            return MenuEntry.entries(of: runtime.tree.root!.first(id: .manual("menu"))!).map(\.said)
        }
        let plain = tree([:])

        XCTAssertEqual(tree([:]), plain, "the same entry says the same")
        XCTAssertNotEqual(tree([.isOn: .bool(true)]), plain, "checked")
        XCTAssertNotEqual(tree([.role: ActionRole.destructive.propValue]), plain, "marked destructive")
        XCTAssertNotEqual(tree([.icon: .string("save.png")]), plain, "with a picture")
        XCTAssertNotEqual(tree([.text: .string("Keep")]), plain, "in other words")
        _ = tree([:])
        XCTAssertNotEqual(tree([:], id: "keep"), plain, "the same words answering another element")
    }
}
