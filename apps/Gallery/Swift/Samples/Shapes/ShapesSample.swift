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

                // A transform on the GEOMETRY, which is not what .rotation
                // does: a skew is possible here and nowhere else.
                Path("M 28,0 L 56,56 L 0,56 Z")
                    .fill(Palette.accent)
                    .renderTransform(.skew(x: 20, y: 0))

                Polyline([Point(0, 44), Point(14, 12), Point(30, 34), Point(56, 4)])
                    .stroke(Palette.accent)
                    .strokeThickness(4)
                    .strokeLineJoin(.round)
                    .widthRequest(56)
                    .heightRequest(56)
            }

            // The same dashes twice, half a pattern apart: the offset, like
            // the pattern itself, is counted in stroke thicknesses.
            VStack {
                Line()
                    .x1(0).y1(4)
                    .x2(200).y2(4)
                    .stroke(Palette.accent)
                    .strokeThickness(4)
                    .strokeDashArray([3, 2])
                    .strokeDashOffset(0)
                    .widthRequest(200)
                    .heightRequest(8)

                Line()
                    .x1(0).y1(4)
                    .x2(200).y2(4)
                    .stroke(Palette.accent)
                    .strokeThickness(4)
                    .strokeDashArray([3, 2])
                    .strokeDashOffset(2.5)
                    .widthRequest(200)
                    .heightRequest(8)
            }

            // The same sharp corner twice. A miter join carries the two outer
            // edges on until they cross, and the limit is how long that join
            // may be, in stroke thicknesses; past it the point is cut flat.
            HStack {
                Polyline([Point(10, 4), Point(28, 48), Point(46, 4)])
                    .stroke(Palette.accent)
                    .strokeThickness(8)
                    .strokeLineJoin(.miter)
                    .strokeMiterLimit(10)
                    .widthRequest(56)
                    .heightRequest(72)

                Polyline([Point(10, 4), Point(28, 48), Point(46, 4)])
                    .stroke(Palette.accent)
                    .strokeThickness(8)
                    .strokeLineJoin(.miter)
                    .strokeMiterLimit(1)
                    .widthRequest(56)
                    .heightRequest(72)
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

                // A transform on the GEOMETRY, which is not what .rotation
                // does: a skew is possible here and nowhere else.
                Path("M 28,0 L 56,56 L 0,56 Z")
                    .fill(Palette.accent)
                    .renderTransform(.skew(x: 20, y: 0))
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

            SectionTitle("WHERE THE DASHES START")

            VStack {
                Line()
                    .x1(0).y1(4)
                    .x2(200).y2(4)
                    .stroke(Palette.accent)
                    .strokeThickness(4)
                    .strokeDashArray([3, 2])
                    .strokeDashOffset(0)
                    .widthRequest(200)
                    .heightRequest(8)

                Line()
                    .x1(0).y1(4)
                    .x2(200).y2(4)
                    .stroke(Palette.accent)
                    .strokeThickness(4)
                    .strokeDashArray([3, 2])
                    .strokeDashOffset(2.5)
                    .widthRequest(200)
                    .heightRequest(8)
            }
            .spacing(10)
            .horizontalOptions(.center)

            Label("The same dashes on both lines. The offset is counted in stroke "
                + "thicknesses, as the pattern is: [3, 2] at thickness 4 repeats every 20 "
                + "points, so the lower line's offset of 2.5 starts it half a pattern in - "
                + "in the middle of a gap where the upper one starts with a dash.")
                .fontSize(12)
                .textColor(Palette.subtle)

            SectionTitle("HOW FAR A SHARP CORNER REACHES")

            HStack {
                Polyline([Point(10, 4), Point(28, 48), Point(46, 4)])
                    .stroke(Palette.accent)
                    .strokeThickness(8)
                    .strokeLineJoin(.miter)
                    .strokeMiterLimit(10)
                    .widthRequest(56)
                    .heightRequest(72)

                Polyline([Point(10, 4), Point(28, 48), Point(46, 4)])
                    .stroke(Palette.accent)
                    .strokeThickness(8)
                    .strokeLineJoin(.miter)
                    .strokeMiterLimit(1)
                    .widthRequest(56)
                    .heightRequest(72)
            }
            .spacing(12)
            .horizontalOptions(.center)

            Label("Both Vs are the same three points and the same 8-point stroke. A miter "
                + "join carries the two outer edges on until they cross, and the limit is "
                + "how long that join may be, measured in stroke thicknesses. A corner this "
                + "sharp asks for about 2.6: the left V is allowed 10 and keeps its point, "
                + "the right one is allowed 1, so the point is cut off flat - a bevel.")
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
