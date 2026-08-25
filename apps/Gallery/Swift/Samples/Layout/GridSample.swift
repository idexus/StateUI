import StateUI

/// MAUI: Grid.
struct GridSample: SampleContent {
    @State private var wideSecondColumn = true
    @State private var redInFront = false

    static let id = "grid"
    static let title = "Grid"
    static let summary = "Rows and columns, sized the way MAUI sizes them - and placement written on the child."

    static let code = """
        @State private var wideSecondColumn = true
        @State private var redInFront = false

        VStack {
            Grid {
                // One cell down the whole left side, beside two that stay in
                // a row each.
                GridCell(text: "Column 0, Rows 0 and 1", color: "#E53935")
                    .gridRowSpan(2)

                GridCell(text: "Column 1, Row 0", color: "#1E88E5")
                    .gridColumn(1)

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
            SwitchRow("Second column twice as wide", $wideSecondColumn)
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

        // -- TWO VIEWS IN ONE CELL --

        // Nothing stops two children claiming the same cell. They overlap, and
        // zIndex decides which is drawn on top - the higher number is nearer
        // the front. Left alone, the one written LAST wins.
        Grid {
            BoxView(Color.fromArgb("#E53935"))
                .horizontalOptions(.start)
                .zIndex(redInFront ? 1 : 0)

            BoxView(Color.fromArgb("#1E88E5"))
                .horizontalOptions(.end)
                .zIndex(redInFront ? 0 : 1)
        }

        SwitchRow("Red in front", $redInFront)
        """

    var content: Element {
        VStack {
            Grid {
                // One cell down the whole left side, beside two that stay in
                // a row each.
                GridCell(text: "Column 0, Rows 0 and 1", color: "#E53935")
                    .gridRowSpan(2)

                GridCell(text: "Column 1, Row 0", color: "#1E88E5")
                    .gridColumn(1)

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
            SwitchRow("Second column twice as wide", $wideSecondColumn)
                .horizontalOptions(.center)

            Label("Where a view sits is written on the VIEW, as in XAML: Grid.Row=\"1\" "
                + "is .gridRow(1). Those modifiers are on View, because any view can be "
                + "a grid child.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("A span counts from the view's OWN cell: .gridRowSpan(2) on the red one "
                + "covers rows 0 and 1 and the spacing between them, and .gridColumnSpan(2) "
                + "does the same across. A cell nothing was placed in is simply empty.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("The definitions travel in MAUI's own syntax - \"70,Auto\" and \"*,2*\" - "
                + "and go straight to MAUI's converter.")
                .fontSize(12)
                .textColor(Palette.subtle)

            SectionTitle("TWO VIEWS IN ONE CELL")

            // Nothing stops two children claiming the same cell - they simply
            // overlap, and `zIndex` is what decides which is drawn on top.
            Grid {
                BoxView(Color.fromArgb("#E53935"))
                    .widthRequest(150)
                    .heightRequest(70)
                    .horizontalOptions(.start)
                    .zIndex(redInFront ? 1 : 0)

                BoxView(Color.fromArgb("#1E88E5"))
                    .widthRequest(150)
                    .heightRequest(70)
                    .horizontalOptions(.end)
                    .zIndex(redInFront ? 0 : 1)
            }
            .heightRequest(70)
            .maximumWidthRequest(240)
            .horizontalOptions(.center)

            SwitchRow("Red in front", $redInFront)
                .horizontalOptions(.center)
        }
        .spacing(12)
    }

    var notes: Element? {
        Label("Both boxes are in the same cell and overlap in the middle. Neither "
            + "moves when the switch is flipped - only `zIndex` changes, and the "
            + "higher number is drawn nearer the front. Left alone, children are "
            + "drawn in the order they are written, so the last one wins.")
            .fontSize(12)
            .textColor(Palette.subtle)
    }
}

/// One coloured cell, composed rather than built inline - and placed with
/// `.gridRow`, `.gridColumn` and the spans like any other view.
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
