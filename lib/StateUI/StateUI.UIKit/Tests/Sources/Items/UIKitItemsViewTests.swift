// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIUIKit
import XCTest

/// Three items, the first chosen.
private struct ChoosingPage: View {
    @State private var chosen: Int? = 0

    var body: some View {
        ItemsView(0..<3) { Text("Item \($0)").padding(12) }
            .selection($chosen)
            .width(300).height(400)
    }
}

/// Mail whose items offer their actions in a context menu, each action written into `done`.
private struct MailPage: View {
    @State private var done: [String] = []

    var body: some View {
        VStack {
            Text(done.joined(separator: " ")).id("done")
            ItemsView(["mail"]) { item in
                Text(item).padding(12).contextMenu {
                    MenuItem("Archive").onClicked { done.append("archived") }
                    MenuSeparator()
                    MenuItem("Delete").role(.destructive).onClicked { done.append("deleted") }
                }
            }
            .width(300).height(400)
        }
    }
}

/// A list choosing many above one choosing one.
private struct ChoicesPage: View {
    @State private var many: Set<String> = []
    @State private var one: String?

    var body: some View {
        VStack {
            ItemsView(["a", "b"]) { Text($0).padding(12) }.selection($many).width(300).height(200)
            ItemsView(["a", "b"]) { Text($0).padding(12) }.selection($one).width(300).height(200)
        }
    }
}

@MainActor
final class UIKitItemsViewTests: XCTestCase {
    /// A tap extends a choice of many - UIKit performs no primary action there, which would choose the item alone -
    /// and opens an item of a list choosing one, as every host's tap does (`ItemsTap`).
    @MainActor
    func testATapExtendsAChoiceOfManyAndOpensAnItemElsewhere() throws {
        let host = UIKitRenderer.running { ChoicesPage() }
        defer { host.finish() }
        let lists = host.views(UIKitItemsView.self)
        let first = IndexPath(item: 0, section: 0)

        let opens = lists.map { $0.collection.delegate?.collectionView?($0.collection, canPerformPrimaryActionForItemAt: first) }

        XCTAssertEqual(lists.map(\.modeForTesting), [.multiple, .single])
        XCTAssertEqual(opens, [false, true], "a tap opens only where it changes no choice of many")
    }

    /// A list item's context menu stands as its swipe actions too - its items in order, a destructive one UIKit's
    /// destructive style - and an action swiped to runs the item's handler.
    @MainActor
    func testAnItemsContextMenuStandsAsItsSwipeActions() throws {
        let host = UIKitRenderer.running { MailPage() }
        defer { host.finish() }
        let items = try XCTUnwrap(host.views(UIKitItemsView.self).first)
        host.settle { items.collection.visibleCells.count == 1 }

        let swipe = try XCTUnwrap(items.swipeActionsForTesting("mail"), "the item swipes to its actions")
        XCTAssertEqual(swipe.actions.map(\.title), ["Archive", "Delete"])
        XCTAssertEqual(swipe.actions.map(\.style), [.normal, .destructive])
        swipe.actions[1].handler(swipe.actions[1], items.collection) { _ in }
        host.settle { host.views(UIKitTextView.self).first?.text == "deleted" }

        XCTAssertEqual(host.views(UIKitTextView.self).first?.text, "deleted", "the action ran its handler")
    }

    /// A cell at rest shows the page through it, as every host's list does; a chosen one shows the user's choice in
    /// the platform's accent, UIKit's tint, laid over the page.
    @MainActor
    func testACellAtRestHasNoBackgroundOfItsOwn() throws {
        let host = UIKitRenderer.running { ChoosingPage() }
        defer { host.finish() }
        let items = try XCTUnwrap(host.views(UIKitItemsView.self).first)
        host.settle { items.collection.visibleCells.count == 3 }

        let cells = items.collection.visibleCells.sorted { $0.frame.minY < $1.frame.minY }
        XCTAssertEqual(cells.count, 3)
        func alpha(_ cell: UICollectionViewCell) -> CGFloat {
            var alpha: CGFloat = 0
            cell.backgroundConfiguration?.resolvedBackgroundColor(for: cell.tintColor)
                .resolvedColor(with: cell.traitCollection).getRed(nil, green: nil, blue: nil, alpha: &alpha)
            return alpha
        }
        XCTAssertGreaterThan(alpha(cells[0]), 0, "the chosen item shows the choice")
        XCTAssertEqual(
            cells[0].backgroundConfiguration?.backgroundColor, cells[0].tintColor.withAlphaComponent(0.2),
            "the choice in the accent")
        XCTAssertEqual(alpha(cells[1]), 0, "an item at rest draws a background")
        XCTAssertEqual(alpha(cells[2]), 0, "an item at rest draws a background")
    }

    /// A group added before the others brings its own header, and every other group keeps its own: a group is known
    /// by its name, not its place.
    @MainActor
    func testAGroupAddedOnTopBringsItsOwnHeader() throws {
        let days = State(wrappedValue: ["Yesterday"])
        let host = UIKitRenderer.running(reducesMotion: true) {
            ItemsView(groups: days.wrappedValue.map { day in
                Section([day + " note"]) { Text($0) }.id(day).header(Text(day))
            })
            .width(300).height(400)
        }
        defer { host.finish() }
        let items = try XCTUnwrap(host.views(UIKitItemsView.self).first)
        func texts(in view: UIView) -> [String] {
            ((view as? UIKitTextView)?.attributedText?.string).map { [$0] } ?? view.subviews.flatMap(texts)
        }
        func headers() -> [String] {
            items.collection.layoutIfNeeded()
            return items.collection.visibleSupplementaryViews(ofKind: UIKitItemsLayout.header)
                .sorted { $0.frame.minY < $1.frame.minY }.map { texts(in: $0).joined() }
        }
        host.settle { headers() == ["Yesterday"] }

        days.wrappedValue = ["Today", "Yesterday"]
        host.settle { headers() == ["Today", "Yesterday"] }

        XCTAssertEqual(headers(), ["Today", "Yesterday"])
    }

    /// Every row moved one place down travels from where it stood to its new place, never above where it stood, and
    /// the list's header stands throughout: the layout keeps what it measured as the entries change.
    @MainActor
    func testRowsMovedOnePlaceDownTravelStraightUnderTheirHeader() throws {
        let numbers = State(wrappedValue: Array(0..<1_000))
        let host = UIKitRenderer.running {
            ItemsView(numbers.wrappedValue) { Text("Row \($0)").fontSize(14).padding(10) }
                .header(Text("Rows").fontSize(11).padding(8))
                .width(300).height(500)
        }
        defer { host.finish() }
        let items = try XCTUnwrap(host.views(UIKitItemsView.self).first)
        let collection = items.collection
        func drawn() -> [String: CGFloat] {
            Dictionary(uniqueKeysWithValues: collection.visibleCells.compactMap { cell in
                (cell as? UIKitItemCell)?.holding.identity.map { ($0, (cell.layer.presentation() ?? cell.layer).frame.minY) }
            })
        }
        func header() -> UIKitItemSupplement? {
            collection.visibleSupplementaryViews(ofKind: UIKitItemsLayout.listHeader).first as? UIKitItemSupplement
        }
        host.settle {
            collection.visibleCells.count > 5
                && collection.visibleCells.allSatisfy { ($0 as? UIKitItemCell)?.holding.shown != nil }
        }
        collection.layoutIfNeeded()
        let stood = drawn().filter { Int($0.key)! < 6 }

        numbers.wrappedValue = [999] + Array(0..<999)
        var astray: [String] = []
        for step in 0..<40 {
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.01))
            host.runtime.pump.turn()
            let now = drawn()
            for (row, before) in stood.sorted(by: { $0.key < $1.key }) where (now[row] ?? before) < before - 0.5 {
                astray.append("step \(step): row \(row) drawn at \(now[row]!), above \(before)")
            }
            if header()?.holding.shown == nil { astray.append("step \(step): no header") }
        }

        XCTAssertEqual(astray, [])
        host.settle { drawn()["0"] == stood["1"] }
        XCTAssertEqual(drawn()["0"], stood["1"], "row 0 ends where row 1 stood")
    }
}
