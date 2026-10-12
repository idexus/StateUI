import StateUI

/// The two non-wrapping stack directions.
struct StackLayoutSample: SampleContent, ExampleContent {
    // listing: StackLayoutSample
    @State private var spaced = true
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

            SectionTitle("Spacer")

            // A spacer takes the room the other children leave.
            HStack {
                StackCell(text: "Draft")
                if spaced { Spacer() }
                StackCell(text: "Send")
            }
            .spacing(8)

            HStack {
                Switch($spaced)
                    .accessibilityIdentifier("stackLayout.spaced")
                    .accessibilityLabel("Spacer")

                Text("Spacer")
                    .verticalAlignment(.center)
            }
            .spacing(12)

            SectionTitle("Divider")

            // The platform's own line, across its stack.
            VStack {
                Text("Inbox")
                Divider()
                Text("Archive")
            }
            .spacing(8)

            HStack {
                Text("Bold")
                Divider()
                Text("Italic")
            }
            .spacing(8)
        }
        .spacing(12)
    }
    // listing: end

    var notes: (any View)? {
        Text("`.horizontalAlignment` places a child across the room its stack gives it. A `Spacer` takes the room "
            + "its siblings leave; a `Divider` draws the platform's line across its stack.")
            .fontSize(12)
            .textColor(Palette.subtle)
    }
}

// listing: StackLayoutSample
/// One block of colour with a word in it, so an arrangement is visible.
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
