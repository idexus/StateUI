// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) @testable import StateUI
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
    func testProgramWritesAreSilentAndUserChoiceReportsOnce() {
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
    func testUserMenuLifecycleReportsOpenThenClose() {
        let picker = AppKitPickerView()
        let menu = NSMenu()
        var events: [String] = []
        picker.onOpened = { events.append("opened") }
        picker.onClosed = { events.append("closed") }

        picker.menuWillOpen(menu)
        picker.menuDidClose(menu)

        XCTAssertEqual(events, ["opened", "closed"])
    }

    /// The captions a picker offers become its native items, whether its
    /// initializer or its modifier gave them.
    @MainActor
    func testAPickersOptionsComeThroughTheHost() throws {
        let renderer = AppKitRenderer.running {
            VStack {
                Picker(["Small", "Medium", "Large"])
                Picker().options(["One", "Two"])
            }
        }
        defer { renderer.closeForTesting() }
        let pickers = renderer.nativeViews(AppKitPickerView.self)

        XCTAssertEqual(
            pickers.map { $0.itemTitles }, [["Small", "Medium", "Large"], ["One", "Two"]])
    }

    /// The item a user chooses reaches the page's `onSelectedIndexChanged`
    /// as its index.
    @MainActor
    func testTheUsersChoiceReachesThePickersHandler() throws {
        let chosen = Received<Int>()
        let renderer = AppKitRenderer.running {
            Picker(["Small", "Medium", "Large"])
                .onSelectedIndexChanged { chosen.values.append($0) }
        }
        defer { renderer.closeForTesting() }
        let picker = try XCTUnwrap(renderer.nativeViews(AppKitPickerView.self).first)

        picker.chooseForTesting(index: 2)

        XCTAssertEqual(chosen.values, [2])
    }

    /// A picker told to open asks its native menu to open, once it stands in a
    /// window. The test stands in for the pop-up button's click, whose menu
    /// tracking would hold the run loop until a user ended it.
    @MainActor
    func testAPickerToldToOpenOpensItsNativeMenu() throws {
        var opened: [AppKitPickerView] = []
        AppKitPickerView.opensMenuForTesting = { opened.append($0) }
        defer { AppKitPickerView.opensMenuForTesting = nil }

        let renderer = AppKitRenderer.running {
            Picker(["Small", "Medium", "Large"]).isOpen(true)
        }
        defer { renderer.closeForTesting() }
        let picker = try XCTUnwrap(renderer.nativeViews(AppKitPickerView.self).first)

        let deadline = Date(timeIntervalSinceNow: 1)
        while opened.isEmpty, Date() < deadline {
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.01))
        }

        XCTAssertEqual(opened.count, 1)
        XCTAssertTrue(opened.first === picker)
    }

    /// Where a picker's text stands reaches its native pop-up button and each
    /// of its items.
    @MainActor
    func testAPickersTextAlignmentComesThroughTheHost() throws {
        let renderer = testRenderer(resourceDirectory: nil, presentsWindows: false)
        defer { renderer.closeForTesting() }
        var picker = HostPatch(id: .manual("picker"), type: .picker)
        picker.properties = [
            .options: .strings(["One", "Two"]),
            .horizontalTextAlignment: .enumeration(TextAlignment.center.rawValue),
        ]
        renderer.applyForTesting(tree(picker))

        let native = try XCTUnwrap(renderer.viewForTesting(id: .manual("picker")))
        let button = try XCTUnwrap(native.subviews.compactMap { $0 as? NSPopUpButton }.first)
        XCTAssertEqual(button.alignment, .center)
        XCTAssertEqual(
            button.itemArray.map {
                ($0.attributedTitle?.attribute(.paragraphStyle, at: 0, effectiveRange: nil)
                    as? NSParagraphStyle)?.alignment
            },
            [.center, .center])
    }
}

#endif
