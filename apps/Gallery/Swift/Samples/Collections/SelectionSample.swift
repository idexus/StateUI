import StateUI

/// Choosing rows of a LazyList - one at a time, or as many as are tapped.
struct SelectionSample: SampleContent {
    @State private var single: String? = "Beta"
    @State private var many: Set<String> = ["Alpha", "Gamma"]

    static let id = "selection"
    static let title = "Selection"
    static let summary = "Which rows of a list are chosen, one at a time or several."

    static let code = """
        @State private var single: String? = "Beta"
        @State private var many: Set<String> = ["Alpha", "Gamma"]

        private static let rows = ["Alpha", "Beta", "Gamma", "Delta"]

        VStack {
            // One binding of one type - and the TYPE is the mode: an
            // optional identity is one row at a time, a Set is as many as
            // are tapped. There is no selectionMode to disagree with it.
            LazyList(Self.rows) { row in
                Label(row)
                    .padding(12, 8)
                    // A chosen row draws ITSELF: the template reads the
                    // same state the binding writes.
                    .backgroundColor(single == row ? Palette.selected : .transparent)
            }
            .selection($single)
            .heightRequest(180)

            Label(single.map { "Chosen: \\($0)" } ?? "Nothing chosen")

            LazyList(Self.rows) { row in
                Label(row)
                    .padding(12, 8)
                    .backgroundColor(many.contains(row) ? Palette.selected : .transparent)
            }
            .selection($many)
            .heightRequest(180)

            Label(many.isEmpty
                ? "Nothing chosen"
                : "Chosen: \\(many.sorted().joined(separator: ", "))")
        }
        """

    private static let rows = ["Alpha", "Beta", "Gamma", "Delta"]

    var content: Element {
        VStack {
            SectionTitle("ONE AT A TIME")

            LazyList(Self.rows) { row in
                Label(row)
                    .fontSize(15)
                    .padding(12, 8)
                    .verticalOptions(.center)
                    .backgroundColor(single == row ? Palette.selected : .transparent)
            }
            .selection($single)
            .heightRequest(180)

            Label(single.map { "Chosen: \($0)" } ?? "Nothing chosen")
                .fontSize(13)

            SectionTitle("AS MANY AS YOU LIKE")

            LazyList(Self.rows) { row in
                Label(row)
                    .fontSize(15)
                    .padding(12, 8)
                    .verticalOptions(.center)
                    .backgroundColor(many.contains(row) ? Palette.selected : .transparent)
            }
            .selection($many)
            .heightRequest(180)

            Label(many.isEmpty
                ? "Nothing chosen"
                : "Chosen: \(many.sorted().joined(separator: ", "))")
                .fontSize(13)

            Label("A selection is made of ITEMS, not positions: the row's identity is what "
                + "the binding holds, so a chosen row keeps its choice when the list is "
                + "sorted, filtered or added to. The binding's TYPE says how many rows may "
                + "be chosen - an optional identity for one, a Set for as many as are "
                + "tapped - which is why there is no mode to set beside it.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("Tapping the chosen row again clears it, in either mode. And what a chosen "
                + "row LOOKS like is the template's business: it reads the same state the "
                + "binding writes, one line, and it can look like anything at all - a wash, "
                + "a tick, a bolder label.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("A list nobody lends a binding to is not selectable: no tap is subscribed "
                + "on its rows at all.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(12)
    }
}
