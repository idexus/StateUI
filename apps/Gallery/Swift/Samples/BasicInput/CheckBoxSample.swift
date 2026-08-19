import StateUI

/// MAUI: CheckBox.
struct CheckBoxSample: SampleContent {
    @State private var agreed = false
    @State private var extras = [false, false, false]

    static let id = "checkBox"
    static let title = "CheckBox"
    static let summary = "A box ticked or not - and no caption, because MAUI's has none."

    static let code = """
        @State private var agreed = false
        @State private var extras = [false, false, false]

        VStack {
            HStack {
                CheckBox($agreed)

                Label("I have read the terms")
                    .verticalOptions(.center)
            }

            Label(agreed ? "Ticked" : "Not ticked")

            ForEach(Array(["Cheese", "Bacon", "Egg"].enumerated()), id: \\.offset) { pair in
                let (index, name) = pair
                return HStack {
                    CheckBox(extras[index])
                        .onCheckedChanged { ticked in extras[index] = ticked }

                    Label(name)
                        .verticalOptions(.center)
                }
                .id(name)
            }
        }
        """

    var content: Element {
        VStack {
            HStack {
                CheckBox($agreed)
                    .color(Palette.accent)

                Label("I have read the terms")
                    .fontSize(15)
                    .verticalOptions(.center)
            }
            .spacing(4)

            Label(agreed ? "Ticked" : "Not ticked")
                .fontSize(15)
                .textColor(agreed ? Palette.accent : Palette.subtle)

            Label("A CheckBox is the box and nothing else - MAUI gives it no caption, so "
                + "the Label beside it is a Label. Tapping the words does nothing; that is "
                + "the platform's behaviour and it is the same in MAUI written by hand.")
                .fontSize(12)
                .textColor(Palette.subtle)

            SectionTitle("SEVERAL OF THEM")

            ForEach(Array(["Cheese", "Bacon", "Egg"].enumerated()), id: \.offset) { pair in
                let (index, name) = pair
                return HStack {
                    CheckBox(extras[index])
                        .color(Palette.accent)
                        .onCheckedChanged { ticked in extras[index] = ticked }

                    Label(name)
                        .fontSize(15)
                        .verticalOptions(.center)
                }
                .spacing(4)
                .id(name)
            }

            Label(chosen.isEmpty ? "Nothing extra" : "With \(chosen.joined(separator: ", "))")
                .fontSize(15)

            Label("Boxes are independent - tick as many as you like. One choice out of "
                + "several is a RadioButton.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(12)
    }

    /// What is ticked, in the order the boxes are drawn.
    private var chosen: [String] {
        ["Cheese", "Bacon", "Egg"].enumerated().filter { extras[$0.offset] }.map { $0.element }
    }
}
