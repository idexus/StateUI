import StateUI

/// MAUI: VisualElement.FlowDirection.
struct FlowDirectionSample: SampleContent {
    static let id = "flowDirection"
    static let title = "Flow direction"
    static let summary = "Laying a view out for a language written right to left."

    static let code = """
        VStack {
            // Left to right, whatever the view above says.
            HStack {
                BoxView(Palette.accent).widthRequest(60).heightRequest(20)
                Label("First")
                Label("Second")
            }
            .flowDirection(.leftToRight)

            // Mirrored: the row fills from the right, and the text with it.
            HStack {
                BoxView(Palette.accent).widthRequest(60).heightRequest(20)
                Label("First")
                Label("Second")
            }
            .flowDirection(.rightToLeft)

            // The default: whatever the view above says, which is why an
            // application usually says it once, high up.
            HStack {
                BoxView(Palette.accent).widthRequest(60).heightRequest(20)
                Label("First")
                Label("Second")
            }
            .flowDirection(.matchParent)
        }
        """

    var example: Element {
        VStack {
            row("leftToRight", .leftToRight)
            row("rightToLeft", .rightToLeft)
            row("matchParent", .matchParent)
        }
        .spacing(16)
    }

    var notes: Element? {
        VStack {
            Label("A view told `.rightToLeft` mirrors its layout: a row fills from the "
                + "right, padding swaps sides, and text finds its natural alignment at "
                + "the other edge. It is what a language written right to left needs, "
                + "and it is one modifier rather than a second set of layouts.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("It is INHERITED. A view left at `.matchParent` - which is the default "
                + "- takes whatever the view above it has, so an application usually says "
                + "it once, high up, and everything below follows.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(8)
    }

    /// One row laid out each way, with the value that produced it.
    private func row(_ caption: String, _ direction: FlowDirection) -> Element {
        VStack {
            Label(caption)
                .fontSize(11)
                .textColor(Palette.subtle)

            HStack {
                BoxView(Palette.accent)
                    .widthRequest(60)
                    .heightRequest(20)

                Label("First")
                Label("Second")
            }
            .spacing(10)
            .flowDirection(direction)
        }
        .spacing(6)
    }
}
