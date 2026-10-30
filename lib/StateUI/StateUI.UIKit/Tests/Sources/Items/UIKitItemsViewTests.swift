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

/// A hundred rows, scrolled to their last as the list is made.
private struct OpeningAtTheEnd: View {
    @Aim(ItemsView<Int>.self) private var list

    var body: some View {
        ItemsView(0..<100) { Text("Row \($0)").fontSize(14).padding(10) }
            .aim(list)
            .onCreated { try await list.scrollTo(99, anchor: .end) }
            .width(300).height(400)
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

    /// A change to the entries waiting for a turn as the collection asks for a cell in its own layout - a scroll
    /// bringing a row near the end of those built - waits for the cell: the turn the cell's entry asks for renders
    /// it, but the snapshot stands only once the cell is the collection's. Applied inside the request, UIKit ends the
    /// application with "Expected dequeued view to be returned to the collection view".
    @MainActor
    func testEntriesChangedWhileTheCollectionAsksForACellWaitForTheCell() throws {
        let numbers = State(wrappedValue: Array(0..<1_000))
        let host = UIKitRenderer.running {
            ItemsView(numbers.wrappedValue) { Text("Row \($0)").fontSize(14).padding(10) }
                .width(300).height(500)
        }
        defer { host.finish() }
        let items = try XCTUnwrap(host.views(UIKitItemsView.self).first)
        let collection = items.collection
        host.settle {
            collection.visibleCells.count > 5
                && collection.visibleCells.allSatisfy { ($0 as? UIKitItemCell)?.holding.shown != nil }
        }

        let renders = host.runtime.core.tally.renders
        numbers.wrappedValue = [999] + Array(0..<999)
        collection.setContentOffset(CGPoint(x: 0, y: 600), animated: false)
        collection.layoutIfNeeded()
        XCTAssertGreaterThan(host.runtime.core.tally.renders, renders, "the cells asked for rendered the tree")
        XCTAssertEqual(items.appliedWhileAskingForTesting, 0, "no snapshot while the collection asked for a cell")
        host.settle { collection.visibleCells.contains { ($0 as? UIKitItemCell)?.holding.shown != nil } }
        collection.setContentOffset(.zero, animated: false)
        host.settle {
            collection.layoutIfNeeded()
            return (collection.cellForItem(at: IndexPath(item: 0, section: 0)) as? UIKitItemCell)?.holding.identity == "999"
        }

        let first = collection.cellForItem(at: IndexPath(item: 0, section: 0)) as? UIKitItemCell
        XCTAssertEqual(first?.holding.identity, "999", "the change stands once the cell is returned")
    }

    /// A scroll the program asks for stands its item though the bars over the list change what it keeps clear while
    /// it glides there - a list in a sheet still coming in, its page's bars first laid out: at the list's end, clear
    /// of the bar at its foot.
    @MainActor
    func testAScrollStandsItsItemThoughTheBarsChangeAsItGlides() throws {
        let host = UIKitRenderer.running {
            ItemsView(0..<100) { Text("Row \($0)").fontSize(14).padding(10) }
                .width(300).height(400)
        }
        defer { host.finish() }
        let items = try XCTUnwrap(host.views(UIKitItemsView.self).first)
        host.settle { items.collection.visibleCells.count > 5 }

        items.scroll(to: "99", anchor: .end)
        items.keepClear(Clearance(top: 50, left: 0, bottom: 60, right: 0))
        let collection = items.collection
        let foot = { (collection.layoutAttributesForItem(at: IndexPath(item: 99, section: 0))?.frame.maxY ?? 0)
            - collection.contentOffset.y }
        host.settle { abs(foot() - (collection.bounds.height - 60)) < 1 }

        XCTAssertEqual(foot(), collection.bounds.height - 60, accuracy: 1, "at the list's end, clear of the foot")
    }

    /// A scroll the program asks for as the list is made - before UIKit ever laid it out - stands its item once the
    /// list is laid out: a conversation opening at its last message.
    @MainActor
    func testAScrollAskedAsTheListIsMadeStandsOnceItIsLaidOut() throws {
        let host = UIKitRenderer.running { OpeningAtTheEnd() }
        defer { host.finish() }
        let items = try XCTUnwrap(host.views(UIKitItemsView.self).first)
        let collection = items.collection
        let foot = { (collection.layoutAttributesForItem(at: IndexPath(item: 99, section: 0))?.frame.maxY ?? 0)
            - collection.contentOffset.y }
        host.settle { abs(foot() - collection.bounds.height) < 1 }

        XCTAssertEqual(foot(), collection.bounds.height, accuracy: 1, "at the list's end")
    }

    /// The item the program scrolled to stands again as the list's room changes, until anything else moves it - a
    /// sheet lays its list out at the screen's size first, where every row fits and the last stands at the top,
    /// then at its own: at the list's end there.
    @MainActor
    func testAnItemScrolledToStandsAgainAsTheListsRoomChanges() throws {
        let host = UIKitRenderer.running {
            ItemsView(0..<15) { Text("Row \($0)").fontSize(14).padding(10) }
                .width(300).height(400)
        }
        defer { host.finish() }
        let items = try XCTUnwrap(host.views(UIKitItemsView.self).first)
        let collection = items.collection
        items.frame = CGRect(x: 0, y: 0, width: 300, height: 1_000)
        items.layoutIfNeeded()
        host.settle { collection.visibleCells.count == 15 }
        items.scroll(to: "14", anchor: .end)
        host.settle { collection.contentOffset.y == 0 }

        items.frame = CGRect(x: 0, y: 0, width: 300, height: 300)
        items.layoutIfNeeded()
        let foot = { (collection.layoutAttributesForItem(at: IndexPath(item: 14, section: 0))?.frame.maxY ?? 0)
            - collection.contentOffset.y }
        host.settle { abs(foot() - 300) < 1 }
        XCTAssertEqual(foot(), 300, accuracy: 1, "at the list's end in its room")
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
