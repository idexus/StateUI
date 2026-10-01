// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// Everything a drawing can tell the canvas to do.
///
///     Canvas {
///         Draw.fillColor(.cornflowerBlue)
///         Draw.fillRoundedRectangle(x: 0, y: 0, width: 120, height: 40, cornerRadius: 8)
///
///         Draw.textColor(.white)
///         Draw.fontSize(14)
///         Draw.drawText(
///             "Hello",
///             x: 0, y: 0, width: 120, height: 40,
///             horizontalAlignment: .center, verticalAlignment: .center)
///     }
///
/// The instructions run in the order they are written, and a setting holds
/// until the next of its kind: a `fillColor` paints every `fill…` after it
/// until another `fillColor` says otherwise.
public enum Draw {
    // MARK: - What the canvas draws with

    /// The colour the `fill…` instructions paint with.
    public static func fillColor(_ value: Color) -> DrawCommand {
        DrawCommand(.fillColor, [value.propValue])
    }

    /// The colour the `draw…` instructions outline with.
    public static func strokeColor(_ value: Color) -> DrawCommand {
        DrawCommand(.strokeColor, [value.propValue])
    }

    /// The colour `drawText` writes in.
    public static func textColor(_ value: Color) -> DrawCommand {
        DrawCommand(.textColor, [value.propValue])
    }

    /// How wide that outline is, in device units.
    public static func strokeWidth(_ value: Double) -> DrawCommand {
        DrawCommand(.strokeWidth, [.number(value)])
    }

    /// How big it writes.
    public static func fontSize(_ value: Double) -> DrawCommand {
        DrawCommand(.fontSize, [.number(value)])
    }

    /// How opaque everything after this is, from 0 to 1.
    public static func alpha(_ value: Double) -> DrawCommand {
        DrawCommand(.alpha, [.number(value)])
    }

    // MARK: - Outlines

    /// A straight line.
    ///
    /// - Parameters:
    ///   - x1: where it starts, across.
    ///   - y1: where it starts, down.
    ///   - x2: where it ends, across.
    ///   - y2: where it ends, down.
    public static func drawLine(x1: Double, y1: Double, x2: Double, y2: Double) -> DrawCommand {
        DrawCommand(.drawLine, [.number(x1), .number(y1), .number(x2), .number(y2)])
    }

    /// The outline of a rectangle.
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

    /// Part of the outline of an oval.
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
    /// `Path` takes.
    ///
    ///     Draw.drawPath("M 0,20 L 20,0 L 40,20 Z")
    ///
    /// The path's own numbers are canvas coordinates, so a shape is moved with
    /// `translate` rather than by rewriting them.
    public static func drawPath(_ data: String) -> DrawCommand {
        DrawCommand(.drawPath, [.string(data)])
    }

    // MARK: - Solid shapes

    /// A filled rectangle.
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

    /// A filled oval.
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

    /// A filled shape written in SVG path syntax.
    public static func fillPath(_ data: String) -> DrawCommand {
        DrawCommand(.fillPath, [.string(data)])
    }

    // MARK: - Text

    /// A piece of text, inside a box.
    ///
    ///     Draw.drawText("42", x: 0, y: 100, width: 32, height: 16,
    ///                     horizontalAlignment: .center)
    ///
    /// Text goes in a box rather than at a point: the box is what the two
    /// alignments place it in, and what clips it.
    ///
    /// - Parameters:
    ///   - text: what to write.
    ///   - x: the left edge of the box.
    ///   - y: its top edge - not the baseline.
    ///   - width: how wide the box is. Text that does not fit is clipped.
    ///   - height: how tall.
    ///   - horizontalAlignment: where the text sits across the box - `.start`
    ///     against its left edge, `.end` against its right: a canvas draws in
    ///     its own coordinates, not in a reading direction.
    ///   - verticalAlignment: and down it - `.start` at the top, `.end` at the
    ///     bottom.
    public static func drawText(
        _ text: String,
        x: Double,
        y: Double,
        width: Double,
        height: Double,
        horizontalAlignment: TextAlignment = .start,
        verticalAlignment: TextAlignment = .start
    ) -> DrawCommand {
        DrawCommand(.drawText, [
            .number(x), .number(y), .number(width), .number(height),
            .enumeration(horizontalAlignment.rawValue), .enumeration(verticalAlignment.rawValue),
            .string(text),
        ])
    }

    // MARK: - Where the canvas draws

    /// Moves everything drawn after it.
    ///
    /// - Parameters:
    ///   - dx: how far across.
    ///   - dy: how far down.
    public static func translate(dx: Double, dy: Double) -> DrawCommand {
        DrawCommand(.translate, [.number(dx), .number(dy)])
    }

    /// Turns everything drawn after it, in degrees clockwise about the origin.
    public static func rotate(_ degrees: Double) -> DrawCommand {
        DrawCommand(.rotate, [.number(degrees)])
    }

    /// Resizes everything drawn after it.
    ///
    /// - Parameters:
    ///   - sx: how much across, 1 being unchanged.
    ///   - sy: how much down.
    public static func scale(sx: Double, sy: Double) -> DrawCommand {
        DrawCommand(.scale, [.number(sx), .number(sy)])
    }

    /// Remembers the colours, sizes and transforms in force, for a later
    /// `restoreState` to put back.
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
    public static func restoreState() -> DrawCommand {
        DrawCommand(.restoreState)
    }
}
