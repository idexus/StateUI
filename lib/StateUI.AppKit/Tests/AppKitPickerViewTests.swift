// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@testable import StateUIAppKit
import XCTest

final class AppKitPickerViewTests: XCTestCase {
    @MainActor
    func testItemsPlaceholderAndSelectionFormOneNativeSnapshot() {
        let picker = AppKitPickerView()

        picker.apply(
            items: ["Small", "Medium", "Large"],
            selectedIndex: 1,
            writeSelection: true,
            title: "Size",
            font: .systemFont(ofSize: 15),
            textColor: .systemPurple,
            tint: .systemOrange,
            alignment: .center,
            enabled: false,
            open: false,
            writeOpen: false)

        XCTAssertEqual(picker.itemTitles, ["Small", "Medium", "Large"])
        XCTAssertEqual(picker.indexOfSelectedItem, 1)
        XCTAssertEqual(picker.titleOfSelectedItem, "Medium")
        XCTAssertEqual(picker.font?.pointSize, 15)
        XCTAssertFalse(picker.isEnabled)
        XCTAssertEqual(picker.contentTintForTesting, .systemOrange)
    }

    @MainActor
    func testNoSelectionUsesTheTitleWithoutInventingAnItem() {
        let picker = AppKitPickerView()

        picker.apply(
            items: ["One", "Two"],
            selectedIndex: -1,
            writeSelection: true,
            title: "Choose",
            font: .systemFont(ofSize: 13),
            textColor: .labelColor,
            tint: .systemOrange,
            alignment: .natural,
            enabled: true,
            open: false,
            writeOpen: false)

        XCTAssertEqual(picker.itemTitles, ["One", "Two"])
        XCTAssertEqual(picker.indexOfSelectedItem, -1)
        XCTAssertEqual(picker.title, "Choose")
    }

    @MainActor
    func testProgramWritesAreSilentAndReaderChoiceReportsOnce() {
        let picker = AppKitPickerView()
        var selections: [Int] = []
        picker.onSelectionChanged = { selections.append($0) }

        picker.apply(
            items: ["One", "Two", "Three"],
            selectedIndex: 0,
            writeSelection: true,
            title: nil,
            font: .systemFont(ofSize: 13),
            textColor: .labelColor,
            tint: nil,
            alignment: .natural,
            enabled: true,
            open: false,
            writeOpen: false)
        picker.chooseForTesting(index: 2)

        XCTAssertEqual(selections, [2])
        XCTAssertEqual(picker.indexOfSelectedItem, 2)
    }

    @MainActor
    func testReplacingItemsClampsAnInvalidSelectionToNone() {
        let picker = AppKitPickerView()
        picker.apply(
            items: ["One", "Two", "Three"],
            selectedIndex: 2,
            writeSelection: true,
            title: nil,
            font: .systemFont(ofSize: 13),
            textColor: .labelColor,
            tint: nil,
            alignment: .natural,
            enabled: true,
            open: false,
            writeOpen: false)

        picker.apply(
            items: ["Only"],
            selectedIndex: 2,
            writeSelection: false,
            title: "Choose",
            font: .systemFont(ofSize: 13),
            textColor: .labelColor,
            tint: nil,
            alignment: .natural,
            enabled: true,
            open: false,
            writeOpen: false)

        XCTAssertEqual(picker.indexOfSelectedItem, -1)
        XCTAssertEqual(picker.title, "Choose")
    }

    @MainActor
    func testReaderMenuLifecycleReportsOpenThenClose() {
        let picker = AppKitPickerView()
        let menu = NSMenu()
        var events: [String] = []
        picker.onOpened = { events.append("opened") }
        picker.onClosed = { events.append("closed") }

        picker.menuWillOpen(menu)
        picker.menuDidClose(menu)

        XCTAssertEqual(events, ["opened", "closed"])
    }
}

#endif
