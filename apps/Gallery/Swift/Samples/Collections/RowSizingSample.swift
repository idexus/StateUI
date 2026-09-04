import StateUI

/// Rows that are each their own height, and the one measurement that answers
/// for all of them.
struct RowSizingSample: SampleContent {
    static let id = "rowSizing"
    static let title = "Rows of their own size"
    static let summary = "One item measured answers for all of them - or every item is measured, and each row is as tall as what is in it."

    static let scrolls = false
    static let fills = true

    /// Posts of very different lengths, which is what makes the difference
    /// visible at all.
    static let posts: [(id: Int, from: String, said: String)] = [
        (1, "Ada", "Morning."),
        (2, "Grace", "The compiler is finished. It takes the words a person would "
            + "write and turns them into the machine's own, which is the whole "
            + "of the idea and the part nobody believed."),
        (3, "Alan", "Yes."),
        (4, "Edsger", "Two things. The first is that a program is a proof, and the "
            + "second is that this is not a metaphor."),
        (5, "Barbara", "Agreed - and the interface is what the proof is about."),
        (6, "Ada", "Then we should write the interface down first."),
        (7, "Grace", "It is already written down. It is the part that moves."),
        (8, "Alan", "Quite."),
        (9, "Edsger", "A list whose rows are all the same height is a list of one "
            + "row repeated. Real lists are not like that, and this one is not "
            + "either: every line here is as tall as what is in it, measured "
            + "one row at a time."),
        (10, "Barbara", "Good night."),
    ]

    static let code = """
        // EVERY ITEM IS MEASURED, so each row is as tall as what is in it.
        // The default measures ONE row and gives every other one the same
        // size - which is what makes a list of a hundred thousand rows cost
        // what a list of ten does, and is exact whenever the rows are alike.
        CollectionView(posts, id: \\.id) { post in
            VStack {
                Label(post.from).fontAttributes(.bold)
                Label(post.said)
            }
            .padding(Thickness(14, 10, 14, 10))
        }
        .itemSizingStrategy(.measureAllItems)
        """

    var example: Element {
        Grid {
            CollectionView(Self.posts, id: \.id) { post in
                VStack {
                    Label(post.from)
                        .fontSize(13)
                        .fontAttributes(.bold)
                        .textColor(Palette.accent)

                    Label(post.said)
                        .fontSize(14)
                        .textColor(Palette.text)
                }
                .spacing(2)
                .padding(Thickness(14, 10, 14, 10))
            }
            .itemSizingStrategy(.measureAllItems)
            .gridRow(0)
        }
        .rowDefinitions(.star)
    }

    var notes: Element? {
        VStack {
            Label("Every row here is as tall as what is in it: a one-word reply "
                + "takes one line and a paragraph takes four. That is "
                + "`.itemSizingStrategy(.measureAllItems)`, which is MAUI's own "
                + "name for the choice.")
                .fontSize(13)
                .textColor(Palette.subtle)

            Label("The default is the other one, and it is the default for a "
                + "reason: measuring ONE item and giving every other one the "
                + "same size means where a row sits is one multiplication, so a "
                + "list of a hundred thousand rows costs what a list of ten "
                + "does. Measuring every item walks every item, so it is for a "
                + "list of tens or hundreds.")
                .fontSize(13)
                .textColor(Palette.subtle)

            Label("A row that has never been on screen has never been measured, "
                + "so the length of the run is an estimate until it has - and "
                + "the rows the reader has already passed ARE measured, which "
                + "is why nothing above them ever shifts.")
                .fontSize(13)
                .textColor(Palette.subtle)
        }
        .spacing(8)
    }
}
