import StateUI

/// Rows under headings: a CollectionView of LazyGroups.
struct GroupingSample: SampleContent {
    @State private var showFooters = true

    static let id = "grouping"
    static let title = "Grouping"
    static let summary = "Rows under headings, with the headings described like everything else."

    // The example IS a scroller, so the page must not put it in one: a list
    // inside a list scrolls the wrong one under the reader's finger, and the
    // words below it would take the height the rows want.
    static let scrolls = false

    /// The list is given the WINDOW's height, so it shows as many rows as the
    /// screen has room for rather than the same few everywhere.
    static let fills = true

    static let code = """
        @State private var showFooters = true

        private static let shelves = [
            ("Fruit", ["Apple", "Pear", "Plum", "Quince", "Cherry", "Fig"]),
            ("Veg", ["Leek", "Parsnip", "Carrot", "Beetroot", "Kale"]),
            ("Bread", ["Rye", "Sourdough", "Bagel", "Focaccia"]),
            ("Cheese", ["Brie", "Cheddar", "Gouda", "Stilton", "Comté"]),
        ]

        Grid {
            // A heading and a footing are SLOTS in the same run as the
            // rows - each kind measured once, so where a slot sits is a
            // sum over the groups above it. A group that is given no
            // footing has no footing SLOT, so hiding the counts takes the
            // rows up rather than leaving a gap.
            CollectionView(groups: Self.shelves.map { (name, items) in
                let shelf = CollectionGroup(items) { item in
                    Label(item)
                        .padding(16, 8)
                }
                .id(name)
                .header(
                    Label(name)
                        .fontAttributes(.bold)
                        .padding(12, 6))

                guard showFooters else { return shelf }

                return shelf.footer(Label("\\(items.count) items").padding(12, 4))
            })
            .gridRow(0)

            SwitchRow("Show the counts", $showFooters)
                .gridRow(1)
        }
        // A STAR row is how a list is bounded: as tall as the window allows,
        // where a height in points shows the same few rows on every screen.
        .rowDefinitions(.star, .auto)
        .rowSpacing(12)
        """

    private static let shelves = [
        ("Fruit", ["Apple", "Pear", "Plum", "Quince", "Cherry", "Fig"]),
        ("Veg", ["Leek", "Parsnip", "Carrot", "Beetroot", "Kale"]),
        ("Bread", ["Rye", "Sourdough", "Bagel", "Focaccia"]),
        ("Cheese", ["Brie", "Cheddar", "Gouda", "Stilton", "Comté"]),
    ]

    var content: Element {
        Grid {
            CollectionView(groups: Self.shelves.map { (name, items) in
                let shelf = CollectionGroup(items) { item in
                    Label(item)
                        .fontSize(15)
                        .padding(16, 8)
                        .verticalOptions(.center)
                }
                .id(name)
                .header(
                    Label(name)
                        .fontSize(13)
                        .fontAttributes(.bold)
                        .textColor(Palette.onAccent)
                        .backgroundColor(Palette.accent)
                        .padding(12, 6))

                guard showFooters else { return shelf }

                return shelf.footer(
                    Label("\(items.count) items")
                        .fontSize(12)
                        .textColor(Palette.subtle)
                        .padding(12, 4))
            })
            .gridRow(0)

            SwitchRow("Show the counts", $showFooters)
                .horizontalOptions(.center)
                .gridRow(1)
        }
        // The list takes the STAR row, so it is as tall as the window leaves
        // it and the switch keeps its own height under it.
        .rowDefinitions(.star, .auto)
        .rowSpacing(12)
    }

    var notes: Element? {
        VStack {
            Label("A group is DATA the list lays out: its items, its row template, and the "
                + "two views that stand above and below them. `CollectionGroup` is this library's "
                + "own name because MAUI has no class for a group either - a grouped items "
                + "source there is a list of lists, and whatever type those lists are is the "
                + "group.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("A heading is a slot in the same run as the rows, so the arithmetic is the "
                + "flat list's one level up: each KIND is measured once - a heading, a row, a "
                + "footing - and where any slot sits is a sum over the groups above it, "
                + "computed once per render over the GROUPS rather than the rows. A hundred "
                + "groups of a thousand rows costs a hundred additions.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("A group given no footing has no footing slot at all, which is what the "
                + "switch does here: the rows below move up by that much rather than leaving "
                + "a gap where a view of no height would be.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("A row is identified under its group, so two groups may hold equal items "
                + "and still keep their own rows. Give each group an `.id()` where the "
                + "groups themselves can be reordered.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(12)
    }
}
