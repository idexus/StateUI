import StateUI

/// Where the state a row shows has to live, once the rows themselves come
/// and go with the window.
struct RowStateSample: SampleContent {
    @State private var notes: [Int: String] = [:]
    @State private var done: Set<Int> = []

    static let id = "rowState"
    static let title = "Row state"
    static let summary = "A row lives while the window holds it - so what must outlive it belongs to the page."

    // Two lists that scroll themselves, so the page holds still - and take the
    // window's height rather than a number, since a list is as useful as the
    // rows it can show.
    static let scrolls = false
    static let fills = true

    // EXAMPLE 2 is the TRAP, not the recipe: it shows state kept in the row,
    // which the window throws away. Naming it here puts the warning triangle
    // on its tab, on its heading and over its code, so a reader who lands on
    // the second half is told before they copy it.
    static let warns: Set<String> = ["EXAMPLE 2"]

    static let code = """
        // -- EXAMPLE 1 --

        // The ITEM is the row's identity, so what a row shows can be kept
        // here, keyed by the item - and it then outlives the row itself,
        // which lives only while the window holds it.
        @State private var notes: [Int: String] = [:]
        @State private var done: Set<Int> = []

        // A STAR row is what bounds the list, rather than a height in points:
        // it is then as tall as the window allows, and the words under it
        // keep their own height.
        Grid {
            CollectionView(Array(1...300)) { row in
                HStack {
                    CheckBox(done.contains(row))
                        .onCheckedChanged { on in
                            if on { done.insert(row) } else { done.remove(row) }
                        }

                    Label("Row \\(row)")

                    Entry(notes[row] ?? "")
                        .placeholder("note")
                        .onTextChanged { notes[row] = $0 }
                        .horizontalOptions(.fill)
                }
            }
            .gridRow(0)

            Label("\\(done.count) ticked")
                .gridRow(1)
        }
        .rowDefinitions(.star, .auto)

        // -- EXAMPLE 2 --

        // And what a row keeps ITSELF: it lives as long as the row does,
        // which is as long as the window holds it. Tap a few, scroll far
        // away and back, and they are zero again - the rows were built
        // afresh when the window reached them.
        struct Tally: ContentView {
            let row: Int
            @State var count = 0

            var content: Element {
                HStack {
                    Label("Row \\(row)")
                    Button("Tap: \\(count)").onClicked { count += 1 }
                }
            }
        }

        Grid {
            CollectionView(Array(1...300)) { Tally(row: $0) }
                .gridRow(0)
        }
        .rowDefinitions(.star)
        """

    var parts: [SamplePart] {
        // `words` rather than `notes` on the halves: this sample's own state is
        // called `notes` - what a reader types into a row - and one name for
        // two things reads worse than two names do.
        let page = KeptByThePage(notes: $notes, done: $done)
        let row = KeptByTheRow()

        return [
            SamplePart(title: "EXAMPLE 1", view: page, notes: page.words),
            SamplePart(title: "EXAMPLE 2", view: row, notes: row.words),
        ]
    }

    var content: Element {
        KeptByThePage(notes: $notes, done: $done)
    }
}

/// What outlives everything: the page holds the state, keyed by the item.
private struct KeptByThePage: ContentView {
    @Binding var notes: [Int: String]
    @Binding var done: Set<Int>

    // A STAR row rather than a height in points: the list is bounded by the
    // cell it is given, so it is as tall as the window allows and the words
    // under it keep their own height.
    var content: Element {
        Grid {
            CollectionView(Array(1...300)) { row in
                HStack {
                    CheckBox(done.contains(row))
                        .onCheckedChanged { on in
                            if on { done.insert(row) } else { done.remove(row) }
                        }

                    Label("Row \(row)")
                        .fontSize(14)
                        .widthRequest(70)
                        .verticalOptions(.center)

                    Entry(notes[row] ?? "")
                        .placeholder("note")
                        .fontSize(14)
                        .onTextChanged { notes[row] = $0 }
                        .horizontalOptions(.fill)
                }
                .spacing(8)
                .padding(12, 4)
            }
            .gridRow(0)

            Label("\(done.count) ticked, \(notes.values.filter { !$0.isEmpty }.count) noted")
                .fontSize(13)
                .textColor(Palette.accent)
                .gridRow(1)
        }
        .rowDefinitions(.star, .auto)
        .rowSpacing(10)
    }

    /// The words under this half - the tally above is a READING and stays with
    /// the example. See `SampleContent.notes`.
    var words: Element {
        Label("Tick a few and type into them, then scroll far away and back: everything "
            + "is still there. The state is the PAGE's, keyed by the item - which is why "
            + "it survives the row itself going, and a row goes as soon as the window "
            + "leaves it behind.")
            .fontSize(12)
            .textColor(Palette.subtle)
    }
}

/// And what a row keeps itself: it lives as long as the row does.
private struct KeptByTheRow: ContentView {
    var content: Element {
        Grid {
            // Said ABOVE the list, where somebody who only tries the example
            // reads it: the triangle is the same one the tab and the code
            // section wear.
            HStack {
                WarningMark().size(16)

                Label("What this example shows is what NOT to rely on: the counts below "
                    + "are the rows' own, and the window throws them away.")
                    .fontSize(12)
                    .textColor(Palette.subtle)
                    .horizontalOptions(.fill)
            }
            .spacing(8)
            .gridRow(0)

            CollectionView(Array(1...300)) { row in
                Tally(row: row)
            }
            .gridRow(1)

        }
        .rowDefinitions(.auto, .star)
        .rowSpacing(10)
    }

    /// The words under this half - the warning above it stays with the
    /// example, where somebody who only tries it reads it. See
    /// `SampleContent.notes`.
    var words: Element {
        VStack {
            Label("The same list, with the count kept INSIDE the row. Tap a few and scroll a "
                + "little: they are as you left them, because the window still holds those "
                + "rows and a row that stays is never rebuilt. Scroll far away and back and "
                + "they are zero - the rows were let go, and built afresh when the window "
                + "reached them again.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("That is the rule a list that describes only what is in view has, and a "
                + "full one does not: a row's own "
                + "state lives as long as the ROW, and the row lives as long as the window. "
                + "Anything that must outlive the window belongs in the page, as EXAMPLE 1 "
                + "does - which is also where text typed into an Entry belongs, since no "
                + "control survives its row either.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(10)
    }
}

/// A row that counts its own taps - the state that lives with the row.
private struct Tally: ContentView {
    let row: Int
    @State private var count = 0

    var content: Element {
        HStack {
            Label("Row \(row)")
                .fontSize(14)
                .widthRequest(70)
                .verticalOptions(.center)

            // The look a button wears in a LIST ROW - compact, and without
            // the touch floor a row's height would fight. See AppStyles.
            Button("Tap: \(count)")
                .style("RowChip")
                .onClicked { count += 1 }
        }
        .spacing(8)
        .padding(12, 4)
    }
}
