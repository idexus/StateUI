import StateUI

/// A long list: 100_000 rows, computed, and only the visible ones described.
struct ManyItemsSample: SampleContent {
    @State private var items: [Int] = Array(1...100_000)

    @State private var list = ControlState<ScrollView>()

    static let id = "manyItems"
    static let title = "Many items"
    static let summary = "The library's own list: a hundred thousand rows, a dozen described."

    // The list scrolls itself, so the page holds still and scrolls the code.
    static let scrolls = false
    static let fills = true

    static let code = """
        @State private var items: [Int] = Array(1...100_000)

        @State private var list = ControlState<ScrollView>()

        // A STAR row bounds the list, so it is as tall as the window allows -
        // a height in points would show the same few rows on every screen.
        Grid {
            HStack {
                // The first item goes to the end. The item is the row's
                // identity, so its ROW moves with it - and only the rows in
                // view are described at all, so the rest cost nothing.
                Button("Rotate")
                    .onClicked {
                        guard !items.isEmpty else { return }
                        items.append(items.removeFirst())
                    }

                // One shorter: the list gets 36 points shorter, and the rows
                // below the one that left move up by that much.
                Button("Remove the first")
                    .isEnabled(!items.isEmpty)
                    .onClicked {
                        guard !items.isEmpty else { return }
                        items.removeFirst()
                    }

                // A row's offset is its number times the row height, which is
                // why a list that means to be scrolled about states one.
                Button("End")
                    .onClicked {
                        try await list.scrollTo(x: 0, y: Double(items.count) * 36)
                    }
            }

            // A row is a table row: everything in it is computed from the
            // number, so a row is exactly what its item says it is.
            CollectionView(items) { number in
                HStack {
                    Label("\\(number)").widthRequest(60)
                    Label("\\(number * number)").widthRequest(90)
                    Label("\\(number * (number + 1) / 2)").widthRequest(90)
                }
            }
            .itemSize(36)
            .header(
                HStack {
                    Label("N").widthRequest(60)
                    Label("N²").widthRequest(90)
                    Label("SUM 1..N").widthRequest(90)
                })
            .assign(list)
            .gridRow(1)
        }
        .rowDefinitions(.auto, .star)
        """

    var content: Element {
        Grid {
            HStack {
                Button("Rotate")
                    .fontSize(13)
                    .padding(16, 6)
                    .onClicked {
                        guard !items.isEmpty else { return }
                        items.append(items.removeFirst())
                    }

                Button("Remove the first")
                    .fontSize(13)
                    .padding(16, 6)
                    .isEnabled(!items.isEmpty)
                    .onClicked {
                        guard !items.isEmpty else { return }
                        items.removeFirst()
                    }

                Button("End")
                    .fontSize(13)
                    .padding(16, 6)
                    .isEnabled(!items.isEmpty)
                    .onClicked {
                        try await list.scrollTo(x: 0, y: Double(items.count) * 36)
                    }
            }
            .spacing(10)
            .horizontalOptions(.center)
            .gridRow(0)

            CollectionView(items) { number in
                HStack {
                    Label("\(number)")
                        .fontSize(14)
                        .widthRequest(60)
                        .verticalOptions(.center)

                    Label("\(number * number)")
                        .fontSize(14)
                        .textColor(Palette.subtle)
                        .widthRequest(90)
                        .verticalOptions(.center)

                    Label("\(number * (number + 1) / 2)")
                        .fontSize(14)
                        .textColor(Palette.subtle)
                        .widthRequest(90)
                        .verticalOptions(.center)
                }
                .spacing(10)
                .padding(12, 6)
            }
            .itemSize(36)
            .header(
                HStack {
                    Label("N")
                        .fontSize(11)
                        .fontAttributes(.bold)
                        .widthRequest(60)

                    Label("N²")
                        .fontSize(11)
                        .fontAttributes(.bold)
                        .widthRequest(90)

                    Label("SUM 1..N")
                        .fontSize(11)
                        .fontAttributes(.bold)
                        .widthRequest(90)
                }
                .spacing(10)
                .padding(12, 8)
                .backgroundColor(Palette.raised))
            .assign(list)
            .gridRow(1)

        }
        .rowDefinitions(.auto, .star)
        .rowSpacing(12)
    }

    var notes: Element? {
        VStack {
            Label("Rotate moves the first item to the end. The item is the row's identity, so "
                + "the row moves with it - and since only the rows in view are described, the "
                + "ones nobody can see cost nothing at all. Remove takes the first item away: "
                + "the list gets one row shorter and everything below moves up by a row.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("The row height is STATED here rather than measured, which is what makes End "
                + "arithmetic: a row's offset is its number times that height. An offset past "
                + "the end is clamped by the platform, so any number past the last row is the "
                + "end wherever that turns out to be.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(12)
    }
}
