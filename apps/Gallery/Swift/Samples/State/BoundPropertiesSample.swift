import StateUI

/// EVERY PROPERTY CAN BE HANDED A BINDING: a font size, a colour, a flag, a
/// placeholder, a choice, a toggle - each a plain `@State` handed on as `$x`,
/// each carried by the host, and each row wearing its own build count so the
/// cost is on the screen: a write renders nobody, unless somebody reads.
struct BoundPropertiesSample: SampleContent {
    /// A number the host WALKS: handed to `fontSize`, an assignment travels
    /// there under the label's law.
    @State private var size = 18.0

    /// A colour the host walks the same way.
    @State private var tint = Palette.accent

    /// Which of the two tints is worn - read by handlers alone.
    @State private var warm = true

    /// A flag the host SETS as it stands.
    @State private var shown = true

    /// Words the host writes.
    @State private var hint = "Type here"

    /// A choice the host sets AND reports: the picker is handed `$choice`
    /// both ways, and nothing here reads it.
    @State private var choice = 1

    /// A toggle the host sets and reports - and one row READS it, which is
    /// the one row that renders.
    @State private var on = false

    static let id = "boundProperties"
    static let title = "Every property by binding"
    static let summary = "A size, a colour, a flag, a placeholder, a choice, a toggle - "
        + "each handed on as `$x`, each carried by the host, none of them a reason to rebuild."

    static let code = """
        @State private var size = 18.0            // a number: the host walks it
        @State private var tint = Palette.accent  // a colour: the same
        @State private var shown = true           // a flag: the host sets it
        @State private var hint = "Type here"     // words: the host writes them
        @State private var choice = 1             // a choice: set and reported
        @State private var on = false             // a toggle: set and reported

        VStack {
            // A JOURNEY. `size = 30` sends the font size there under the
            // label's law; the row is never built again.
            VStack {
                Label("The quick brown fox").fontSize($size)
                Label(debugInfo())                          // stays at one
            }
            Button("Bigger").onClicked { size = min(40, size + 4) }

            // A colour walks the same way.
            Label("Tinted").textColor($tint)

            // A PLAIN flag: set as it stands, nothing walks.
            Label("Now you see me").isVisible($shown)
            Switch($shown)

            // WORDS: written by the host as the state changes.
            Entry().placeholder($hint)

            // BOTH WAYS: the host sets the choice from the state and lands
            // the reader's pick on it - and nothing here reads `choice`.
            Picker(["S", "M", "L"]).selectedIndex($choice)
            Button("Choose L").onClicked { choice = 2 }

            // The one row that READS: `on` printed in its braces makes it a
            // reader, so a flip renders this row and no other.
            VStack {
                Switch($on)
                Label(on ? "on" : "off")
                Label(debugInfo())                          // climbs on every flip
            }
        }
        """

    var example: Element {
        VStack {
            row("1 · a number the host walks - fontSize($size)") {
                Label("The quick brown fox")
                    .fontSize($size)
                Label(BuildCount.of(debugInfo()))
                    .fontSize(12)
                    .textColor(Palette.accent)
            }

            HStack {
                button("Smaller") { size = max(10, size - 4) }
                button("Bigger") { size = min(40, size + 4) }
            }
            .spacing(8)
            .horizontalOptions(.center)

            row("2 · a colour the host walks - textColor($tint)") {
                Label("Tinted words")
                    .fontSize(17)
                    .textColor($tint)
                Label(BuildCount.of(debugInfo()))
                    .fontSize(12)
                    .textColor(Palette.accent)
            }

            button("Swap the tint") {
                warm.toggle()
                tint = warm ? Palette.accent : Palette.subtle
            }

            row("3 · a flag the host sets - isVisible($shown)") {
                Label("Now you see me")
                    .fontSize(15)
                    .isVisible($shown)
                Label(BuildCount.of(debugInfo()))
                    .fontSize(12)
                    .textColor(Palette.accent)
            }

            SwitchRow("Shown", $shown)

            row("4 · words the host writes - placeholder($hint)") {
                Entry()
                    .placeholder($hint)
                Label(BuildCount.of(debugInfo()))
                    .fontSize(12)
                    .textColor(Palette.accent)
            }

            button("Another hint") { hint = hint == "Type here" ? "Your name" : "Type here" }

            row("5 · a choice, both ways - selectedIndex($choice)") {
                Picker(["S", "M", "L"])
                    .selectedIndex($choice)
                Label(BuildCount.of(debugInfo()))
                    .fontSize(12)
                    .textColor(Palette.accent)
            }

            button("Choose L") { choice = 2 }

            row("6 · a toggle, both ways - and a label that READS it") {
                Switch($on)
                    .horizontalOptions(.start)
                Label(on ? "on" : "off")
                    .fontSize(15)
                Label(BuildCount.of(debugInfo()))
                    .fontSize(12)
                    .textColor(Palette.accent)
            }
        }
        .spacing(10)
    }

    var notes: Element? {
        VStack {
            Label("Every property here is handed a plain `@State` as `$x`, and the host "
                + "carries it: a number and a colour are WALKED there under the "
                + "element's law, a flag is SET as it stands, words are WRITTEN, and a "
                + "choice or a toggle is set from the state and landed on it when the "
                + "reader moves it. Every row wears its own build count, and only row 6 "
                + "climbs: it is the one whose braces read the value.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("The rule is the same one everywhere: a get makes the closure it sits "
                + "in a reader, a binding makes none. What a property can be handed is "
                + "every value form's twin taking `Binding<T>` - a number, a colour, a "
                + "thickness, a flag, a count, a string - so a value that moves is never "
                + "a reason to build the view again.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(12)
    }

    /// One row: a caption, then the content in a stack of its own, so the
    /// reading taken inside the content is that stack's alone.
    private func row(_ caption: String, @ViewBuilder _ content: @escaping () -> [Element]) -> Element {
        Border {
            VStack {
                Label(caption)
                    .fontSize(11)
                    .textColor(Palette.subtle)

                VStack(content: content)
                    .spacing(4)
            }
            .spacing(6)
        }
        .padding(10)
        .strokeShape(.roundRectangle(8))
        .stroke(Palette.outline)
    }

    /// One of the buttons, all of which look the same.
    private func button(_ caption: String, _ act: @escaping EventHandler) -> Button {
        Button(caption)
            .fontSize(13)
            .padding(14, 6)
            .onClicked(act)
    }
}
