import StateUI

/// What a basket holds, as a class rather than a pile of `@State` in the view.
///
/// The properties the interface draws are `@State` - the same word, the same
/// storage and the same rule as in a view: a write asks the closures that READ
/// that property for another build, and no other. A plain `var` is stored and
/// nothing more, and this one is here to be SEEN not working: pressing the
/// button below raises it and the screen does not follow.
private final class Basket {
    @State var items: [String] = []
    @State var note = ""

    /// Counted for the sample's sake; nothing on screen is meant to follow it.
    var plainTaps = 0

    var summary: String {
        items.isEmpty ? "The basket is empty" : items.joined(separator: ", ")
    }
}

/// A child the basket was LENT to.
///
/// `@Binding`, the same wrapper an Int is borrowed with - a model is a value
/// like any other as far as lending is concerned. `$basket` says: I lend you
/// this, do with it what you want - and `basket.$note` is the note's own
/// state, the `Binding<String>` an Entry takes and the host carries.
private struct NoteRow: ContentView {
    @Binding var basket: Basket

    var content: Element {
        VStack {
            // The field is handed the note's own state and reads nothing; the
            // label below READS `note`, which is what builds this again.
            DebugInfoLabel()

            Entry(basket.$note)
                .automationId("stateClass.note")
                .semanticDescription("A note on the basket")
                .placeholder("A note on the basket")

            Label(basket.note.isEmpty ? "No note yet" : "Note: \(basket.note)")
                .fontSize(17)
                .horizontalTextAlignment(.center)
        }
        .spacing(14)
    }
}

/// A model in a class, edited in place - `@State` on its properties is what
/// makes the writes visible, and `@State` on the view is what keeps the
/// instance.
struct StateClassSample: SampleContent {
    @State private var basket = Basket()

    static let id = "stateClass"
    static let title = "State in a class"
    static let summary = "A class whose properties are @State lives in @State and is edited property by property."

    static let code = """
        final class Basket {
            @State var items: [String] = []
            @State var note = ""

            var plainTaps = 0

            var summary: String {
                items.isEmpty ? "The basket is empty" : items.joined(separator: ", ")
            }
        }

        struct NoteRow: ContentView {
            @Binding var basket: Basket

            var content: Element {
                VStack {
                    // The field is handed the note's own state and reads
                    // nothing; the label READS `note`, so typing rebuilds this.
                    DebugInfoLabel()

                    Entry(basket.$note)
                        .placeholder("A note on the basket")

                    Label(basket.note.isEmpty ? "No note yet" : "Note: \\(basket.note)")
                }
            }
        }

        @State private var basket = Basket()

        VStack {
            // And this one reads the items, so adding and removing rebuild it
            // - while typing a note leaves it standing.
            DebugInfoLabel()

            Label("\\(basket.items.count) item(s)")

            Label(basket.summary)

            HStack {
                Button("Add")
                    .onClicked { basket.items.append("Item \\(basket.items.count + 1)") }

                Button("Remove")
                    .isEnabled(!basket.items.isEmpty)
                    .onClicked { basket.items.removeLast() }
            }

            NoteRow(basket: $basket)

            Button("Tap a plain property (\\(basket.plainTaps))")
                .onClicked { basket.plainTaps += 1 }
        }
        """

    var content: Element {
        VStack {
            DebugInfoLabel()

            Label("\(basket.items.count) item(s)")
                .fontSize(22)
                .horizontalTextAlignment(.center)

            Label(basket.summary)
                .fontSize(15)
                .textColor(Palette.subtle)
                .horizontalTextAlignment(.center)

            HStack {
                Button("Add")
                    .backgroundColor(Palette.accent)
                    .textColor(.white)
                    .cornerRadius(8)
                    .padding(20, 10)
                    .onClicked { basket.items.append("Item \(basket.items.count + 1)") }

                Button("Remove")
                    .borderColor(Palette.outline)
                    .borderWidth(1)
                    .backgroundColor(.transparent)
                    .textColor(Palette.subtle)
                    .cornerRadius(8)
                    .padding(20, 10)
                    .isEnabled(!basket.items.isEmpty)
                    .onClicked { basket.items.removeLast() }
            }
            .spacing(12)
            .horizontalOptions(.center)

            Label("The basket is a CLASS, held in @State. The view's box holds a reference "
                + "to it, so `basket.items.append(…)` never writes through that box - the "
                + "write lands on the PROPERTY's own @State, and that is what asks for the "
                + "render. Both are needed: @State on the properties makes the writes "
                + "visible, @State on the view keeps the instance across the rebuild.")
                .fontSize(12)
                .textColor(Palette.subtle)

            NoteRow(basket: $basket)

            Label("The note is written by a child row the basket was LENT to - @Binding, "
                + "the same wrapper an Int is borrowed with. `basket.$note` is the note's "
                + "own state, handed to the field whole, and it works the same off the "
                + "view's own @State. No handler either way.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Button("Tap a plain property (\(basket.plainTaps))")
                .borderColor(Palette.outline)
                .borderWidth(1)
                .backgroundColor(.transparent)
                .textColor(Palette.subtle)
                .cornerRadius(8)
                .padding(20, 10)
                .onClicked { basket.plainTaps += 1 }

        }
        .spacing(14)
    }

    var notes: Element? {
        VStack {
            Label("That last count really is going up - press Add afterwards and it jumps "
                + "to where it got to. A plain `var` is stored and nothing more: a cache, a "
                + "scratch value, anything the interface does not draw - and writing it "
                + "asks for nothing.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("Swift's own @Observable is a different attribute reporting to a "
                + "different listener, and this library does not listen to it: a model "
                + "marked with it can be held in @State, and its writes redraw nothing. "
                + "The compiler says so on the line that holds it. What this library "
                + "hears is @State - in a view or in a class alike.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(10)
    }
}
