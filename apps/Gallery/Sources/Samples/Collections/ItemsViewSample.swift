import StateUI

/// A thousand rows, of which only the ones on screen are built.
private struct LongList: ExampleContent {
    @State private var chosen: Int?

    static let code = """
        @State private var chosen: Int?

        Grid {
            // One view per item, the item its identity - built as the
            // platform's own list shows it, never before.
            ItemsView(0..<1_000) { number in
                HStack {
                    Label("\\(number)").width(90)
                    Label("\\(number * number)")
                }
                .padding(14, 10)
            }
            .header(Label("N and N², a thousand times"))
            .footer(Label("That is all of them."))
            .selection($chosen)
            .gridRow(0)

            // Built again only for the choice: scrolling builds rows, never
            // the page.
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

    var notes: (any View)? {
        Label("Scroll to the end, and tap a row to choose it.")
            .fontSize(12)
            .textColor(Palette.subtle)
    }
}

/// Two strips running across: cards of one width, and tags as wide as their words.
private struct AcrossList: ExampleContent {
    static let tags = [
        "State", "Binding", "Journey", "Engine", "Motion", "Placement", "Environment", "Scene", "Window",
        "Page", "Aim", "Style", "Theme", "Gesture", "Frame", "Conversion", "Sample", "Identity", "Session",
        "Persistence",
    ]

    static let code = """
        VStack {
            DebugInfoLabel()

            // A row: one card beside another, each as wide as it says.
            ItemsView(1...200) { number in
                Label("Card \\(number)")
                    .horizontalTextAlignment(.center)
                    .verticalTextAlignment(.center)
                    .width(120)
                    .background(Palette.surface)
            }
            .itemsLayout(.row(spacing: 8))
            .height(80)

            // Each tag as wide as its word.
            ItemsView(tags) { tag in
                Label(tag)
                    .padding(14, 0)
                    .verticalTextAlignment(.center)
                    .background(Palette.raised)
            }
            .itemsLayout(.row(spacing: 8))
            .height(40)
        }
        """

    var content: any View {
        VStack {
            DebugInfoLabel()

            ItemsView(1...200) { number in
                Label("Card \(number)")
                    .fontSize(14)
                    .horizontalTextAlignment(.center)
                    .verticalTextAlignment(.center)
                    .width(120)
                    .background(Palette.surface)
            }
            .itemsLayout(.row(spacing: 8))
            .height(80)

            ItemsView(Self.tags) { tag in
                Label(tag)
                    .fontSize(13)
                    .padding(14, 0)
                    .verticalTextAlignment(.center)
                    .background(Palette.raised)
            }
            .itemsLayout(.row(spacing: 8))
            .height(40)
        }
        .spacing(12)
    }

    var notes: (any View)? {
        Label("Swipe both strips: the cards share one width, and every tag is as wide as its word.")
            .fontSize(12)
            .textColor(Palette.subtle)
    }
}

/// Tiles in as many columns as the width holds.
private struct GridList: ExampleContent {
    @State private var opened: Int?

    static let hues: [Color] = [.tomato, .orange, .teal, .steelBlue, .purple, .firebrick]

    static let code = """
        @State private var opened: Int?

        Grid {
            // Columns at least 100 wide: as many as the width holds.
            ItemsView(0..<120) { number in
                Label("\\(number)")
                    .horizontalTextAlignment(.center)
                    .verticalTextAlignment(.center)
                    .height(72)
                    .background(hues[number % hues.count])
            }
            .itemsLayout(.grid(minimumItemWidth: 100, spacing: 8))
            .onItemActivated { opened = $0 }
            .gridRow(0)

            DebugInfoLabel()
                .gridRow(1)

            Label(opened.map { "Tile \\($0) opened." } ?? "Tap a tile.")
                .gridRow(1)
        }
        .rows(.fill, .auto)
        """

    var content: any View {
        Grid {
            ItemsView(0..<120) { number in
                Label("\(number)")
                    .fontSize(15)
                    .fontAttributes(.bold)
                    .textColor(.white)
                    .horizontalTextAlignment(.center)
                    .verticalTextAlignment(.center)
                    .height(72)
                    .background(Self.hues[number % Self.hues.count])
            }
            .itemsLayout(.grid(minimumItemWidth: 100, spacing: 8))
            .onItemActivated { opened = $0 }
            .gridRow(0)

            DebugInfoLabel()
                .gridRow(1)

            Label(opened.map { "Tile \($0) opened." } ?? "Tap a tile.")
                .fontSize(13)
                .textColor(Palette.accent)
                .gridRow(1)
        }
        .rows(.fill, .auto)
        .rowSpacing(10)
    }

    var notes: (any View)? {
        Label("Turn the device or widen the window: the columns follow the width.")
            .fontSize(12)
            .textColor(Palette.subtle)
    }
}

/// Items under headings of their own, with a count under each group.
private struct GroupedList: ExampleContent {
    @State private var counts = true

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

        Grid {
            SwitchRow("Counts", $counts)
                .gridRow(0)

            DebugInfoLabel()
                .gridRow(0)

            // A group per shelf, named so two shelves may hold the same item.
            ItemsView(groups: shelves.map { shelf in
                let group = ItemsGroup(shelf.items) { item in
                    Label(item).padding(14, 10)
                }
                .id(shelf.name)
                .header(Label(shelf.name).fontAttributes(.bold).padding(14, 8))

                return counts
                    ? group.footer(Label("\\(shelf.items.count) items").padding(14, 6))
                    : group
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

    var notes: (any View)? {
        Label("Turn Counts off: the groups close up where their footers stood.")
            .fontSize(12)
            .textColor(Palette.subtle)
    }
}

/// The shapes a list takes: a thousand rows down the page, strips running across it, tiles in columns, and items under
/// headings of their own.
struct ItemsViewSample: SampleContent {
    static let id = "itemsView"
    static let title = "ItemsView"
    static let summary = "Only the items on screen are built - down, across, in columns or in groups."

    // Every example IS a scroller, so the page does not put one inside another, and each takes the window's height.
    static let scrolls = false
    static let fills = true

    var examples: [Example] {
        [
            Example(LongList()),
            Example(AcrossList()),
            Example(GridList()),
            Example(GroupedList()),
        ]
    }
}
