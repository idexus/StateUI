import StateUI

/// Rows and columns with each child's place written on the child, and two
/// views sharing one cell.
struct GridSample: SampleContent {
    static let id = "grid"
    static let title = "Grid"
    static let summary = "Rows and columns, with each child's place written on the child."

    var examples: [Example] {
        [Example(GridPlacement()), Example(SharedCell())]
    }
}

/// Four cells - one down two rows, one across both columns - and a column
/// whose width a switch changes.
private struct GridPlacement: ExampleContent {
    @State private var wideSecondColumn = true

    static let code = """
        @State private var wideSecondColumn = true

        VStack {
            // `wideSecondColumn` is read here, so flipping its switch builds
            // this closure - and the cells cross to their new places.
            DebugInfoLabel()

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

            var content: any View {
                Label(text)
                    .textColor(.white)
                    .backgroundColor(Color.fromArgb(color))
                    .padding(8)
            }
        }
        """

    var content: any View {
        VStack {
            DebugInfoLabel()

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
                .horizontalAlignment(.center)
        }
        .spacing(12)
    }

    var notes: Element? {
        VStack {
            Label("Where a view sits is written on the view - `.gridRow(1)`, "
                + "`.gridColumn(1)` - and those modifiers are on every view, because any "
                + "view can be a grid child.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("A span counts from the view's own cell: `.gridRowSpan(2)` on the red "
                + "cell covers rows 0 and 1 and the spacing between them, and "
                + "`.gridColumnSpan(2)` does the same across. A cell nothing is placed in "
                + "stays empty.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("A row or column is a `GridLength`: `.absolute(64)`, `.auto`, `.star` "
                + "and `.star(2)`.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(8)
    }
}

/// Two views in one cell, and which is drawn on top.
private struct SharedCell: ExampleContent {
    @State private var redInFront = false

    static let code = """
        @State private var redInFront = false

        VStack {
            // Nothing stops two children claiming the same cell. They overlap,
            // and zIndex decides which is drawn on top - the higher number is
            // nearer the front. Left alone, the one written LAST wins.
            Grid {
                BoxView(Color.fromArgb("#E53935"))
                    .horizontalAlignment(.start)
                    .zIndex(redInFront ? 1 : 0)

                BoxView(Color.fromArgb("#1E88E5"))
                    .horizontalAlignment(.end)
                    .zIndex(redInFront ? 0 : 1)
            }

            SwitchRow("Red in front", $redInFront)
        }
        """

    var content: any View {
        VStack {
            // Nothing stops two children claiming the same cell - they simply
            // overlap, and `zIndex` is what decides which is drawn on top.
            Grid {
                BoxView(Color.fromArgb("#E53935"))
                    .width(150)
                    .height(70)
                    .horizontalAlignment(.start)
                    .zIndex(redInFront ? 1 : 0)

                BoxView(Color.fromArgb("#1E88E5"))
                    .width(150)
                    .height(70)
                    .horizontalAlignment(.end)
                    .zIndex(redInFront ? 0 : 1)
            }
            .height(70)
            .maximumWidth(240)
            .horizontalAlignment(.center)

            SwitchRow("Red in front", $redInFront)
                .horizontalAlignment(.center)
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

    var content: any View {
        Label(text)
            .fontSize(12)
            .textColor(.white)
            .backgroundColor(Color.fromArgb(color))
            .padding(8)
            .horizontalTextAlignment(.center)
            .verticalTextAlignment(.center)
    }
}
