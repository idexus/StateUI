import StateUI

/// What a basket holds, as a class rather than a pile of `@State`.
///
/// `@StateClass` is what makes a write to any of these ask for another render.
/// `@Untracked` is the opt-out, and this one is here to be SEEN not working:
/// pressing the button below raises it and the screen does not follow.
@StateClass
private final class Basket {
    var items: [String] = []
    var note = ""

    /// Counted for the sample's sake; nothing on screen is meant to follow it.
    @Untracked var untrackedTaps = 0

    var summary: String {
        items.isEmpty ? "The basket is empty" : items.joined(separator: ", ")
    }
}

/// A child the basket was LENT to.
///
/// `@Binding`, the same wrapper an Int is borrowed with - a model is a value
/// like any other as far as lending is concerned. `$basket` says: I lend you
/// this, do with it what you want, which includes handing one property of it
/// onwards - `$basket.note` is the `Binding<String>` an Entry takes.
private struct NoteRow: ContentView {
    @Binding var basket: Basket

    var content: Element {
        VStack {
            Entry($basket.note)
                .placeholder("A note on the basket")

            Label(basket.note.isEmpty ? "No note yet" : "Note: \(basket.note)")
                .fontSize(17)
                .horizontalTextAlignment(.center)
        }
        .spacing(14)
    }
}

/// A model in a class, edited in place - `@StateClass` is what makes the writes
/// visible, and `@State` is what keeps the instance.
struct StateClassSample: SampleContent {
    @State private var basket = Basket()

    static let id = "stateClass"
    static let title = "State in a class"
    static let summary = "A class marked @StateClass can live in @State and be edited property by property."

    static let code = """
        @StateClass
        final class Basket {
            var items: [String] = []
            var note = ""

            @Untracked var untrackedTaps = 0

            var summary: String {
                items.isEmpty ? "The basket is empty" : items.joined(separator: ", ")
            }
        }

        struct NoteRow: ContentView {
            @Binding var basket: Basket

            var content: Element {
                VStack {
                    Entry($basket.note)
                        .placeholder("A note on the basket")

                    Label(basket.note.isEmpty ? "No note yet" : "Note: \\(basket.note)")
                }
            }
        }

        @State private var basket = Basket()

        VStack {
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

            Button("Tap an @Untracked property (\\(basket.untrackedTaps))")
                .onClicked { basket.untrackedTaps += 1 }
        }
        """

    var content: Element {
        VStack {
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

            Label("The basket is a CLASS, held in @State. A @State holds a reference to it, "
                + "so `basket.items.append(…)` never writes through the box - which is "
                + "exactly what @StateClass fixes: it gives every stored property the two "
                + "lines that say the interface needs drawing again. Both halves are "
                + "needed - @StateClass makes the writes visible, @State keeps the "
                + "instance across the rebuild.")
                .fontSize(12)
                .textColor(Palette.subtle)

            NoteRow(basket: $basket)

            Label("The note is written by a child row the basket was LENT to - @Binding, "
                + "the same wrapper an Int is borrowed with. `$basket.note` is a binding "
                + "to that one property, and it works the same off the view's own @State. "
                + "No handler either way.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Button("Tap an @Untracked property (\(basket.untrackedTaps))")
                .borderColor(Palette.outline)
                .borderWidth(1)
                .backgroundColor(.transparent)
                .textColor(Palette.subtle)
                .cornerRadius(8)
                .padding(20, 10)
                .onClicked { basket.untrackedTaps += 1 }

            Label("That last count really is going up - press Add afterwards and it jumps "
                + "to where it got to. @Untracked means the property is stored and nothing "
                + "more: a cache, a scratch value, anything the interface does not draw.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(14)
    }
}
