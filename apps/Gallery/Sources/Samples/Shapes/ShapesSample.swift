import StateUI

/// Six outlines, filled and stroked - with dashes, joins and a fill rule.
struct ShapesSample: SampleContent, ExampleContent {
    // listing: ShapesSample
    @State private var rule = FillRule.evenOdd
    // listing: end

    static let id = "shapes"
    static let title = "Shapes"
    static let summary = "Six outlines sharing one shape vocabulary, drawn with each platform's own paths."

    // listing: ShapesSample
    /// A pentagram: five points, each joined to the one two along, so the
    /// outline crosses itself - which is the whole point of a fill rule.
    private static let star = [
        Point(28, 0), Point(44.5, 50.6), Point(1.4, 19.3),
        Point(54.6, 19.3), Point(11.5, 50.6),
    ]

    var body: some View {
        VStack {
            // The fill rule is read here, so switching it builds this closure.
            DebugInfoLabel()

            SectionTitle("Filled")

            HStack {
                Rectangle()
                    .fill(Palette.accent)
                    .width(56)
                    .height(56)

                Rectangle()
                    .fill(Palette.accent)
                    .cornerRadius(14)
                    .width(56)
                    .height(56)

                Rectangle()
                    .fill(Palette.accent)
                    .cornerRadius(topLeft: 22, topRight: 4, bottomLeft: 4, bottomRight: 22)
                    .width(56)
                    .height(56)

                Ellipse()
                    .fill(Palette.accent)
                    .width(56)
                    .height(56)
            }
            .spacing(12)
            .horizontalAlignment(.center)

            SectionTitle("Stroked")

            HStack {
                Line()
                    .x1(0).y1(0)
                    .x2(56).y2(56)
                    .stroke(Palette.accent)
                    .lineWidth(4)
                    .lineCap(.round)
                    .width(56)
                    .height(56)

                Line()
                    .x1(0).y1(28)
                    .x2(56).y2(28)
                    .stroke(Palette.accent)
                    .lineWidth(4)
                    .dash([3, 2])
                    .width(56)
                    .height(56)

                // The one shape that is whatever you can write down: SVG path
                // syntax, normalized by StateUI for every native host.
                Path("M 28,0 L 56,56 L 0,56 Z")
                    .fill(Palette.accent)
                    .width(56)
                    .height(56)

                // A transform on the GEOMETRY - the same ViewTransform
                // every view takes, drawn whole: a lean draws here, and the
                // stroke follows the shape it makes. On any shape, not only
                // a Path.
                Path("M 28,0 L 56,56 L 0,56 Z")
                    .fill(Palette.accent)
                    .geometryTransform(.skew(20, 0))
                    .width(56)
                    .height(56)

                Rectangle()
                    .fill(Palette.accent)
                    .cornerRadius(14)
                    .geometryTransform(.skew(20, 0))
                    .width(56)
                    .height(56)

                Polyline([Point(0, 44), Point(14, 12), Point(30, 34), Point(56, 4)])
                    .stroke(Palette.accent)
                    .lineWidth(4)
                    .lineJoin(.round)
                    .width(56)
                    .height(56)
            }
            .spacing(12)
            .horizontalAlignment(.center)

            SectionTitle("Where the dashes start")

            // The same dashes twice, half a pattern apart: the offset, like
            // the pattern itself, is counted in stroke widths.
            VStack {
                Line()
                    .x1(0).y1(4)
                    .x2(200).y2(4)
                    .stroke(Palette.accent)
                    .lineWidth(4)
                    .dash([3, 2])
                    .dashPhase(0)
                    .width(200)
                    .height(8)

                Line()
                    .x1(0).y1(4)
                    .x2(200).y2(4)
                    .stroke(Palette.accent)
                    .lineWidth(4)
                    .dash([3, 2])
                    .dashPhase(2.5)
                    .width(200)
                    .height(8)
            }
            .spacing(10)
            .horizontalAlignment(.center)

            SectionTitle("How far a sharp corner reaches")

            // The same sharp corner twice. A miter join carries the two outer
            // edges on until they cross, and the limit is how long that join
            // may be, in stroke widths; past it the point is cut flat.
            HStack {
                Polyline([Point(10, 4), Point(28, 48), Point(46, 4)])
                    .stroke(Palette.accent)
                    .lineWidth(8)
                    .lineJoin(.miter)
                    .miterLimit(10)
                    .width(56)
                    .height(72)

                Polyline([Point(10, 4), Point(28, 48), Point(46, 4)])
                    .stroke(Palette.accent)
                    .lineWidth(8)
                    .lineJoin(.miter)
                    .miterLimit(1)
                    .width(56)
                    .height(72)
            }
            .spacing(12)
            .horizontalAlignment(.center)

            SectionTitle("An outline that crosses itself")

            Polygon(Self.star)
                .fill(Palette.accent)
                .fillRule(rule)
                .width(56)
                .height(56)
                .horizontalAlignment(.center)

            Button("fillRule: .\(rule)")
                .horizontalAlignment(.center)
                .onClicked { rule = rule == .evenOdd ? .nonzero : .evenOdd }
        }
        .spacing(12)
    }
    // listing: end

    var notes: (any View)? {
        VStack {
            Text("Fill, stroke and everything about the stroke form one `Shape` protocol, "
                + "shared by all six outlines and every native host. A shape with no "
                + "stroke draws no outline and one with no fill has no inside - a "
                + "`Line` has only an outline, as there is nothing to fill. A `Rectangle` "
                + "rounds its corners with `cornerRadius`: one number for all four, or "
                + "each corner by name.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("A `Path` is whatever you can write down: `M` moves the pen, `L` draws a "
                + "line to a point, `Z` closes the figure back to where it started - the "
                + "same SVG path vocabulary on every StateUI host. A `Polygon` closes its "
                + "figure for you and a `Polyline` leaves it open.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("Dashes and their offset are counted in stroke widths: `[3, 2]` at "
                + "width 4 repeats every 20 points, so the lower line's offset of 2.5 "
                + "shifts it half a pattern and its dashes stand under the upper line's gaps. "
                + "A miter join carries the two outer edges on until they cross, and the "
                + "miter limit is how long that join may be, in the same units. The Vs' "
                + "corner asks for about 2.6: the left V is allowed 10 and keeps its point, "
                + "the right one is allowed 1 and is cut off flat - a bevel.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("The star is five points, each joined to the one two along, so its outline "
                + "crosses itself and the middle is enclosed twice. A `fillRule` only says "
                + "anything there: `.evenOdd` counts that middle as outside and empties it, "
                + "`.nonzero` counts it as inside and fills it. Everywhere else the two "
                + "rules agree.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(8)
    }
}
