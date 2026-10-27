import StateUI

/// Rows and columns with each child's place written on the child.
struct GridSample: SampleContent {
    static let id = "grid"
    static let title = "Grid"
    static let summary = "Rows and columns, with each child's place written on the child."

    var examples: [Example] {
        [Example(GridPlacement()), Example(ButtonRow())]
    }
}

/// Four cells - one down two rows, one across both columns - and a column
/// whose width a switch changes.
private struct GridPlacement: ExampleContent {
    // listing: GridPlacement
    @State private var wideSecondColumn = true

    var body: some View {
        VStack {
            // `wideSecondColumn` is read here, so flipping its switch builds
            // this closure - and the cells cross to their new places.
            DebugInfoLabel()

            Grid {
                // One cell down the whole left side, beside two that stay in
                // a row each.
                GridCell(text: "Column 0, Rows 0 and 1", color: Color(hex: 0xE53935))
                    .gridRowSpan(2)

                GridCell(text: "Column 1, Row 0", color: Color(hex: 0x1E88E5))
                    .gridColumn(1)

                GridCell(text: "Column 1, Row 1", color: Color(hex: 0x8E24AA))
                    .gridRow(1)
                    .gridColumn(1)

                GridCell(text: "Row 2, spanning both columns", color: Color(hex: 0xF4511E))
                    .gridRow(2)
                    .gridColumnSpan(2)
            }
            .rows(.fixed(64, count: 2), .auto)
            .columns(.fill, .proportional(wideSecondColumn ? 2 : 1))
            .rowSpacing(10)
            .columnSpacing(10)

            // Changing a definition patches the grid in place: the cells keep
            // their controls and only the column widths move.
            SwitchRow("Second column twice as wide", $wideSecondColumn)
                .horizontalAlignment(.center)
        }
        .spacing(12)
    }
    // listing: end

    var notes: (any View)? {
        VStack {
            Text("Where a view sits is written on the view - `.gridRow(1)`, "
                + "`.gridColumn(1)` - and those modifiers are on every view, because any "
                + "view can be a grid child.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("A span counts from the view's own cell: `.gridRowSpan(2)` on the red "
                + "cell covers rows 0 and 1 and the spacing between them, and "
                + "`.gridColumnSpan(2)` does the same across. A cell nothing is placed in "
                + "stays empty.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("A row or column is `.fixed(64)`, `.auto`, `.fill` or `.proportional(2)`; "
                + "`count` repeats it - `.fixed(64, count: 2)` is two rows 64 points tall.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(8)
    }
}

// listing: GridPlacement
/// One colored cell, composed rather than built inline - and placed with
/// `.gridRow`, `.gridColumn` and the spans like any other view.
private struct GridCell: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .fontSize(12)
            .textColor(.white)
            .background(color)
            .padding(8)
            .horizontalTextAlignment(.center)
            .verticalTextAlignment(.center)
    }
}
// listing: end

/// Two buttons sharing a row alike, and the first across both columns when
/// the second is hidden.
private struct ButtonRow: ExampleContent {
    // listing: ButtonRow
    @State private var second = true

    var body: some View {
        VStack {
            // Two columns of one share each. Alone, the first button spans
            // both and asks its width of them, so its row stays a button tall.
            Grid {
                Button("Details")
                    .gridColumnSpan(second ? 1 : 2)

                if second {
                    Button("Undo")
                        .gridColumn(1)
                }
            }
            .columns(.fill, .fill)
            .columnSpacing(10)

            SwitchRow("Second button", $second)
                .horizontalAlignment(.center)
        }
        .spacing(12)
    }
    // listing: end

    var notes: (any View)? {
        Text("Turn the second button off: the first spans both columns at a button's height.")
            .fontSize(12)
            .textColor(Palette.subtle)
    }
}
