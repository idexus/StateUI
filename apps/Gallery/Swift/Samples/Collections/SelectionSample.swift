import StateUI

/// One row chosen at a time - an optional identity, and nothing else to set.
private struct OneAtATime: ContentView {
    @State private var chosen: String? = "Beta"

    private static let rows = [
        "Alpha", "Beta", "Gamma", "Delta", "Epsilon", "Zeta", "Eta", "Theta",
        "Iota", "Kappa", "Lambda", "Mu", "Nu", "Xi", "Omicron", "Pi",
        "Rho", "Sigma", "Tau", "Upsilon", "Phi", "Chi", "Psi", "Omega",
    ]

    var content: Element {
        Grid {
            CollectionView(Self.rows) { row in
                Label(row)
                    .fontSize(15)
                    .padding(12, 8)
                    .verticalOptions(.center)
                    // A chosen row draws ITSELF: the template reads the same
                    // state the binding writes.
                    .backgroundColor(chosen == row ? Palette.selected : .transparent)
            }
            .selection($chosen)
            .gridRow(0)

            Label(chosen.map { "Chosen: \($0)" } ?? "Nothing chosen")
                .fontSize(13)
                .textColor(Palette.accent)
                .gridRow(1)
        }
        .rowDefinitions(.star, .auto)
        .rowSpacing(10)
    }

    /// The words under this half - the page places them, and on a held page
    /// they take a tab of their own. See `SampleContent.notes`.
    var notes: Element {
        VStack {
            Label("An OPTIONAL identity is one row at a time. Tap a row to choose it, tap "
                + "the chosen one again to clear it - there is no mode to set beside the "
                + "binding, because the binding's type already said which this is.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("A selection is made of ITEMS, not positions: the row's identity is what "
                + "the binding holds, so a chosen row keeps its choice when the list is "
                + "sorted, filtered or added to.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(12)
    }
}

/// As many rows as are tapped - a Set of identities, the same binding one type
/// along.
private struct AsManyAsYouLike: ContentView {
    @State private var chosen: Set<String> = ["Alpha", "Gamma"]

    private static let rows = [
        "Alpha", "Beta", "Gamma", "Delta", "Epsilon", "Zeta", "Eta", "Theta",
        "Iota", "Kappa", "Lambda", "Mu", "Nu", "Xi", "Omicron", "Pi",
        "Rho", "Sigma", "Tau", "Upsilon", "Phi", "Chi", "Psi", "Omega",
    ]

    var content: Element {
        Grid {
            CollectionView(Self.rows) { row in
                Label(row)
                    .fontSize(15)
                    .padding(12, 8)
                    .verticalOptions(.center)
                    .backgroundColor(chosen.contains(row) ? Palette.selected : .transparent)
            }
            .selection($chosen)
            .gridRow(0)

            Label(chosen.isEmpty
                ? "Nothing chosen"
                : "Chosen: \(chosen.sorted().joined(separator: ", "))")
                .fontSize(13)
                .textColor(Palette.accent)
                .gridRow(1)
        }
        .rowDefinitions(.star, .auto)
        .rowSpacing(10)
    }

    /// See `OneAtATime.notes`.
    var notes: Element {
        VStack {
            Label("A SET of identities is as many rows as are tapped, and it is the same "
                + "modifier as the half before this one - one binding of one type, and the "
                + "TYPE is the mode. Tapping a chosen row again takes it out again.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("What a chosen row LOOKS like is the template's business: it reads the "
                + "same state the binding writes, one line, and it can look like anything "
                + "at all - a wash, a tick, a bolder label.")
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

/// Choosing rows of a CollectionView - one at a time, or as many as are tapped.
struct SelectionSample: SampleContent {
    static let id = "selection"
    static let title = "Selection"
    static let summary = "Which rows of a list are chosen, one at a time or several."

    // Each half IS a scroller, so the page must not put it in one.
    static let scrolls = false

    // Two short paragraphs fit under a list without taking rows worth having,
    // so they stay where the eye already is instead of taking a tab.
    static let notesUnder = true

    /// Each list is given the WINDOW's height, so it shows as many rows as the
    /// screen has room for.
    static let fills = true

    static let code = """
        // -- ONE --

        struct OneAtATime: ContentView {
            @State private var chosen: String? = "Beta"

            private static let rows = [
                "Alpha", "Beta", "Gamma", "Delta", "Epsilon", "Zeta", "Eta",
                "Theta", "Iota", "Kappa", "Lambda", "Mu", "Nu", "Xi",
                "Omicron", "Pi", "Rho", "Sigma", "Tau", "Upsilon", "Phi",
                "Chi", "Psi", "Omega",
            ]

            var content: Element {
                Grid {
                    // One binding of one type - and the TYPE is the mode: an
                    // optional identity is one row at a time. There is no
                    // selectionMode to disagree with it.
                    CollectionView(Self.rows) { row in
                        Label(row)
                            .padding(12, 8)
                            // A chosen row draws ITSELF: the template reads
                            // the same state the binding writes.
                            .backgroundColor(chosen == row ? Palette.selected : .transparent)
                    }
                    .selection($chosen)
                    .gridRow(0)

                    Label(chosen.map { "Chosen: \\($0)" } ?? "Nothing chosen")
                        .gridRow(1)
                }
                // A STAR row is how a list is bounded: as tall as the window
                // allows, where a height in points would show the same few
                // rows on every screen.
                .rowDefinitions(.star, .auto)
                .rowSpacing(10)
            }
        }

        // -- SEVERAL --

        struct AsManyAsYouLike: ContentView {
            @State private var chosen: Set<String> = ["Alpha", "Gamma"]

            private static let rows = [
                "Alpha", "Beta", "Gamma", "Delta", "Epsilon", "Zeta", "Eta",
                "Theta", "Iota", "Kappa", "Lambda", "Mu", "Nu", "Xi",
                "Omicron", "Pi", "Rho", "Sigma", "Tau", "Upsilon", "Phi",
                "Chi", "Psi", "Omega",
            ]

            var content: Element {
                Grid {
                    // The same modifier, one type along: a Set is as many rows
                    // as are tapped.
                    CollectionView(Self.rows) { row in
                        Label(row)
                            .padding(12, 8)
                            .backgroundColor(chosen.contains(row) ? Palette.selected : .transparent)
                    }
                    .selection($chosen)
                    .gridRow(0)

                    Label(chosen.isEmpty
                        ? "Nothing chosen"
                        : "Chosen: \\(chosen.sorted().joined(separator: ", "))")
                        .gridRow(1)
                }
                .rowDefinitions(.star, .auto)
                .rowSpacing(10)
            }
        }
        """

    var parts: [SamplePart] {
        let one = OneAtATime()
        let several = AsManyAsYouLike()

        return [SamplePart(title: "ONE", view: one, notes: one.notes),
                SamplePart(title: "SEVERAL", view: several, notes: several.notes)]
    }

    var content: Element {
        VStack {
            OneAtATime()
            AsManyAsYouLike()
        }
        .spacing(16)
    }
}
