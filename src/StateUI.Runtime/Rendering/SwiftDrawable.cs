// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

using Microsoft.Maui.Graphics;
using StateUI.Runtime.Protocol;

namespace StateUI.Runtime.Rendering;

/// <summary>
/// What a <see cref="GraphicsView"/> draws, replayed from the instructions the
/// Swift side sent.
/// </summary>
/// <remarks>
/// <para>
/// MAUI's GraphicsView takes an <see cref="IDrawable"/> - an object with a Draw
/// method - and an object is the one thing this boundary cannot carry. So the
/// Swift side sends the calls that method would have made, one record per canvas
/// operation, and this replays them in order against the real canvas.
/// </para>
/// <para>
/// A record is a list of typed VALUES: the ICanvas member first, as the number
/// <see cref="Kind"/> and <c>DrawCommand.Kind</c> both spell, then that member's
/// arguments as the things they ARE - a number as a number, a flag as a bool, a
/// colour as its four bytes, an alignment as MAUI's own member number, and text
/// only where an author wrote some. The drawing is the list of those records, so
/// <c>Draw.fillRoundedRectangle(x: 0, y: 0, width: 120, height: 40,
/// cornerRadius: 8)</c> arrives as <c>[13, 0, 0, 120, 40, 8]</c>.
/// </para>
/// <para>
/// A record whose kind is not one of these is SKIPPED, and so is one whose
/// arguments are not the shapes that member takes - the same answer an
/// unrecognized property gets everywhere else here, and for the same reason: a
/// lagging host must not take the page down, and half a drawing is more use than
/// an exception from inside the platform's draw pass.
/// </para>
/// <para>
/// A number must also be FINITE, which is how the rest of the runtime reads one
/// (<c>SwiftNode.GetNumber</c>, <c>SwiftCommand.GetDouble</c>), and a record with
/// a non-finite argument is skipped whole rather than drawn with a 0 put in its
/// place. An infinity says nothing about where to draw, and a substituted 0 would
/// draw the shape at the origin instead.
/// </para>
/// </remarks>
/// <param name="commands">The records, in the order they are drawn in.</param>
internal sealed class SwiftDrawable(SwiftWireValue[] commands) : IDrawable
{
    /// <summary>
    /// Which member of ICanvas a record calls, as the number it travels as.
    /// </summary>
    /// <remarks>
    /// A closed vocabulary, so it crosses as a number both sides of this
    /// repository spell - the way a brush's kind and a window's phase do.
    /// Mirrored by <c>DrawCommand.Kind</c> in Types/Drawing.swift, member for
    /// member: THESE NUMBERS ARE THE CONTRACT. Add at the END - a case inserted
    /// in the middle renumbers every one after it, and the drawing then replays
    /// the wrong instructions without a word from either side.
    /// </remarks>
    internal enum Kind
    {
        /// <summary>MAUI: ICanvas.FillColor.</summary>
        FillColor = 0,

        /// <summary>MAUI: ICanvas.StrokeColor.</summary>
        StrokeColor = 1,

        /// <summary>MAUI: ICanvas.FontColor.</summary>
        FontColor = 2,

        /// <summary>MAUI: ICanvas.StrokeSize.</summary>
        StrokeSize = 3,

        /// <summary>MAUI: ICanvas.FontSize.</summary>
        FontSize = 4,

        /// <summary>MAUI: ICanvas.Alpha.</summary>
        Alpha = 5,

        /// <summary>MAUI: ICanvas.DrawLine.</summary>
        DrawLine = 6,

        /// <summary>MAUI: ICanvas.DrawRectangle.</summary>
        DrawRectangle = 7,

        /// <summary>MAUI: ICanvas.DrawRoundedRectangle.</summary>
        DrawRoundedRectangle = 8,

        /// <summary>MAUI: ICanvas.DrawEllipse.</summary>
        DrawEllipse = 9,

        /// <summary>MAUI: ICanvas.DrawArc.</summary>
        DrawArc = 10,

        /// <summary>MAUI: ICanvas.DrawPath.</summary>
        DrawPath = 11,

        /// <summary>MAUI: ICanvas.FillRectangle.</summary>
        FillRectangle = 12,

        /// <summary>MAUI: ICanvas.FillRoundedRectangle.</summary>
        FillRoundedRectangle = 13,

        /// <summary>MAUI: ICanvas.FillEllipse.</summary>
        FillEllipse = 14,

        /// <summary>MAUI: ICanvas.FillArc.</summary>
        FillArc = 15,

        /// <summary>MAUI: ICanvas.FillPath.</summary>
        FillPath = 16,

        /// <summary>MAUI: ICanvas.DrawString.</summary>
        DrawString = 17,

        /// <summary>MAUI: ICanvas.Translate.</summary>
        Translate = 18,

        /// <summary>MAUI: ICanvas.Rotate.</summary>
        Rotate = 19,

        /// <summary>MAUI: ICanvas.Scale.</summary>
        Scale = 20,

        /// <summary>MAUI: ICanvas.SaveState.</summary>
        SaveState = 21,

        /// <summary>MAUI: ICanvas.RestoreState.</summary>
        RestoreState = 22,
    }

    /// <summary>The records this drawable replays, in the order they are drawn in.</summary>
    /// <remarks>
    /// Kept exactly as they arrived rather than unpacked into anything: each is
    /// already the typed values its canvas call takes, and a drawing is replayed
    /// from them on every draw pass. It is also what tells one drawing from
    /// another without comparing the objects - an unchanged drawing is not sent
    /// at all, but a fixture applied twice is.
    /// </remarks>
    public SwiftWireValue[] Commands { get; } = commands;

    /// <summary>Replays every instruction against the canvas.</summary>
    /// <param name="canvas">What to draw on.</param>
    /// <param name="dirtyRect">The area being redrawn, which nothing here reads.</param>
    public void Draw(ICanvas canvas, RectF dirtyRect)
    {
        foreach (SwiftWireValue command in Commands)
        {
            // A record is [kind, arguments…], the kind at index 0 - so an
            // argument is at the index it was written at, one-based, exactly as
            // ICanvas takes them.
            if (command is { Tag: SwiftWireValue.TagValues, Values: SwiftWireValue[] record }
                && Enumeration(record, 0) is int kind)
            {
                Run(canvas, (Kind)kind, record);
            }
        }
    }

    private static void Run(ICanvas canvas, Kind kind, SwiftWireValue[] record)
    {
        // Every arm reads its arguments in its guard, so a record missing one -
        // or carrying something of another shape, or a number that is not finite
        // - matches no arm and is skipped whole.
        switch (kind)
        {
            // ---- What the canvas draws with --------------------------------

            case Kind.FillColor when Colour(record, 1) is Color colour:
                canvas.FillColor = colour;
                break;

            case Kind.StrokeColor when Colour(record, 1) is Color colour:
                canvas.StrokeColor = colour;
                break;

            case Kind.FontColor when Colour(record, 1) is Color colour:
                canvas.FontColor = colour;
                break;

            case Kind.StrokeSize when Number(record, 1) is double size:
                canvas.StrokeSize = (float)size;
                break;

            case Kind.FontSize when Number(record, 1) is double size:
                canvas.FontSize = (float)size;
                break;

            case Kind.Alpha when Number(record, 1) is double alpha:
                canvas.Alpha = (float)alpha;
                break;

            // ---- Outlines ---------------------------------------------------

            case Kind.DrawLine when Numbers(record, 4) is [double x1, double y1, double x2, double y2]:
                canvas.DrawLine((float)x1, (float)y1, (float)x2, (float)y2);
                break;

            case Kind.DrawRectangle when Numbers(record, 4) is [double x, double y, double width, double height]:
                canvas.DrawRectangle((float)x, (float)y, (float)width, (float)height);
                break;

            case Kind.DrawRoundedRectangle when Numbers(record, 5) is
                [double x, double y, double width, double height, double cornerRadius]:
                canvas.DrawRoundedRectangle(
                    (float)x, (float)y, (float)width, (float)height, (float)cornerRadius);
                break;

            case Kind.DrawEllipse when Numbers(record, 4) is [double x, double y, double width, double height]:
                canvas.DrawEllipse((float)x, (float)y, (float)width, (float)height);
                break;

            case Kind.DrawArc when Numbers(record, 6) is
                    [double x, double y, double width, double height, double startAngle, double endAngle]
                && Flag(record, 7) is bool clockwise
                && Flag(record, 8) is bool closed:
                canvas.DrawArc(
                    (float)x, (float)y, (float)width, (float)height,
                    (float)startAngle, (float)endAngle, clockwise, closed);
                break;

            case Kind.DrawPath when Text(record, 1) is string data:
                canvas.DrawPath(new PathBuilder().BuildPath(data));
                break;

            // ---- Solid shapes ------------------------------------------------

            case Kind.FillRectangle when Numbers(record, 4) is [double x, double y, double width, double height]:
                canvas.FillRectangle((float)x, (float)y, (float)width, (float)height);
                break;

            case Kind.FillRoundedRectangle when Numbers(record, 5) is
                [double x, double y, double width, double height, double cornerRadius]:
                canvas.FillRoundedRectangle(
                    (float)x, (float)y, (float)width, (float)height, (float)cornerRadius);
                break;

            case Kind.FillEllipse when Numbers(record, 4) is [double x, double y, double width, double height]:
                canvas.FillEllipse((float)x, (float)y, (float)width, (float)height);
                break;

            case Kind.FillArc when Numbers(record, 6) is
                    [double x, double y, double width, double height, double startAngle, double endAngle]
                && Flag(record, 7) is bool clockwise:
                canvas.FillArc(
                    (float)x, (float)y, (float)width, (float)height,
                    (float)startAngle, (float)endAngle, clockwise);
                break;

            case Kind.FillPath when Text(record, 1) is string data:
                canvas.FillPath(new PathBuilder().BuildPath(data), WindingMode.NonZero);
                break;

            // ---- Text ---------------------------------------------------------

            // Text goes in a BOX, which is the overload that works: the shorter
            // DrawString(value, x, y, alignment) draws nothing at all on Mac
            // Catalyst - measured, with a chart's bars appearing and their
            // captions not.
            case Kind.DrawString when Numbers(record, 4) is [double x, double y, double width, double height]
                && Across(record, 5) is HorizontalAlignment across
                && Down(record, 6) is VerticalAlignment down
                && Text(record, 7) is string text:
                canvas.DrawString(
                    text, (float)x, (float)y, (float)width, (float)height, across, down);
                break;

            // ---- Where the canvas draws ----------------------------------------

            case Kind.Translate when Numbers(record, 2) is [double dx, double dy]:
                canvas.Translate((float)dx, (float)dy);
                break;

            case Kind.Rotate when Number(record, 1) is double degrees:
                canvas.Rotate((float)degrees);
                break;

            case Kind.Scale when Numbers(record, 2) is [double sx, double sy]:
                canvas.Scale((float)sx, (float)sy);
                break;

            case Kind.SaveState:
                canvas.SaveState();
                break;

            case Kind.RestoreState:
                canvas.RestoreState();
                break;
        }
    }

    /// <summary>An argument as a colour, or null when it is absent or is something else.</summary>
    /// <remarks>
    /// Four channels, each 0 to 255, sRGB, alpha included - a colour's own tag,
    /// the same one every other colour on this tree rides, read with no parser
    /// at all. The Swift side has already picked the half for the theme in
    /// force, so one of these is one colour and never a pair.
    /// </remarks>
    private static Color? Colour(SwiftWireValue[] record, int index)
    {
        return At(record, index) is { Tag: SwiftWireValue.TagColor } value
            ? new Color(value.Red / 255f, value.Green / 255f, value.Blue / 255f, value.Alpha / 255f)
            : null;
    }

    /// <summary>
    /// An argument as a number, or null when it is absent, is not one, or is not
    /// finite.
    /// </summary>
    /// <remarks>
    /// A double all the way to the canvas call, which narrows to float where MAUI
    /// asks for one - the same rule the tree's properties follow. The finite
    /// check is what makes a NaN or an infinity refuse the record it is in rather
    /// than draw it somewhere nobody asked for.
    /// </remarks>
    private static double? Number(SwiftWireValue[] record, int index)
    {
        return At(record, index) is { Tag: SwiftWireValue.TagNumber } value
            && double.IsFinite(value.Number)
                ? value.Number
                : null;
    }

    /// <summary>
    /// The record's first <paramref name="count"/> arguments as numbers, or null
    /// when any one of them is missing, is not a number, or is not finite.
    /// </summary>
    /// <remarks>
    /// Every canvas call here takes its numbers FIRST, so this reads a prefix -
    /// from index 1, index 0 being the kind - and the list pattern at the call
    /// site names them in MAUI's own order. All or nothing: a record cannot be
    /// half read, because a missing coordinate has no answer that would draw the
    /// right thing.
    /// </remarks>
    private static double[]? Numbers(SwiftWireValue[] record, int count)
    {
        double[] numbers = new double[count];

        for (int at = 0; at < count; at++)
        {
            if (Number(record, at + 1) is not double value)
            {
                return null;
            }

            numbers[at] = value;
        }

        return numbers;
    }

    /// <summary>An argument as true or false, or null when it is absent or neither.</summary>
    private static bool? Flag(SwiftWireValue[] record, int index)
    {
        return At(record, index)?.Tag switch
        {
            SwiftWireValue.TagTrue => true,
            SwiftWireValue.TagFalse => false,
            _ => null,
        };
    }

    /// <summary>An argument as text, or null when it is absent or is something else.</summary>
    /// <remarks>
    /// Text is the one thing here that IS a spelling - what an author wrote, or
    /// the SVG data of a path - so it rides the wire's string tag and nothing
    /// else reads as one.
    /// </remarks>
    private static string? Text(SwiftWireValue[] record, int index)
    {
        return At(record, index) is { Tag: SwiftWireValue.TagString } value ? value.Text : null;
    }

    /// <summary>
    /// A closed vocabulary's member as the number it rides as - a record's kind,
    /// or one of the two alignments - or null when the argument is absent or is
    /// something else.
    /// </summary>
    /// <remarks>
    /// The one place in this file that names the wire's enumeration tag, so that
    /// the whole drawing follows it if it ever moves.
    /// </remarks>
    private static int? Enumeration(SwiftWireValue[] record, int index)
    {
        return At(record, index) is { Tag: SwiftWireValue.TagEnumeration } value ? value.Member : null;
    }

    /// <summary>Where the text sits across its box, or null when it did not arrive.</summary>
    /// <remarks>
    /// The number is MAUI's own - <c>HorizontalAlignment.Left</c> is 0, Center 1,
    /// Right 2, Justified 3 - and the Swift enum is declared with those values,
    /// so a cast is the whole conversion and no spelling crosses.
    /// </remarks>
    private static HorizontalAlignment? Across(SwiftWireValue[] record, int index)
    {
        return Enumeration(record, index) is int member ? (HorizontalAlignment)member : null;
    }

    /// <summary>And down it. MAUI's numbers again: Top 0, Center 1, Bottom 2.</summary>
    private static VerticalAlignment? Down(SwiftWireValue[] record, int index)
    {
        return Enumeration(record, index) is int member ? (VerticalAlignment)member : null;
    }

    /// <summary>The argument at an index, or null when the record is shorter than that.</summary>
    private static SwiftWireValue? At(SwiftWireValue[] record, int index)
    {
        return index < record.Length ? record[index] : null;
    }
}
