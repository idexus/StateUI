// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIWinUI
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIWinUI
@testable import StateUIWinUIDriver
import XCTest

/// WinUI's own ItemsView under the host: a list measured in the room it stands in.
final class WinUIItemsViewTests: XCTestCase {
    /// A list whose window is widened and narrowed stands at each new width: a layout WinUI cannot settle ends the
    /// process. Every width fits a screen of 1024 x 768, where a larger window is cut to the screen.
    func testAListWhoseWindowChangesItsWidthSettles() throws {
        try onUIThread {
            let host = WinUIRenderer.running {
                Grid {
                    ItemsView(0..<1_000) { number in
                        HStack {
                            Text("\(number)").width(90)
                            Text("\(number * number)")
                        }
                        .padding(horizontal: 14, vertical: 10)
                    }
                    .header { Text("N and N²").padding(horizontal: 14, vertical: 8) }
                    .gridRow(0)

                    Text("Tap a row.").gridRow(1)
                }
                .rows(.fill, .automatic)
            }
            let list = try XCTUnwrap(host.views(WinUIItemsView.self).first)
            let window = try XCTUnwrap(host.window)

            for (width, height) in [(750.0, 600.0), (1000.0, 700.0), (650.0, 500.0), (900.0, 650.0)] {
                window.request(WindowFrame(width: width, height: height))
                host.settle(until: { abs(list.laidOutFrame.width - width) < 0.5 })
                XCTAssertEqual(list.laidOutFrame.width, width, accuracy: 0.5, "the list stands as wide as its window")
            }
        }
    }

    /// Narrator reads a row by its container's name alone: each row is named by what its item says, and named again
    /// as that changes.
    func testARowIsNamedByWhatItsItemSays() throws {
        try onUIThread {
            let doubled = State(wrappedValue: false)
            let host = WinUIRenderer.running {
                ItemsView(0..<50) { number in
                    HStack {
                        Text("\(number)")
                        Text("\(doubled.wrappedValue ? number * 2 : number * number)")
                    }
                }
                .height(300)
            }
            let list = try XCTUnwrap(host.views(WinUIItemsView.self).first)
            host.settle { Self.rowName(list, 3) == "3, 9" }
            XCTAssertEqual(Self.rowName(list, 3), "3, 9")

            doubled.wrappedValue = true
            host.settle { Self.rowName(list, 3) == "3, 6" }
            XCTAssertEqual(Self.rowName(list, 3), "3, 6", "named again")
        }
    }

    /// A list that comes back into the window - its tab chosen again - hears its scroller once: its handlers hang on
    /// a scroller once, however often WinUI loads the list.
    func testAListHearsItsScrollerOnceHoweverOftenItComesBack() throws {
        try onUIThread {
            let tab = State(wrappedValue: 0)
            let host = WinUIRenderer.running {
                TabView([0, 1]) { number in
                    if number == 0 {
                        ItemsView(0..<50) { Text("\($0)") }.title("List")
                    } else {
                        Text("Other").title("Other")
                    }
                }
                .selection(tab.projectedValue)
            }
            let list = try XCTUnwrap(host.views(WinUIItemsView.self).first)
            host.settle { stateui_winui_items_scroller_handlers(list.list.handle) == 1 }
            XCTAssertEqual(stateui_winui_items_scroller_handlers(list.list.handle), 1)

            for _ in 0..<3 {
                tab.wrappedValue = 1
                host.settle { !stateui_winui_is_loaded(list.list.handle) }
                XCTAssertFalse(stateui_winui_is_loaded(list.list.handle), "out of the window with its tab")
                tab.wrappedValue = 0
                host.settle { stateui_winui_is_loaded(list.list.handle) }
            }
            XCTAssertEqual(stateui_winui_items_scroller_handlers(list.list.handle), 1, "one set, not one a load")
        }
    }

    /// A native choice keeps each authored string whole: an empty identity and a line feed are values too.
    func testNativeSelectionKeepsEachAuthoredStringIdentityWhole() throws {
        try onUIThread {
            let chosen = State<Set<String>>(wrappedValue: [])
            var heard: [Set<String>] = []
            let driver = WinUIDriver()
            defer { driver.close() }
            _ = driver.start(clock: nil, reducesMotion: true) {
                ItemsView(Self.choiceIdentities) { identity in
                    Text(identity.isEmpty ? "empty item" : identity)
                }
                .selection(chosen.projectedValue)
                .onSelectionChanged { heard.append(chosen.wrappedValue) }
                .height(360)
            }
            let host = try XCTUnwrap(driver.renderer)
            let list = try XCTUnwrap(host.views(WinUIItemsView.self).first)
            XCTAssertEqual(list.cells.identities, Self.choiceIdentities, "distinct authored strings reached the host whole")

            let choices: [[String]] = [["ordinary"], ["a\nb"], [""], ["a\nb", ""], []]
            for wanted in choices {
                chosen.wrappedValue = Set(wanted)
                host.settle { list.selectedForTesting == wanted }
                XCTAssertEqual(list.selectedForTesting, wanted, "native choice for \(wanted.debugDescription)")
                XCTAssertEqual(chosen.wrappedValue, Set(wanted), "a program's write is not a user report")
            }
            XCTAssertEqual(heard, [], "program selection raises no user event")
        }
    }

    /// WinUI's SelectionChanged reaches the same state and event without splitting or dropping an identity.
    func testNativeSelectionReportsEachAuthoredStringIdentityWhole() throws {
        try onUIThread {
            let chosen = State<Set<String>>(wrappedValue: [])
            var heard: [Set<String>] = []
            let driver = WinUIDriver()
            defer { driver.close() }
            _ = driver.start(clock: nil, reducesMotion: true) {
                ItemsView(Self.choiceIdentities) { identity in
                    Text(identity.isEmpty ? "empty item" : identity)
                }
                .selection(chosen.projectedValue)
                .onSelectionChanged { heard.append(chosen.wrappedValue) }
                .height(360)
            }
            let host = try XCTUnwrap(driver.renderer)
            let list = try XCTUnwrap(host.views(WinUIItemsView.self).first)
            XCTAssertEqual(list.cells.identities, Self.choiceIdentities)

            for place in 0..<3 {
                chosen.wrappedValue = []
                host.settle { list.selectedForTesting.isEmpty }
                heard = []
                let wanted: Set<String> = [Self.choiceIdentities[place]]

                list.chooseForTesting(place)
                host.settle { chosen.wrappedValue == wanted && !heard.isEmpty }

                XCTAssertEqual(chosen.wrappedValue, wanted, "native event for \(Self.choiceIdentities[place].debugDescription)")
                XCTAssertEqual(heard, [wanted], "the event is heard once, the state holding exactly the chosen item")
                XCTAssertEqual(list.selectedForTesting, [Self.choiceIdentities[place]], "the same item stays chosen natively")
            }
        }
    }

    private static let choiceIdentities = ["ordinary", "a\nb", "", "a", "b"]

    /// What Narrator calls the row at `position`; nil where no cell holds it.
    @MainActor
    private static func rowName(_ list: WinUIItemsView, _ position: Int) -> String? {
        let ids = list.cells.entries.sections.flatMap(\.items)
        guard ids.indices.contains(position), let cell = list.cells.holding(of: ids[position]) as? WinUIItemCell else { return nil }
        var bytes = [CChar](repeating: 0, count: 256)
        let length = stateui_winui_items_row_name(list.list.handle, cell.number, &bytes, Int32(bytes.count))
        return String(decoding: bytes.prefix(Int(max(length, 0))).map { UInt8(bitPattern: $0) }, as: UTF8.self)
    }
}
