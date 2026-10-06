import StateUI

/// A thousand rows, of which only the ones on screen are built.
private struct LongList: ExampleContent {
    // listing: LongList
    @State private var chosen: Int?

    var body: some View {
        Grid {
            // One view per item, the item its identity - built as the
            // platform's own list shows it, never before.
            ItemsView(0..<1_000) { number in
                HStack {
                    Text("\(number)")
                        .fontSize(14)
                        .width(90)
                        .verticalAlignment(.center)

                    Text("\(number * number)")
                        .fontSize(13)
                        .textColor(Palette.subtle)
                        .verticalAlignment(.center)
                }
                .spacing(12)
                .padding(horizontal: 14, vertical: 10)
            }
            .header(Text("N and N², a thousand times")
                .fontSize(11)
                .fontAttributes(.bold)
                .textColor(Palette.subtle)
                .padding(horizontal: 14, vertical: 8)
                .background(Palette.raised))
            .footer(Text("That is all of them.")
                .fontSize(12)
                .textColor(Palette.subtle)
                .padding(horizontal: 14, vertical: 8))
            .selection($chosen)
            .gridRow(0)

            // Built again only for the choice: scrolling builds rows, never
            // the page.
            DebugInfoLabel()
                .gridRow(1)

            Text(chosen.map { "Row \($0) is chosen." } ?? "Tap a row.")
                .fontSize(13)
                .textColor(Palette.accent)
                .gridRow(1)
        }
        .rows(.fill, .auto)
        .rowSpacing(10)
    }
    // listing: end

    var notes: (any View)? {
        Text("Scroll to the end, and tap a row to choose it.")
            .fontSize(12)
            .textColor(Palette.subtle)
    }
}

/// Two strips running across: cards of one width, and tags as wide as their words.
private struct AcrossList: ExampleContent {
    // listing: AcrossList
    static let tags = [
        "State", "Binding", "Journey", "Engine", "Motion", "Placement", "Environment", "Scene", "Window",
        "Page", "Aim", "Style", "Theme", "Gesture", "Frame", "Conversion", "Sample", "Identity", "Session",
        "Persistence",
    ]

    var body: some View {
        VStack {
            DebugInfoLabel()

            // A row: one card beside another, each as wide as it says.
            ItemsView(1...200) { number in
                Text("Card \(number)")
                    .fontSize(14)
                    .horizontalTextAlignment(.center)
                    .verticalTextAlignment(.center)
                    .width(120)
                    .background(Palette.surface)
            }
            .itemsLayout(.row(spacing: 8))
            .height(80)

            // Each tag as wide as its word.
            ItemsView(Self.tags) { tag in
                Text(tag)
                    .fontSize(13)
                    .padding(horizontal: 14, vertical: 0)
                    .verticalTextAlignment(.center)
                    .background(Palette.raised)
            }
            .itemsLayout(.row(spacing: 8))
            .height(40)
        }
        .spacing(12)
    }
    // listing: end

    var notes: (any View)? {
        Text("Swipe both strips: the cards share one width, and every tag is as wide as its word.")
            .fontSize(12)
            .textColor(Palette.subtle)
    }
}

/// Tiles in as many columns as the width holds.
private struct GridList: ExampleContent {
    // listing: GridList
    @State private var opened: Int?

    static let hues: [Color] = [.tomato, .orange, .teal, .steelBlue, .purple, .firebrick]

    var body: some View {
        Grid {
            // Columns at least 100 wide: as many as the width holds.
            ItemsView(0..<120) { number in
                Text("\(number)")
                    .fontSize(15)
                    .fontAttributes(.bold)
                    .textColor(.white)
                    .horizontalTextAlignment(.center)
                    .verticalTextAlignment(.center)
                    .height(72)
                    .background(Self.hues[number % Self.hues.count])   // listing: keep
            }
            .itemsLayout(.grid(minimumItemWidth: 100, spacing: 8))
            .onItemActivated { opened = $0 }
            .gridRow(0)

            DebugInfoLabel()
                .gridRow(1)

            Text(opened.map { "Tile \($0) opened." } ?? "Open a tile.")
                .fontSize(13)
                .textColor(Palette.accent)
                .gridRow(1)
        }
        .rows(.fill, .auto)
        .rowSpacing(10)
    }
    // listing: end

    var notes: (any View)? {
        Text("Turn the device or widen the window: the columns follow the width.")
            .fontSize(12)
            .textColor(Palette.subtle)
    }
}

/// Items under headings of their own, with a count under each group.
private struct GroupedList: ExampleContent {
    // listing: GroupedList
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

    var body: some View {
        Grid {
            SwitchRow("Counts", $counts)
                .gridRow(0)

            DebugInfoLabel()
                .gridRow(0)

            // A group per shelf, named so two shelves may hold the same item.
            ItemsView(groups: Self.shelves.map { (shelf: Shelf) -> Section<[String], String> in
                let group = Section(shelf.items) { item in
                    Text(item)
                        .fontSize(14)
                        .padding(horizontal: 14, vertical: 10)
                }
                .id(shelf.name)
                .header(Text(shelf.name)
                    .fontSize(12)
                    .fontAttributes(.bold)
                    .textColor(Palette.subtle)
                    .padding(horizontal: 14, vertical: 8)
                    .background(Palette.raised))

                return counts
                    ? group.footer(Text("\(shelf.items.count) items")
                        .fontSize(12)
                        .textColor(Palette.subtle)
                        .padding(horizontal: 14, vertical: 6))
                    : group
            })
            .gridRow(1)
        }
        .rows(.auto, .fill)
        .rowSpacing(10)
    }
    // listing: end

    var notes: (any View)? {
        Text("Turn Counts off: the groups close up where their footers stood.")
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
