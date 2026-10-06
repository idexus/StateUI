import StateUI

/// EVERY PROPERTY CAN BE HANDED A BINDING: a font size, a colour, a flag, a
/// placeholder, a choice, a toggle - each a plain `@State` handed on as `$x`,
/// each carried by the host, and each row wearing its own build count so the
/// cost is on the screen: a write renders nobody, unless somebody reads.
struct BoundPropertiesSample: SampleContent, ExampleContent {
    // listing: BoundPropertiesSample
    /// A number the host WALKS: handed to `fontSize`, an assignment travels
    /// there under the label's law.
    @State private var size = 18.0   // a number: the host walks it

    /// A colour the host walks the same way.
    @State private var tint = Palette.accent   // a colour: the same

    /// Which of the two tints is worn - read by handlers alone.
    @State private var warm = true   // which tint: read by a handler alone

    /// A flag the host SETS as it stands.
    @State private var shown = true   // a flag: the host sets it

    /// Words the host writes.
    @State private var hint = "Type here"   // words: the host writes them

    /// A choice the host sets AND reports: the picker is handed `$choice`
    /// both ways, and nothing here reads it.
    @State private var choice = 1   // a choice: set and reported

    /// A toggle the host sets and reports - and one row READS it, which is
    /// the one row that renders.
    @State private var on = false   // a toggle: set and reported

    /// A MEMBER: an enum the host sets as it stands. It crosses as the
    /// member's number, which the host resolves.
    @State private var side = Alignment.start   // a member: the host sets it
    // listing: end

    static let id = "boundProperties"
    static let title = "Every property by binding"
    static let summary = "A size, a colour, a flag and more, each handed on as `$x` and carried by the host."

    // listing: BoundPropertiesSample
    var body: some View {
        VStack {
            // A JOURNEY. `size = 30` sends the font size there under the
            // label's law; the row is never built again.
            row("1 · a number the host walks - fontSize($size)") {
                Text("The quick brown fox")
                    .fontSize($size)
                DebugInfoLabel()   // stays at one
            }

            HStack {
                button("Smaller") { size = max(10, size - 4) }
                button("Bigger") { size = min(40, size + 4) }
            }
            .spacing(8)
            .horizontalAlignment(.center)

            row("2 · a colour the host walks - textColor($tint)") {
                Text("Tinted words")
                    .fontSize(17)
                    .textColor($tint)
                DebugInfoLabel()   // stays at one
            }

            button("Swap the tint") {
                warm.toggle()
                tint = warm ? Palette.accent : Palette.subtle
            }

            row("3 · a flag the host sets - isVisible($shown)") {
                Text("Now you see me")
                    .fontSize(15)
                    .isVisible($shown)
                DebugInfoLabel()
            }

            SwitchRow("Shown", $shown)

            row("4 · words the host writes - placeholder($hint)") {
                TextField()
                    .accessibilityIdentifier("boundProperties.hint")
                    .accessibilityLabel("A field whose placeholder the host writes")
                    .placeholder($hint)
                DebugInfoLabel()
            }

            button("Another hint") { hint = hint == "Type here" ? "Your name" : "Type here" }

            row("5 · a choice, both ways - selectedIndex($choice)") {
                Picker(["S", "M", "L"])
                    .accessibilityIdentifier("boundProperties.choice")
                    .accessibilityLabel("Size")
                    .selectedIndex($choice)
                DebugInfoLabel()
            }

            button("Choose L") { choice = 2 }

            row("6 · a member the host sets - horizontalAlignment($side)") {
                Text("Where am I?")
                    .fontSize(15)
                    .horizontalAlignment($side)
                DebugInfoLabel()
            }

            button("Move me along") {
                side = side == .start ? .center : side == .center ? .end : .start
            }

            row("7 · a toggle, both ways - and a label that reads it") {
                Switch($on)
                    .accessibilityIdentifier("boundProperties.on")
                    .accessibilityLabel("On")
                    .horizontalAlignment(.start)
                Text(on ? "on" : "off")
                    .fontSize(15)
                DebugInfoLabel()   // climbs on every flip
            }
        }
        .spacing(10)
    }
    // listing: end

    var notes: (any View)? {
        VStack {
            Text("Every property here is handed a plain `@State` as `$x`, and the host "
                + "carries it: a number and a colour are WALKED there under the "
                + "element's law, a flag is SET as it stands, words are WRITTEN, and a "
                + "choice or a toggle is set from the state and landed on it when the "
                + "user moves it. A MEMBER - an alignment, a keyboard, a line break - "
                + "crosses as its number and the host resolves it. "
                + "Every row wears its own build count, and only row 7 climbs: it is the "
                + "one whose braces read the value.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("The rule is the same one everywhere: a get makes the closure it sits "
                + "in a reader, a binding makes none. Properties like these have a twin "
                + "taking `Binding<T>` beside the value form - a number, a colour, "
                + "insets, a flag, a count, a string - so a value that moves is no "
                + "reason to build the view again.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(12)
    }

    // listing: BoundPropertiesSample
    /// One row: a caption, then the content in a stack of its own, so the
    /// reading taken inside the content is that stack's alone.
    private func row<Content: Views>(_ caption: String, @ViewBuilder _ content: @escaping () -> Content) -> some View {
        ZStack {
            VStack {
                Text(caption)
                    .fontSize(11)
                    .textColor(Palette.subtle)

                VStack(content: content)
                    .spacing(4)
            }
            .spacing(6)
        }
        .style("Card")
        .padding(10)
        .shape(.roundedRectangle(8))
        .stroke(Palette.outline)
    }

    /// One of the buttons, all of which look the same.
    private func button(_ caption: String, _ act: @escaping EventHandler) -> Button {
        Button(caption)
            .fontSize(13)
            .padding(horizontal: 14, vertical: 6)
            .onClicked(act)
    }
    // listing: end
}
