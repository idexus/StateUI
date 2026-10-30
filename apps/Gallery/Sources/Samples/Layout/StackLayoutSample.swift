import StateUI

/// The two stack directions, and a row that wraps.
struct StackLayoutSample: SampleContent, ExampleContent {
    // listing: StackLayoutSample
    @State private var spaced = true
    @State private var onBaseline = true
    @State private var wraps = true
    static let tags = [
        "Button", "Toggle", "Slider", "Picker", "Text", "Image", "Stack", "Grid",
        "Scroll", "List", "Map", "Sheet", "Menu", "Toolbar", "Tab", "Split",
    ]
    // listing: end

    static let id = "stackLayout"
    static let title = "Stack layouts"
    static let summary = "Children top to bottom or left to right, with room and lines between them."

    // listing: StackLayoutSample
    var body: some View {
        VStack {
            SectionTitle("Vertical")

            VStack {
                StackCell(text: "One")
                StackCell(text: "Two")
                StackCell(text: "Three")
            }
            .spacing(8)

            SectionTitle("Horizontal")

            HStack {
                StackCell(text: "One")
                StackCell(text: "Two")
                StackCell(text: "Three")
            }
            .spacing(8)

            SectionTitle("Alignment")

            // Where a child sits in the room its stack gives it.
            VStack {
                StackCell(text: "start")
                    .horizontalAlignment(.start)

                StackCell(text: "center")
                    .horizontalAlignment(.center)

                StackCell(text: "end")
                    .horizontalAlignment(.end)

                StackCell(text: "fill")
                    .horizontalAlignment(.fill)
            }
            .spacing(8)

            SectionTitle("First baseline")

            // A label and a value of other sizes reading as one line: each
            // rests its first line of words on the row's baseline.
            HStack {
                Text("Total")
                    .fontSize(13)
                    .verticalAlignment(onBaseline ? .firstBaseline : .center)
                Text("€120")
                    .fontSize(34)
                    .fontWeight(.bold)
                    .verticalAlignment(onBaseline ? .firstBaseline : .center)
            }
            .spacing(8)

            Switch($onBaseline)
                .text("On one baseline")
                .accessibilityIdentifier("stackLayout.baseline")

            SectionTitle("Space")

            // A space takes the room the other children leave.
            HStack {
                StackCell(text: "Draft")
                if spaced { Space() }
                StackCell(text: "Send")
            }
            .spacing(8)

            Switch($spaced)
                .text("Space")
                .accessibilityIdentifier("stackLayout.spaced")

            SectionTitle("Short of room")

            // A row short of room takes it from its words: the button stays
            // whole, and the title wraps to what is left - or, kept to one
            // line, ends where the room does.
            HStack {
                Text("A title longer than the row has room for beside its button")
                Button("Open")
            }
            .spacing(8)

            HStack {
                Text("A title longer than the row has room for beside its button")
                    .maximumLines(1)
                Button("Open")
            }
            .spacing(8)

            SectionTitle("Wraps")

            // A row that wraps goes on onto the next line where its room
            // ends; on one line, its words share the room it has.
            HStack {
                ForEach(Self.tags, id: \.self) { StackCell(text: $0) }
            }
            .wraps(wraps)
            .spacing(8)
            .rowSpacing(8)

            Switch($wraps)
                .text("Wraps")
                .accessibilityIdentifier("stackLayout.wraps")

            SectionTitle("Separator")

            // The platform's own line, across its stack.
            VStack {
                Text("Inbox")
                Separator()
                Text("Archive")
            }
            .spacing(8)

            HStack {
                Text("Bold")
                    .fontWeight(.bold)
                Separator()
                Text("Italic")
                    .fontAttributes(.italic)
            }
            .spacing(8)
        }
        .spacing(12)
    }
    // listing: end

    var notes: (any View)? {
        Text("`.horizontalAlignment` places a child across the room its stack gives it; `.firstBaseline` rests "
            + "words of other sizes on one line. A `Space` takes the room its siblings leave; a row short of room "
            + "takes it from its words, and `.wraps(true)` goes on onto further lines; a `Separator` draws the "
            + "platform's line across its stack.")
            .fontSize(12)
            .textColor(Palette.subtle)
    }
}

// listing: StackLayoutSample
/// One block of color with a word in it, so an arrangement is visible.
private struct StackCell: View {
    let text: String

    var body: some View {
        Text(text)
            .fontSize(13)
            .textColor(.white)
            .background(Palette.accent)
            .padding(horizontal: 14, vertical: 8)
            .horizontalTextAlignment(.center)
    }
}
// listing: end
