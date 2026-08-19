// What a GraphicsView draws, as a list of instructions.
//
// MAUI's GraphicsView takes an IDrawable - an OBJECT with a Draw method, which
// is the one thing this boundary cannot carry. So a drawing travels as what the
// method would have called: one record per canvas operation, in order, and
// `SwiftDrawable` on the other side replays them against the real ICanvas.
//
// A record is a list of typed VALUES - the ICanvas member first, as the number
// both sides spell, then that member's arguments as the things they ARE: a
// number as a number, a flag as a bool, a colour as its four bytes, an
// alignment as its member's number, and text only where an author wrote some.
// The drawing is the list of those records, so it crosses as one `.values`
// holding one `.values` per instruction:
//
//     Draw.fillColor(.cornflowerBlue)
//     Draw.fillRoundedRectangle(x: 0, y: 0, width: 120, height: 40, cornerRadius: 8)
//
//     [[0, #FF6495ED], [13, 0, 0, 120, 40, 8]]
//
// THE NUMBERS ARE THE CONTRACT - see `DrawCommand.Kind`.
//
// The theme is resolved here, as it is everywhere else: a colour written
// `Color(light:dark:)` picks its half as the record is made, and the view that
// wrote it is rebuilt when the system flips - see Types/Color.swift.

/// One instruction for the canvas. Written with `Draw`, never by hand.
public struct DrawCommand: Equatable, Sendable {
    /// Which member of ICanvas an instruction calls, as the number it travels
    /// as - a closed vocabulary, so it crosses as a number and never a
    /// spelling.
    ///
    /// These numbers ARE the contract: `SwiftDrawable` switches on the same
    /// ones, member for member. Add at the END - a case inserted in the middle
    /// renumbers every case after it, and the drawing then replays the wrong
    /// instructions without a word from either side.
    enum Kind: Int32, Sendable {
        // What the canvas draws with.
        case fillColor = 0
        case strokeColor = 1
        case fontColor = 2
        case strokeSize = 3
        case fontSize = 4
        case alpha = 5

        // Outlines.
        case drawLine = 6
        case drawRectangle = 7
        case drawRoundedRectangle = 8
        case drawEllipse = 9
        case drawArc = 10
        case drawPath = 11

        // Solid shapes.
        case fillRectangle = 12
        case fillRoundedRectangle = 13
        case fillEllipse = 14
        case fillArc = 15
        case fillPath = 16

        // Text.
        case drawString = 17

        // Where the canvas draws.
        case translate = 18
        case rotate = 19
        case scale = 20
        case saveState = 21
        case restoreState = 22
    }

    /// Which canvas call this instruction is.
    let kind: Kind

    /// What to call it with, in the order ICanvas takes the arguments - each
    /// already the value it is, so nothing is formatted here and nothing is
    /// parsed on arrival.
    let arguments: [PropValue]

    init(_ kind: Kind, _ arguments: [PropValue] = []) {
        self.kind = kind
        self.arguments = arguments
    }

    /// The kind, then what that kind is called with - the record described at
    /// the top of the file.
    var propValue: PropValue {
        .values([.enumeration(kind.rawValue)] + arguments)
    }
}

/// Collects the instructions written as consecutive statements into a drawing
/// - what a `GraphicsView`'s closure is built with.
///
/// Unlike `ViewBuilder`, this one has a `buildArray`, so a plain `for` loop
/// inside a drawing compiles: a chart draws a bar per value that way.
@resultBuilder
public enum DrawingBuilder {
    /// A single instruction written as a statement.
    public static func buildExpression(_ expression: DrawCommand) -> [DrawCommand] {
        [expression]
    }

    /// Several, from something that already produced a list.
    public static func buildExpression(_ expression: [DrawCommand]) -> [DrawCommand] {
        expression
    }

    /// The statements of the closure, in the order they are written - which is
    /// the order the canvas draws them in.
    public static func buildBlock(_ components: [DrawCommand]...) -> [DrawCommand] {
        components.flatMap { $0 }
    }

    /// An `if` without an `else`.
    public static func buildOptional(_ component: [DrawCommand]?) -> [DrawCommand] {
        component ?? []
    }

    /// Both branches of an if/else.
    public static func buildEither(first component: [DrawCommand]) -> [DrawCommand] {
        component
    }

    /// The `else` branch.
    public static func buildEither(second component: [DrawCommand]) -> [DrawCommand] {
        component
    }

    /// A `for` loop - which is how a chart draws a bar per value.
    public static func buildArray(_ components: [[DrawCommand]]) -> [DrawCommand] {
        components.flatMap { $0 }
    }
}

/// Where a piece of text sits across the box it is drawn in - what
/// `Draw.drawString` takes for `horizontalAlignment:`.
/// MAUI: HorizontalAlignment, in Microsoft.Maui.Graphics.
///
/// Mirrored by `SwiftHorizontalAlignment` and checked case for case like every
/// other vocabulary here. These numbers happen to be MAUI's own as well, which
/// is why `SwiftDrawable` casts one back instead of translating it member by
/// member.
public enum HorizontalAlignment: Int32, Sendable {
    /// Against the left edge of the box. MAUI: HorizontalAlignment.Left.
    case left = 0

    /// In the middle of it. MAUI: HorizontalAlignment.Center.
    case center = 1

    /// Against the right edge. MAUI: HorizontalAlignment.Right.
    case right = 2

    /// Spread out to fill the width - which does nothing to a single word.
    /// MAUI: HorizontalAlignment.Justified.
    case justified = 3
}

/// And where it sits down the box - `Draw.drawString`'s `verticalAlignment:`.
/// MAUI: VerticalAlignment, in Microsoft.Maui.Graphics.
///
/// Mirrored by `SwiftVerticalAlignment`, and lined up with MAUI's own numbers
/// exactly as `HorizontalAlignment` is.
public enum VerticalAlignment: Int32, Sendable {
    /// Against the top of the box. MAUI: VerticalAlignment.Top.
    case top = 0

    /// In the middle of it. MAUI: VerticalAlignment.Center.
    case center = 1

    /// Against the bottom. MAUI: VerticalAlignment.Bottom.
    case bottom = 2
}

/// Everything a drawing can tell the canvas to do. MAUI: ICanvas.
///
///     GraphicsView {
///         Draw.fillColor(.cornflowerBlue)
///         Draw.fillRoundedRectangle(x: 0, y: 0, width: 120, height: 40, cornerRadius: 8)
///
///         Draw.fontColor(.white)
///         Draw.fontSize(14)
///         Draw.drawString(
///             "Hello",
///             x: 0, y: 0, width: 120, height: 40,
///             horizontalAlignment: .center, verticalAlignment: .center)
///     }
///
/// The names are ICanvas's, camelCased, and so is the order: a `fillColor` holds
/// until the next one, exactly as it does when the drawing is written in C#.
public enum Draw {
    // MARK: - What the canvas draws with

    /// The colour the `fill…` instructions paint with. MAUI: ICanvas.FillColor.
    public static func fillColor(_ value: Color) -> DrawCommand {
        DrawCommand(.fillColor, [value.propValue])
    }

    /// The colour the `draw…` instructions outline with.
    /// MAUI: ICanvas.StrokeColor.
    public static func strokeColor(_ value: Color) -> DrawCommand {
        DrawCommand(.strokeColor, [value.propValue])
    }

    /// The colour `drawString` writes in. MAUI: ICanvas.FontColor.
    public static func fontColor(_ value: Color) -> DrawCommand {
        DrawCommand(.fontColor, [value.propValue])
    }

    /// How thick that outline is, in device units. MAUI: ICanvas.StrokeSize.
    public static func strokeSize(_ value: Double) -> DrawCommand {
        DrawCommand(.strokeSize, [.number(value)])
    }

    /// How big it writes. MAUI: ICanvas.FontSize.
    public static func fontSize(_ value: Double) -> DrawCommand {
        DrawCommand(.fontSize, [.number(value)])
    }

    /// How opaque everything after this is, from 0 to 1. MAUI: ICanvas.Alpha.
    public static func alpha(_ value: Double) -> DrawCommand {
        DrawCommand(.alpha, [.number(value)])
    }

    // MARK: - Outlines

    /// A straight line. MAUI: ICanvas.DrawLine.
    ///
    /// - Parameters:
    ///   - x1: where it starts, across.
    ///   - y1: where it starts, down.
    ///   - x2: where it ends, across.
    ///   - y2: where it ends, down.
    public static func drawLine(x1: Double, y1: Double, x2: Double, y2: Double) -> DrawCommand {
        DrawCommand(.drawLine, [.number(x1), .number(y1), .number(x2), .number(y2)])
    }

    /// The outline of a rectangle. MAUI: ICanvas.DrawRectangle.
    ///
    /// - Parameters:
    ///   - x: the left edge.
    ///   - y: the top edge.
    ///   - width: how wide.
    ///   - height: how tall.
    public static func drawRectangle(
        x: Double, y: Double, width: Double, height: Double
    ) -> DrawCommand {
        DrawCommand(.drawRectangle, [.number(x), .number(y), .number(width), .number(height)])
    }

    /// The outline of a rectangle with rounded corners.
    /// MAUI: ICanvas.DrawRoundedRectangle.
    ///
    /// - Parameters:
    ///   - x: the left edge.
    ///   - y: the top edge.
    ///   - width: how wide.
    ///   - height: how tall.
    ///   - cornerRadius: how far the corners are rounded.
    public static func drawRoundedRectangle(
        x: Double, y: Double, width: Double, height: Double, cornerRadius: Double
    ) -> DrawCommand {
        DrawCommand(.drawRoundedRectangle, [
            .number(x), .number(y), .number(width), .number(height), .number(cornerRadius),
        ])
    }

    /// The outline of an oval filling the rectangle given.
    /// MAUI: ICanvas.DrawEllipse.
    ///
    /// - Parameters:
    ///   - x: the left edge of the rectangle it fits in.
    ///   - y: the top edge.
    ///   - width: how wide.
    ///   - height: how tall.
    public static func drawEllipse(
        x: Double, y: Double, width: Double, height: Double
    ) -> DrawCommand {
        DrawCommand(.drawEllipse, [.number(x), .number(y), .number(width), .number(height)])
    }

    /// Part of the outline of an oval. MAUI: ICanvas.DrawArc.
    ///
    /// - Parameters:
    ///   - x: the left edge of the rectangle the oval fits in.
    ///   - y: the top edge.
    ///   - width: how wide.
    ///   - height: how tall.
    ///   - startAngle: where the arc begins, in degrees, 0 being to the right.
    ///   - endAngle: where it ends.
    ///   - clockwise: which way round it goes between the two.
    ///   - closed: whether the two ends are joined back up.
    public static func drawArc(
        x: Double, y: Double, width: Double, height: Double,
        startAngle: Double, endAngle: Double, clockwise: Bool, closed: Bool
    ) -> DrawCommand {
        DrawCommand(.drawArc, [
            .number(x), .number(y), .number(width), .number(height),
            .number(startAngle), .number(endAngle), .bool(clockwise), .bool(closed),
        ])
    }

    /// The outline of a shape written in SVG path syntax - the same string a
    /// `Path` takes. MAUI: ICanvas.DrawPath.
    ///
    ///     Draw.drawPath("M 0,20 L 20,0 L 40,20 Z")
    ///
    /// The path's own numbers are canvas coordinates, so a shape is moved with
    /// `translate` rather than by rewriting them.
    public static func drawPath(_ data: String) -> DrawCommand {
        DrawCommand(.drawPath, [.string(data)])
    }

    // MARK: - Solid shapes

    /// A filled rectangle. MAUI: ICanvas.FillRectangle.
    ///
    /// - Parameters:
    ///   - x: the left edge.
    ///   - y: the top edge.
    ///   - width: how wide.
    ///   - height: how tall.
    public static func fillRectangle(
        x: Double, y: Double, width: Double, height: Double
    ) -> DrawCommand {
        DrawCommand(.fillRectangle, [.number(x), .number(y), .number(width), .number(height)])
    }

    /// A filled rectangle with rounded corners.
    /// MAUI: ICanvas.FillRoundedRectangle.
    ///
    /// - Parameters:
    ///   - x: the left edge.
    ///   - y: the top edge.
    ///   - width: how wide.
    ///   - height: how tall.
    ///   - cornerRadius: how far the corners are rounded.
    public static func fillRoundedRectangle(
        x: Double, y: Double, width: Double, height: Double, cornerRadius: Double
    ) -> DrawCommand {
        DrawCommand(.fillRoundedRectangle, [
            .number(x), .number(y), .number(width), .number(height), .number(cornerRadius),
        ])
    }

    /// A filled oval. MAUI: ICanvas.FillEllipse.
    ///
    /// - Parameters:
    ///   - x: the left edge of the rectangle it fits in.
    ///   - y: the top edge.
    ///   - width: how wide.
    ///   - height: how tall.
    public static func fillEllipse(
        x: Double, y: Double, width: Double, height: Double
    ) -> DrawCommand {
        DrawCommand(.fillEllipse, [.number(x), .number(y), .number(width), .number(height)])
    }

    /// A filled wedge of an oval - what a pie chart is made of.
    /// MAUI: ICanvas.FillArc.
    ///
    /// - Parameters:
    ///   - x: the left edge of the rectangle the oval fits in.
    ///   - y: the top edge.
    ///   - width: how wide.
    ///   - height: how tall.
    ///   - startAngle: where the wedge begins, in degrees, 0 being to the right.
    ///   - endAngle: where it ends.
    ///   - clockwise: which way round it goes between the two.
    public static func fillArc(
        x: Double, y: Double, width: Double, height: Double,
        startAngle: Double, endAngle: Double, clockwise: Bool
    ) -> DrawCommand {
        DrawCommand(.fillArc, [
            .number(x), .number(y), .number(width), .number(height),
            .number(startAngle), .number(endAngle), .bool(clockwise),
        ])
    }

    /// A filled shape written in SVG path syntax. MAUI: ICanvas.FillPath.
    public static func fillPath(_ data: String) -> DrawCommand {
        DrawCommand(.fillPath, [.string(data)])
    }

    // MARK: - Text

    /// A piece of text, inside a box. MAUI: ICanvas.DrawString.
    ///
    ///     Draw.drawString("42", x: 0, y: 100, width: 32, height: 16,
    ///                     horizontalAlignment: .center)
    ///
    /// Text goes in a BOX rather than at a point, which is MAUI's fuller
    /// overload and the one that works: the shorter `DrawString(value, x, y,
    /// alignment)` draws nothing at all on Mac Catalyst - measured, with the
    /// bars of a chart appearing and their captions not.
    ///
    /// - Parameters:
    ///   - text: what to write.
    ///   - x: the left edge of the box.
    ///   - y: its top edge - not the baseline.
    ///   - width: how wide the box is. Text that does not fit is clipped.
    ///   - height: how tall.
    ///   - horizontalAlignment: where the text sits across the box.
    ///   - verticalAlignment: and down it.
    public static func drawString(
        _ text: String,
        x: Double,
        y: Double,
        width: Double,
        height: Double,
        horizontalAlignment: HorizontalAlignment = .left,
        verticalAlignment: VerticalAlignment = .top
    ) -> DrawCommand {
        DrawCommand(.drawString, [
            .number(x), .number(y), .number(width), .number(height),
            .enumeration(horizontalAlignment.rawValue), .enumeration(verticalAlignment.rawValue),
            .string(text),
        ])
    }

    // MARK: - Where the canvas draws

    /// Moves everything drawn after it. MAUI: ICanvas.Translate.
    ///
    /// - Parameters:
    ///   - dx: how far across.
    ///   - dy: how far down.
    public static func translate(dx: Double, dy: Double) -> DrawCommand {
        DrawCommand(.translate, [.number(dx), .number(dy)])
    }

    /// Turns everything drawn after it, in degrees clockwise about the origin.
    /// MAUI: ICanvas.Rotate.
    public static func rotate(_ degrees: Double) -> DrawCommand {
        DrawCommand(.rotate, [.number(degrees)])
    }

    /// Resizes everything drawn after it. MAUI: ICanvas.Scale.
    ///
    /// - Parameters:
    ///   - sx: how much across, 1 being unchanged.
    ///   - sy: how much down.
    public static func scale(sx: Double, sy: Double) -> DrawCommand {
        DrawCommand(.scale, [.number(sx), .number(sy)])
    }

    /// Remembers the colours, sizes and transforms in force, for a later
    /// `restoreState` to put back. MAUI: ICanvas.SaveState.
    ///
    ///     Draw.saveState()
    ///     Draw.translate(dx: 40, dy: 0)
    ///     Draw.rotate(45)
    ///     Draw.fillRectangle(x: 0, y: 0, width: 20, height: 20)
    ///     Draw.restoreState()
    ///
    /// Everything after this line inherits what was in force, so the pair is
    /// what keeps one rotated shape from turning the rest of the drawing.
    public static func saveState() -> DrawCommand {
        DrawCommand(.saveState)
    }

    /// Puts back what the last `saveState` remembered.
    /// MAUI: ICanvas.RestoreState.
    public static func restoreState() -> DrawCommand {
        DrawCommand(.restoreState)
    }
}
