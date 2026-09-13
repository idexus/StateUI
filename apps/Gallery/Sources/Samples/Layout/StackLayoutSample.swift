import StateUI

/// MAUI: VerticalStackLayout and HorizontalStackLayout.
struct StackLayoutSample: SampleContent {
    static let id = "stackLayout"
    static let title = "Stack layouts"
    static let summary = "Children top to bottom or left to right - and the one place a short name is offered."

    static let code = """
        // VStack and HStack are aliases for VerticalStackLayout and
        // HorizontalStackLayout. Both spellings work.
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
                .horizontalOptions(.start)

            StackCell(text: "center")
                .horizontalOptions(.center)

            StackCell(text: "end")
                .horizontalOptions(.end)

            StackCell(text: "fill")
                .horizontalOptions(.fill)
        }
        .spacing(8)

        private struct StackCell: ContentView {
            let text: String

            var content: any View {
                Label(text)
                    .textColor(.white)
                    .backgroundColor(Palette.accent)
                    .padding(14, 8)
            }
        }
        """

    var content: any View {
        VStack {
            SectionTitle("VERTICAL")

            VStack {
                StackCell(text: "One")
                StackCell(text: "Two")
                StackCell(text: "Three")
            }
            .spacing(8)

            SectionTitle("HORIZONTAL")

            HStack {
                StackCell(text: "One")
                StackCell(text: "Two")
                StackCell(text: "Three")
            }
            .spacing(8)

            SectionTitle("LAYOUT OPTIONS")

            VStack {
                StackCell(text: "start")
                    .horizontalOptions(.start)

                StackCell(text: "center")
                    .horizontalOptions(.center)

                StackCell(text: "end")
                    .horizontalOptions(.end)

                StackCell(text: "fill")
                    .horizontalOptions(.fill)
            }
            .spacing(8)

        }
        .spacing(12)
    }

    var notes: Element? {
        Label("`.horizontalOptions` is MAUI's HorizontalOptions: where a child sits "
            + "across the room its stack gives it.")
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
            .backgroundColor(Palette.accent)
            .padding(14, 8)
            .horizontalTextAlignment(.center)
    }
}
