import StateUI

/// MAUI: Grid.
struct GridSample: SampleContent {
    @State private var wideSecondColumn = true

    static let id = "grid"
    static let title = "Grid"
    static let summary = "Rows and columns, sized the way MAUI sizes them - and placement written on the child."

    static let code = """
        @State private var wideSecondColumn = true

        VStack {
            Grid {
                GridCell(text: "Column 0, Row 0", color: "#E53935")

                GridCell(text: "Column 1, Row 0", color: "#1E88E5")
                    .gridColumn(1)

                GridCell(text: "Column 0, Row 1", color: "#00897B")
                    .gridRow(1)

                GridCell(text: "Column 1, Row 1", color: "#8E24AA")
                    .gridRow(1)
                    .gridColumn(1)

                GridCell(text: "Row 2, spanning both columns", color: "#F4511E")
                    .gridRow(2)
                    .gridColumnSpan(2)
            }
            .rowDefinitions(.absolute(64), .absolute(64), .auto)
            .columnDefinitions(.star, .star(wideSecondColumn ? 2 : 1))
            .rowSpacing(10)
            .columnSpacing(10)

            // Changing a definition patches the grid in place: the cells keep
            // their controls and only the column widths move.
            Button(wideSecondColumn ? "Columns: * and 2*" : "Columns: * and *")
                .onClicked { wideSecondColumn.toggle() }
        }

        private struct GridCell: ContentView {
            let text: String
            let color: String

            var content: Element {
                Label(text)
                    .textColor(.white)
                    .backgroundColor(Color.fromArgb(color))
                    .padding(8)
            }
        }
        """

    var content: Element {
        VStack {
            Grid {
                GridCell(text: "Column 0, Row 0", color: "#E53935")

                GridCell(text: "Column 1, Row 0", color: "#1E88E5")
                    .gridColumn(1)

                GridCell(text: "Column 0, Row 1", color: "#00897B")
                    .gridRow(1)

                GridCell(text: "Column 1, Row 1", color: "#8E24AA")
                    .gridRow(1)
                    .gridColumn(1)

                GridCell(text: "Row 2, spanning both columns", color: "#F4511E")
                    .gridRow(2)
                    .gridColumnSpan(2)
            }
            .rowDefinitions(.absolute(64), .absolute(64), .auto)
            .columnDefinitions(.star, .star(wideSecondColumn ? 2 : 1))
            .rowSpacing(10)
            .columnSpacing(10)

            // Changing a definition patches the grid in place: the cells keep
            // their controls and only the column widths move.
            Button(wideSecondColumn ? "Columns: * and 2*" : "Columns: * and *")
                .fontSize(13)
                .padding(16, 6)
                .horizontalOptions(.center)
                .onClicked { wideSecondColumn.toggle() }

            Label("Where a view sits is written on the VIEW, as in XAML: Grid.Row=\"1\" "
                + "is .gridRow(1). Those modifiers are on View, because any view can be "
                + "a grid child.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("The definitions travel in MAUI's own syntax - \"70,Auto\" and \"*,2*\" - "
                + "and go straight to MAUI's converter.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(12)
    }
}

/// One coloured cell, composed rather than built inline - and placed with
/// `.gridRow` and `.gridColumn` like any other view.
private struct GridCell: ContentView {
    let text: String
    let color: String

    var content: Element {
        Label(text)
            .fontSize(12)
            .textColor(.white)
            .backgroundColor(Color.fromArgb(color))
            .padding(8)
            .horizontalTextAlignment(.center)
            .verticalTextAlignment(.center)
    }
}
