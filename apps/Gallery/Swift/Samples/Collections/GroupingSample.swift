import StateUI

/// Rows under headings: a CollectionView of LazyGroups.
struct GroupingSample: SampleContent {
    @State private var showFooters = true

    static let id = "grouping"
    static let title = "Grouping"
    static let summary = "Rows under headings, with the headings described like everything else."

    static let code = """
        @State private var showFooters = true

        private static let shelves = [
            ("Fruit", ["Apple", "Pear", "Plum"]),
            ("Veg", ["Leek", "Parsnip"]),
        ]

        VStack {
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
            .heightRequest(320)

            Button(showFooters ? "Hide the counts" : "Show the counts")
                .onClicked { showFooters.toggle() }
        }
        """

    private static let shelves = [
        ("Fruit", ["Apple", "Pear", "Plum"]),
        ("Veg", ["Leek", "Parsnip"]),
    ]

    var content: Element {
        VStack {
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
            .heightRequest(320)

            Button(showFooters ? "Hide the counts" : "Show the counts")
                .fontSize(13)
                .padding(16, 6)
                .horizontalOptions(.center)
                .onClicked { showFooters.toggle() }

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

            Label("A group given no footing has no footing slot at all, which is what Hide "
                + "does here: the rows below move up by that much rather than leaving a gap "
                + "where a view of no height would be.")
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
