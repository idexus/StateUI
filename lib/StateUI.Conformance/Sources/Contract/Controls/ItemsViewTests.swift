// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// `ItemsViewContract` on a host: only the items in view are built; a list lays them down, a row across and a grid in
/// the columns its width holds; the user's choice - one or many - lands on the state, the program's is shown and heard
/// by nobody; an item opened is heard; the end is heard once as the user nears it; and the list scrolls to an item.
@_spi(Host) public enum ItemsViewTests: ConformanceFamily {
    public static let name = "ItemsView"

    public static var cases: [ConformanceCase] {
        [
            Aspects.standsAlone("ItemsView"),
            ConformanceCase("onlyTheItemsInViewAreBuilt", proves: [
                Covered(ItemsViewContract.items), Covered(ItemsViewContract.realizedChanged),
            ]) { s in
                s.start { VStack { numbers().width(300).height(400).id("list") } }

                s.settle { (try? s.item("0", of: s.element("list"))) != nil }
                s.expect(try s.held(TextElementContract.text, on: s.item("0", of: s.element("list"))), "Item 0")
                s.expect((try? s.item("999", of: s.element("list"))) == nil, true, "an item far out of view is not built")
            },
            ConformanceCase("aListLaysItsItemsDown", proves: [Covered(ItemsViewContract.itemsLayout)]) { s in
                s.start { VStack { numbers().itemsLayout(.list(spacing: 6)).width(300).height(400).id("list") } }
                s.settle { (try? s.item("1", of: s.element("list"))) != nil }
                let (first, second) = (try s.place(of: s.item("0", of: s.element("list"))), try s.place(of: s.item("1", of: s.element("list"))))

                s.expect(second.x, first.x, within: 0.5, "one under another")
                s.expect(second.y, first.y + first.height + 6, within: 0.5, "six apart")
                s.expect(first.width, 300, within: 0.5, "each as wide as the list")
            },
            ConformanceCase("aRowLaysItsItemsAcross", proves: [Covered(ItemsViewContract.itemsLayout)]) { s in
                s.start { VStack { numbers().itemsLayout(.row(spacing: 8)).width(300).height(60).id("list") } }
                s.settle { (try? s.item("1", of: s.element("list"))) != nil }
                let (first, second) = (try s.place(of: s.item("0", of: s.element("list"))), try s.place(of: s.item("1", of: s.element("list"))))

                s.expect(second.y, first.y, within: 0.5, "one beside another")
                s.expect(second.x, first.x + first.width + 8, within: 0.5, "eight apart")
                s.expect(first.height, 60, within: 0.5, "each as tall as the row")
            },
            ConformanceCase("aGridLaysItsItemsInTheColumnsItsWidthHolds", proves: [
                Covered(ItemsViewContract.itemsLayout),
            ]) { s in
                s.start {
                    VStack {
                        numbers().itemsLayout(.grid(minimumItemWidth: 90, spacing: 10)).width(300).height(400).id("list")
                    }
                }
                s.settle { (try? s.item("3", of: s.element("list"))) != nil }
                let places = try (0...3).map { try s.place(of: s.item("\($0)", of: s.element("list"))) }
                let width = (300.0 - 2 * 10) / 3

                s.expect(places[1].y, places[0].y, within: 0.5, "three columns")
                s.expect(places[2].y, places[0].y, within: 0.5, "three columns")
                s.expect(places[1].x, places[0].x + width + 10, within: 0.5, "sharing the width, ten apart")
                s.expect(places[3].x, places[0].x, within: 0.5, "the fourth under the first")
                s.expect(places[0].width, width, within: 0.5)
            },
            ConformanceCase("aChoiceTheUserMakesLandsOnTheState", proves: [
                Covered(ItemsViewContract.selectionMode), Covered(ItemsViewContract.selectedItems),
                Covered(ItemsViewContract.selectionChanged),
            ], needs: [Covered(ButtonContract.clicked)]) { s in
                let chosen = State<Int?>(wrappedValue: nil)
                let heard = Received<[String]>()
                s.start(reducesMotion: true) {
                    VStack {
                        Button("Five").onClicked { chosen.wrappedValue = 5 }.id("five")
                        numbers().selection(chosen.projectedValue)
                            .onEvent(ItemsViewContract.selectionChanged) { heard.values.append($0) }
                            .width(300).height(400).id("list")
                    }
                }
                let list = try s.element("list")
                s.settle { (try? s.item("3", of: s.element("list"))) != nil }
                s.expect(try s.held(ItemsViewContract.selectionMode, on: list), .single)

                try s.perform(.choose(3), on: list)
                s.settle { chosen.wrappedValue == 3 }
                s.expect(chosen.wrappedValue, 3, "the user's choice")
                s.expect(try s.held(ItemsViewContract.selectedItems, on: list), ["3"])

                try s.perform(.activate, on: s.element("five"))
                try s.settle { try s.held(ItemsViewContract.selectedItems, on: list) == ["5"] }
                s.expect(try s.held(ItemsViewContract.selectedItems, on: list), ["5"], "the program's choice shown")
                s.expect(heard.values, [["3"]], "and heard by nobody")
            },
            ConformanceCase("manyChoicesLandOnTheState", proves: [
                Covered(ItemsViewContract.selectionMode), Covered(ItemsViewContract.selectedItems),
                Covered(ItemsViewContract.selectionChanged),
            ]) { s in
                let chosen = State<Set<Int>>(wrappedValue: [])
                s.start { VStack { numbers().selection(chosen.projectedValue).width(300).height(400).id("list") } }
                let list = try s.element("list")
                s.settle { (try? s.item("3", of: s.element("list"))) != nil }
                s.expect(try s.held(ItemsViewContract.selectionMode, on: list), .multiple)

                try s.perform(.choose(1), on: list)
                s.settle { chosen.wrappedValue == [1] }
                try s.perform(.choose(3), on: list)
                s.settle { chosen.wrappedValue == [1, 3] }
                s.expect(chosen.wrappedValue, [1, 3])
                s.expect(try s.held(ItemsViewContract.selectedItems, on: list), ["1", "3"], "in the order they show")
            },
            ConformanceCase("anItemOpenedIsHeard", proves: [Covered(ItemsViewContract.itemActivated)]) { s in
                let opened = Received<Int>()
                s.start {
                    VStack {
                        numbers().onItemActivated { opened.values.append($0) }.width(300).height(400).id("list")
                    }
                }
                s.settle { (try? s.item("2", of: s.element("list"))) != nil }

                try s.perform(.activate, on: s.item("2", of: s.element("list")))
                s.settle { !opened.values.isEmpty }
                s.expect(opened.values, [2])
            },
            ConformanceCase("theEndIsHeardOnceAsTheUserNearsIt", proves: [
                Covered(ItemsViewContract.endReached), Covered(ItemsViewContract.endReachedWithin),
            ]) { s in
                let count = State(wrappedValue: 30)
                s.start {
                    VStack {
                        ItemsView(0..<count.wrappedValue) { Label("Item \($0)").padding(12) }
                            .onEndReached(within: 5) { count.wrappedValue += 30 }
                            .width(300).height(300).id("list")
                    }
                }
                let list = try s.element("list")
                s.settle { (try? s.item("0", of: s.element("list"))) != nil }
                s.expect(count.wrappedValue, 30, "nothing asked for at the start")

                try s.perform(.scroll(to: Point(0, 100_000)), on: list)
                s.settle { count.wrappedValue == 60 }
                s.turn()
                s.expect(count.wrappedValue, 60, "thirty more, asked for once")
            },
            ConformanceCase("theListScrollsToAnItem", proves: [
                Covered(ItemsViewContract.scrollTo),
            ], needs: [Covered(ButtonContract.clicked)]) { s in
                let aim = Aim(ItemsViewContract.self)
                s.start(reducesMotion: true) {
                    VStack {
                        Button("To 80").onClicked { try await aim.scrollTo(80, anchor: .start) }.id("go")
                        numbers().aim(aim).width(300).height(300).id("list")
                    }
                }
                s.settle { (try? s.item("0", of: s.element("list"))) != nil }

                try s.perform(.activate, on: s.element("go"))
                s.settle { (try? s.item("80", of: s.element("list"))) != nil }
                let item = try s.place(of: s.item("80", of: s.element("list")))
                let list = try s.place(of: s.element("list"))
                s.expect(item.y, list.y, within: 1, "at the list's start")
            },
        ]
    }

    /// A thousand numbered items, each words with room around them.
    static func numbers() -> ItemsView<Range<Int>, Int> {
        ItemsView(0..<1_000) { Label("Item \($0)").padding(12) }
    }
}
