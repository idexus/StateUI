import StateUI

/// MAUI: Rectangle, RoundRectangle, Ellipse, Line, Path, Polygon, Polyline.
struct ShapesSample: SampleContent {
    @State private var rule = FillRule.evenOdd

    static let id = "shapes"
    static let title = "Shapes"
    static let summary = "The seven outlines MAUI draws, and what every one of them shares."

    static let code = """
        @State private var rule = FillRule.evenOdd

        /// A pentagram: five points, each joined to the one two along, so the
        /// outline crosses itself - which is the whole point of a fill rule.
        private static let star = [
            Point(28, 0), Point(44.5, 50.6), Point(1.4, 19.3),
            Point(54.6, 19.3), Point(11.5, 50.6),
        ]

        VStack {
            HStack {
                Rectangle()
                    .fill(Palette.accent)
                    .widthRequest(56)
                    .heightRequest(56)

                Rectangle()
                    .fill(Palette.accent)
                    .radiusX(14)
                    .radiusY(14)
                    .widthRequest(56)
                    .heightRequest(56)

                RoundRectangle()
                    .fill(Palette.accent)
                    .cornerRadius(topLeft: 22, topRight: 4, bottomLeft: 4, bottomRight: 22)
                    .widthRequest(56)
                    .heightRequest(56)

                Ellipse()
                    .fill(Palette.accent)
                    .widthRequest(56)
                    .heightRequest(56)
            }

            HStack {
                Line()
                    .x1(0).y1(0)
                    .x2(56).y2(56)
                    .stroke(Palette.accent)
                    .strokeThickness(4)
                    .strokeLineCap(.round)
                    .widthRequest(56)
                    .heightRequest(56)

                Line()
                    .x1(0).y1(28)
                    .x2(56).y2(28)
                    .stroke(Palette.accent)
                    .strokeThickness(4)
                    .strokeDashArray([3, 2])
                    .widthRequest(56)
                    .heightRequest(56)

                // The one shape that is whatever you can write down: SVG path
                // syntax, straight into MAUI's own converter.
                Path("M 28,0 L 56,56 L 0,56 Z")
                    .fill(Palette.accent)
                    .widthRequest(56)
                    .heightRequest(56)

                Polyline([Point(0, 44), Point(14, 12), Point(30, 34), Point(56, 4)])
                    .stroke(Palette.accent)
                    .strokeThickness(4)
                    .strokeLineJoin(.round)
                    .widthRequest(56)
                    .heightRequest(56)
            }

            Polygon(Self.star)
                .fill(Palette.accent)
                .fillRule(rule)
                .widthRequest(56)
                .heightRequest(56)

            Button("fillRule: .\\(rule)")
                .onClicked { rule = rule == .evenOdd ? .nonzero : .evenOdd }
        }
        """

    /// A pentagram: five points, each joined to the one two along, so the
    /// outline crosses itself - which is the whole point of a fill rule.
    private static let star = [
        Point(28, 0), Point(44.5, 50.6), Point(1.4, 19.3),
        Point(54.6, 19.3), Point(11.5, 50.6),
    ]

    var content: Element {
        VStack {
            SectionTitle("FILLED")

            HStack {
                Rectangle()
                    .fill(Palette.accent)
                    .widthRequest(56)
                    .heightRequest(56)

                Rectangle()
                    .fill(Palette.accent)
                    .radiusX(14)
                    .radiusY(14)
                    .widthRequest(56)
                    .heightRequest(56)

                RoundRectangle()
                    .fill(Palette.accent)
                    .cornerRadius(topLeft: 22, topRight: 4, bottomLeft: 4, bottomRight: 22)
                    .widthRequest(56)
                    .heightRequest(56)

                Ellipse()
                    .fill(Palette.accent)
                    .widthRequest(56)
                    .heightRequest(56)
            }
            .spacing(12)
            .horizontalOptions(.center)

            Label("A Rectangle rounds its corners with radiusX and radiusY, the same on all "
                + "four. A RoundRectangle is the one that names them separately.")
                .fontSize(12)
                .textColor(Palette.subtle)

            SectionTitle("STROKED")

            HStack {
                Line()
                    .x1(0).y1(0)
                    .x2(56).y2(56)
                    .stroke(Palette.accent)
                    .strokeThickness(4)
                    .strokeLineCap(.round)
                    .widthRequest(56)
                    .heightRequest(56)

                Line()
                    .x1(0).y1(28)
                    .x2(56).y2(28)
                    .stroke(Palette.accent)
                    .strokeThickness(4)
                    .strokeDashArray([3, 2])
                    .widthRequest(56)
                    .heightRequest(56)

                Path("M 28,0 L 56,56 L 0,56 Z")
                    .fill(Palette.accent)
                    .widthRequest(56)
                    .heightRequest(56)

                Polyline([Point(0, 44), Point(14, 12), Point(30, 34), Point(56, 4)])
                    .stroke(Palette.accent)
                    .strokeThickness(4)
                    .strokeLineJoin(.round)
                    .widthRequest(56)
                    .heightRequest(56)
            }
            .spacing(12)
            .horizontalOptions(.center)

            Label("A shape with no stroke thickness draws no outline, and one with no fill "
                + "has no inside. A Line has only the first: there is nothing to fill.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("A Path is whatever you can write down. The data travels as the string "
                + "XAML writes - M moves, L draws a line, Z closes - into MAUI's own "
                + "converter, rather than being re-invented on this side.")
                .fontSize(12)
                .textColor(Palette.subtle)

            SectionTitle("AN OUTLINE THAT CROSSES ITSELF")

            Polygon(Self.star)
                .fill(Palette.accent)
                .fillRule(rule)
                .widthRequest(56)
                .heightRequest(56)
                .horizontalOptions(.center)

            Button("fillRule: .\(rule)")
                .fontSize(13)
                .padding(16, 6)
                .horizontalOptions(.center)
                .onClicked { rule = rule == .evenOdd ? .nonzero : .evenOdd }

            Label("A Polygon closes the figure for you; a Polyline leaves it open. Where the "
                + "outline crosses itself the fill rule decides what is inside - .evenOdd "
                + "leaves the middle of the star hollow, .nonzero fills it.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("Fill, stroke and everything about the stroke are MAUI's Shape properties, "
                + "declared once and inherited by all seven - so they are one protocol here "
                + "too, and every shape has the lot.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(12)
    }
}
