// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) @testable import StateUI
@testable import StateUIAppKit
import XCTest

final class AppKitContextMenuTests: XCTestCase {
    @MainActor
    func testAViewOwnsItsNativeNestedContextMenuAndDispatchesTheChosenItem() throws {
        var reports: [(Int32, [HostValue])] = []
        let renderer = AppKitRenderer(
            resourceDirectory: nil,
            presentsWindows: false,
            eventSink: { reports.append(($0, $1)) })
        defer { renderer.closeForTesting() }

        var duplicate = HostPatch(id: .manual("duplicate"), type: .menuItem)
        duplicate.properties[.text] = .string("Duplicate")
        duplicate.events = .replace([.clicked: 40])
        let separator = HostPatch(id: .manual("separator"), type: .menuSeparator)
        var top = HostPatch(id: .manual("top"), type: .menuItem)
        top.properties[.text] = .string("To the top")
        var move = HostPatch(id: .manual("move"), type: .menu)
        move.properties[.text] = .string("Move")
        move.children = .arranged([top])
        var menu = HostPatch(id: .manual("context"), type: .contextMenu)
        menu.children = .arranged([duplicate, separator, move])
        var label = HostPatch(id: .manual("row"), type: .label)
        label.properties[.text] = .string("Alpha")
        label.children = .arranged([menu])

        renderer.applyForTesting(tree(label))

        let native = try XCTUnwrap(renderer.viewForTesting(id: .manual("row")))
        let context = try XCTUnwrap(native.menu)
        XCTAssertEqual(context.items.map(\.title), ["Duplicate", "", "Move"])
        XCTAssertEqual(context.items.last?.submenu?.items.map(\.title), ["To the top"])

        context.performActionForItem(at: 0)
        XCTAssertEqual(reports.map(\.0), [40])
    }

    @MainActor
    func testSparseMenuChangesKeepItsNativeOwnerAndRemovalDetachesIt() throws {
        var reports: [Int32] = []
        let renderer = AppKitRenderer(
            resourceDirectory: nil,
            presentsWindows: false,
            eventSink: { handler, _ in reports.append(handler) })
        defer { renderer.closeForTesting() }

        var originalItem = HostPatch(id: .manual("item"), type: .menuItem)
        originalItem.properties[.text] = .string("Rename")
        originalItem.events = .replace([.clicked: 50])
        var originalMenu = HostPatch(id: .manual("context"), type: .contextMenu)
        originalMenu.children = .arranged([originalItem])
        var originalLabel = HostPatch(id: .manual("row"), type: .label)
        originalLabel.children = .arranged([originalMenu])
        renderer.applyForTesting(tree(originalLabel))

        let native = try XCTUnwrap(renderer.viewForTesting(id: .manual("row")))
        let nativeMenu = try XCTUnwrap(native.menu)
        let nativeItem = try XCTUnwrap(nativeMenu.items.first)

        var changedItem = HostPatch(id: .manual("item"), type: .menuItem)
        changedItem.properties[.text] = .string("Remove")
        changedItem.events = .replace([.clicked: 51])
        var changedMenu = HostPatch(id: .manual("context"), type: .contextMenu)
        changedMenu.children = .changed([changedItem])
        var changedLabel = HostPatch(id: .manual("row"), type: .label)
        changedLabel.children = .changed([changedMenu])
        renderer.applyForTesting(changedTree(changedLabel))

        XCTAssertTrue(native.menu === nativeMenu)
        XCTAssertTrue(native.menu?.items.first === nativeItem)
        XCTAssertEqual(nativeItem.title, "Remove")
        nativeMenu.performActionForItem(at: 0)
        XCTAssertEqual(reports, [51])

        var withoutMenu = HostPatch(id: .manual("row"), type: .label)
        withoutMenu.children = .arranged([])
        renderer.applyForTesting(changedTree(withoutMenu))
        XCTAssertNil(native.menu)
    }
}

#endif
