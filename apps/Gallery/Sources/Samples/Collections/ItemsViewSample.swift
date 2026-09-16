#if MAUI
import StateUI

/// A thousand rows, of which the list describes the dozen in view - and one
/// measured row is where all the arithmetic comes from.
private struct LongList: ExampleContent {
    @State private var chosen: Int?

    static let code = """
        @State private var chosen: Int?

        // A list is bounded the way a scroller is: a STAR row of a Grid gives
        // it as much of the window as there is.
        Grid {
            // One view per item, the item its identity - described as it
            // comes into view, a dozen at a time. The first row is measured,
            // and its height is every row's.
            ItemsView(0..<1_000) { number in
                HStack {
                    Label("\\(number)").width(90)
                    Label("\\(number * number)")
                }
                .padding(14, 10)
                // A chosen row draws itself: the template reads the state the
                // binding writes.
                .background(chosen == number ? Palette.selected : .transparent)
            }
            .header(Label("N and N², a thousand times"))
            .footer(Label("That is all of them."))
            .selection($chosen)
            .gridRow(0)

            // `chosen` is read here, so a tap builds this closure - and a
            // scroll through the thousand builds it not once.
            DebugInfoLabel()
                .gridRow(1)

            Label(chosen.map { "Row \\($0) is chosen." } ?? "Tap a row.")
                .gridRow(1)
        }
        .rows(.fill, .auto)
        """

    var content: any View {
        Grid {
            ItemsView(0..<1_000) { number in
                HStack {
                    Label("\(number)")
                        .fontSize(14)
                        .width(90)
                        .verticalAlignment(.center)

                    Label("\(number * number)")
                        .fontSize(13)
                        .textColor(Palette.subtle)
                        .verticalAlignment(.center)
                }
                .spacing(12)
                .padding(14, 10)
                .background(chosen == number ? Palette.selected : .transparent)
            }
            .header(Label("N and N², a thousand times")
                .fontSize(11)
                .fontAttributes(.bold)
                .textColor(Palette.subtle)
                .padding(14, 8)
                .background(Palette.raised))
            .footer(Label("That is all of them.")
                .fontSize(12)
                .textColor(Palette.subtle)
                .padding(14, 8))
            .selection($chosen)
            .gridRow(0)

            DebugInfoLabel()
                .gridRow(1)

            Label(chosen.map { "Row \($0) is chosen." } ?? "Tap a row.")
                .fontSize(13)
                .textColor(Palette.accent)
                .gridRow(1)
        }
        .rows(.fill, .auto)
        .rowSpacing(10)
    }

    var notes: Element? {
        Label("Scroll to the end: every row is described as it comes into view, and the "
            + "first row measured gives every row its height. Tap a row to choose it, and "
            + "tap it again to clear it.")
            .fontSize(12)
            .textColor(Palette.subtle)
    }
}

/// Two strips running across: cards of one stated width, and tags each as
/// wide as its word.
private struct AcrossList: ExampleContent {
    /// Words of every length, each its own tag.
    static let tags = [
        "State", "Binding", "Journey", "Engine", "Motion", "Placement", "Environment",
        "Scene", "Window", "Page", "Aim", "Style", "Theme", "Gesture", "Frame",
        "Conversion", "Sample", "Identity", "Session", "Persistence",
    ]

    static let code = """
        let tags = [
            "State", "Binding", "Journey", "Engine", "Motion", "Placement", "Environment",
            "Scene", "Window", "Page", "Aim", "Style", "Theme", "Gesture", "Frame",
            "Conversion", "Sample", "Identity", "Session", "Persistence",
        ]

        VStack {
            // Scrolling a strip builds nothing here: each strip describes its
            // own items, and this closure reads none of it.
            DebugInfoLabel()

            // Across is the same arithmetic on the other axis: an item takes
            // the strip's whole height, and `itemSize` is its WIDTH.
            ItemsView(1...200) { number in
                Label("Card \\(number)")
                    .horizontalTextAlignment(.center)
                    .verticalTextAlignment(.center)
                    .background(Palette.surface)
                    .margin(0, 0, 8, 0)
            }
            .orientation(.horizontal)
            .itemSize(120)
            // Bounded across its axis, as any scroller is.
            .height(80)

            // Every tag measured on its own, so each is as wide as its word.
            ItemsView(tags) { tag in
                Grid {
                    Label(tag)
                        .padding(14, 0)
                        .verticalTextAlignment(.center)
                        .background(Palette.raised)
                }
                .padding(0, 0, 8, 0)
            }
            .orientation(.horizontal)
            .itemSizing(.individual)
            .height(40)
        }
        """

    var content: any View {
        VStack {
            DebugInfoLabel()

            ItemsView(1...200) { number in
                // The card FILLS its slot - the alignment is the text's, not
                // the view's - so what is on screen is the item's real size.
                Label("Card \(number)")
                    .fontSize(14)
                    .horizontalTextAlignment(.center)
                    .verticalTextAlignment(.center)
                    .background(Palette.surface)
                    .margin(0, 0, 8, 0)
            }
            .orientation(.horizontal)
            .itemSize(120)
            .height(80)

            ItemsView(Self.tags) { tag in
                Grid {
                    Label(tag)
                        .fontSize(13)
                        .padding(14, 0)
                        .verticalTextAlignment(.center)
                        .background(Palette.raised)
                }
                .padding(0, 0, 8, 0)
            }
            .orientation(.horizontal)
            .itemSizing(.individual)
            .height(40)
        }
        .spacing(12)
    }

    var notes: Element? {
        Label("Swipe both strips. The cards share one stated width; every tag is measured "
            + "on its own and is as wide as its word.")
            .fontSize(12)
            .textColor(Palette.subtle)
    }
}

/// Items under headers, with a footer each that a switch takes away.
private struct GroupedList: ExampleContent {
    @State private var counts = true

    /// One shelf: its name, and what stands on it.
    struct Shelf {
        let name: String
        let items: [String]
    }

    static let shelves = [
        Shelf(name: "Fruit", items: ["Apple", "Pear", "Plum", "Cherry", "Quince", "Apricot"]),
        Shelf(name: "Vegetables", items: ["Leek", "Carrot", "Parsnip", "Beetroot", "Celery"]),
        Shelf(name: "Bakery", items: ["Rye loaf", "Bagel", "Croissant", "Pretzel"]),
        Shelf(name: "Dairy", items: ["Butter", "Kefir", "Cheddar", "Quark", "Cream", "Yoghurt"]),
        Shelf(name: "Pantry", items: ["Rice", "Lentils", "Flour", "Oats", "Honey", "Salt"]),
        Shelf(name: "Drinks", items: ["Water", "Tea", "Coffee", "Juice"]),
    ]

    static let code = """
        @State private var counts = true

        struct Shelf {
            let name: String
            let items: [String]
        }

        let shelves = [
            Shelf(name: "Fruit", items: ["Apple", "Pear", "Plum", "Cherry", "Quince", "Apricot"]),
            Shelf(name: "Vegetables", items: ["Leek", "Carrot", "Parsnip", "Beetroot", "Celery"]),
            Shelf(name: "Bakery", items: ["Rye loaf", "Bagel", "Croissant", "Pretzel"]),
            Shelf(name: "Dairy", items: ["Butter", "Kefir", "Cheddar", "Quark", "Cream", "Yoghurt"]),
            Shelf(name: "Pantry", items: ["Rice", "Lentils", "Flour", "Oats", "Honey", "Salt"]),
            Shelf(name: "Drinks", items: ["Water", "Tea", "Coffee", "Juice"]),
        ]

        Grid {
            // A group given no footer has no footer slot, so its items close up.
            SwitchRow("Counts", $counts)
                .gridRow(0)

            DebugInfoLabel()
                .gridRow(0)

            // The groups are data - an array, not a builder. A header and a
            // footer are slots in the same run as the items, each kind
            // measured once.
            ItemsView(groups: shelves.map { shelf in
                let group = ItemsGroup(shelf.items) { item in
                    Label(item).padding(14, 10)
                }
                .id(shelf.name)
                .header(Label(shelf.name).padding(14, 8).background(Palette.raised))

                return counts ? group.footer(Label("\\(shelf.items.count) items")) : group
            })
            .gridRow(1)
        }
        .rows(.auto, .fill)
        """

    var content: any View {
        Grid {
            SwitchRow("Counts", $counts)
                .gridRow(0)

            DebugInfoLabel()
                .gridRow(0)

            ItemsView(groups: Self.shelves.map { (shelf: Shelf) -> ItemsGroup<[String], String> in
                let group = ItemsGroup(shelf.items) { item in
                    Label(item)
                        .fontSize(14)
                        .padding(14, 10)
                }
                .id(shelf.name)
                .header(Label(shelf.name)
                    .fontSize(12)
                    .fontAttributes(.bold)
                    .textColor(Palette.subtle)
                    .padding(14, 8)
                    .background(Palette.raised))

                return counts
                    ? group.footer(Label("\(shelf.items.count) items")
                        .fontSize(12)
                        .textColor(Palette.subtle)
                        .padding(14, 6))
                    : group
            })
            .gridRow(1)
        }
        .rows(.auto, .fill)
        .rowSpacing(10)
    }

    var notes: Element? {
        Label("Turn Counts off: a group without a footer has no footer slot, and its items "
            + "close up rather than leave a gap.")
            .fontSize(12)
            .textColor(Palette.subtle)
    }
}

/// The shapes a list takes: a thousand rows down the page, strips running
/// across it, and items under headers of their own.
struct ItemsViewSample: SampleContent {
    static let id = "itemsView"
    static let title = "ItemsView"
    static let summary = "A list that describes only the items in view - down, across, and in groups."

    // Every example here IS a scroller, so the page does not put one inside
    // another - and each takes the window's height, since a list is worth as
    // many rows as there is room for.
    static let scrolls = false
    static let fills = true

    var examples: [Example] {
        [
            Example(LongList()),
            Example(AcrossList()),
            Example(GroupedList()),
        ]
    }
}
#endif
