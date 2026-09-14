import StateUI

/// The two non-wrapping stack directions.
struct StackLayoutSample: SampleContent, ExampleContent {
    static let id = "stackLayout"
    static let title = "Stack layouts"
    static let summary = "Children top to bottom or left to right."

    static let code = """
        VStack {
            StackCell(text: "One")
            StackCell(text: "Two")
            StackCell(text: "Three")
        }
        .spacing(8)

        HStack {
            StackCell(text: "One")
            StackCell(text: "Two")
            StackCell(text: "Three")
        }
        .spacing(8)

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

        private struct StackCell: ContentView {
            let text: String

            var content: any View {
                Label(text)
                    .textColor(.white)
                    .background(Palette.accent)
                    .padding(14, 8)
            }
        }
        """

    var content: any View {
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
        }
        .spacing(12)
    }

    var notes: Element? {
        Label("`.horizontalAlignment` places a child across the room its stack gives it.")
            .fontSize(12)
            .textColor(Palette.subtle)
    }
}

/// One block of colour with a word in it, so an arrangement is visible.
private struct StackCell: ContentView {
    let text: String

    var content: any View {
        Label(text)
            .fontSize(13)
            .textColor(.white)
            .background(Palette.accent)
            .padding(14, 8)
            .horizontalTextAlignment(.center)
    }
}
