// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

namespace StateUI.Runtime.Rendering;

using Microsoft.Maui.Controls;

/// <summary>
/// Something a channel can move: where the value is now, and how to put it
/// somewhere else.
/// </summary>
/// <remarks>
/// <para>
/// The engine knows nothing but LANES - one number for an opacity, four for a
/// colour, a thickness or a rectangle - and this is the whole of what turns
/// lanes back into something a platform understands. It is also the channel's
/// IDENTITY: <see cref="Owner"/> and <see cref="Key"/> say which value is
/// moving, so a second setpoint for the same one finds the motion already
/// under way and bends it rather than starting beside it.
/// </para>
/// <para>
/// One instance per moving value is the intended shape, and the engine keeps
/// the one it was first given - so an implementation is free to hold whatever
/// it needs to write quickly.
/// </para>
/// </remarks>
internal interface IMotionTarget
{
    /// <summary>What the value belongs to - normally the control.</summary>
    object Owner { get; }

    /// <summary>Which of the owner's values this is.</summary>
    object Key { get; }

    /// <summary>How many numbers the value is made of.</summary>
    int Lanes { get; }

    /// <summary>Reads where the value is now.</summary>
    /// <param name="into">Filled with the value's lanes.</param>
    /// <returns>Whether there was anything to read.</returns>
    bool Read(double[] into);

    /// <summary>Puts the value there.</summary>
    /// <param name="from">The lanes to write.</param>
    void Write(double[] from);

    /// <summary>The value these lanes stand for, in the platform's own type.</summary>
    /// <remarks>
    /// What a reading of a motion in the air is made of - where a walk has got
    /// to, or where one is going.
    /// </remarks>
    /// <param name="from">The lanes.</param>
    /// <returns>The value.</returns>
    object Compose(double[] from);
}

/// <summary>What shape a value is, as the lanes that carry it.</summary>
internal enum MotionValue : byte
{
    /// <summary>One number.</summary>
    Number = 0,

    /// <summary>Four channels, each from 0 to 1.</summary>
    Colour = 1,

    /// <summary>Four edges - left, top, right, bottom.</summary>
    Edges = 2,

    /// <summary>A rectangle - x, y, width, height.</summary>
    Bounds = 3,

    /// <summary>Four corners - top left, top right, bottom left, bottom right.</summary>
    Corners = 4,

    /// <summary>
    /// One number the platform takes as a WHOLE one - a corner radius MAUI
    /// happens to type as an integer.
    /// </summary>
    /// <remarks>
    /// It travels like any other length and is written rounded, because what
    /// makes a value travel is whether there is a half-way between two of them
    /// on SCREEN, never which C# type the property happens to have. What must
    /// not travel is a place or a count, and those are named on the Swift side
    /// - see <c>Prop.unmoved</c>.
    /// </remarks>
    Whole = 5,

    /// <summary>One number the platform takes as a single-precision one.</summary>
    Single = 6,
}

/// <summary>
/// One property of one control, moved by writing it.
/// </summary>
/// <remarks>
/// The same <see cref="BindableProperty"/> a style setter would write and a
/// plain assignment would snap - which is what makes a property animatable the
/// moment it is styleable, and why the engine needs no table of its own.
/// </remarks>
internal sealed class MotionProperty : IMotionTarget
{
    private readonly BindableObject _target;
    private readonly BindableProperty _property;
    private readonly MotionValue _shape;
    private readonly bool _fraction;

    /// <summary>Names a property of a control as something to move.</summary>
    /// <param name="target">The control.</param>
    /// <param name="property">Which of its properties.</param>
    /// <param name="shape">What the value is made of.</param>
    /// <param name="fraction">
    /// Whether the number is a fraction of one, as an opacity is - the one
    /// place a curve that overshoots has to be held back, since a platform
    /// given 1.04 draws something it was never asked for.
    /// </param>
    internal MotionProperty(
        BindableObject target, BindableProperty property, MotionValue shape, bool fraction = false)
    {
        _target = target;
        _property = property;
        _shape = shape;
        _fraction = fraction;
    }

    /// <inheritdoc/>
    public object Owner => _target;

    /// <inheritdoc/>
    public object Key => _property;

    /// <inheritdoc/>
    public int Lanes => _shape is MotionValue.Number or MotionValue.Whole or MotionValue.Single
        ? 1
        : 4;

    /// <inheritdoc/>
    public bool Read(double[] into) => Split(_target.GetValue(_property), _shape, into);

    /// <inheritdoc/>
    public void Write(double[] from) => _target.SetValue(_property, Compose(from));

    /// <inheritdoc/>
    public object Compose(double[] from) => _shape switch
    {
        MotionValue.Colour => new Color(
            (float)Held(from[0]), (float)Held(from[1]),
            (float)Held(from[2]), (float)Held(from[3])),
        MotionValue.Edges => new Thickness(from[0], from[1], from[2], from[3]),
        MotionValue.Bounds => new Rect(from[0], from[1], from[2], from[3]),
        MotionValue.Corners => new CornerRadius(from[0], from[1], from[2], from[3]),
        MotionValue.Whole => (int)Math.Round(from[0]),
        MotionValue.Single => (float)from[0],
        _ => _fraction ? Held(from[0]) : from[0],
    };

    /// <summary>A fraction of one, kept inside its own range.</summary>
    private static double Held(double value) => Math.Clamp(value, 0, 1);

    /// <summary>
    /// The lanes a platform value is made of, or nothing when it is of a shape
    /// that does not move.
    /// </summary>
    /// <remarks>
    /// A value that has never been set reads as MAUI's own default, which for a
    /// colour is null - so a fade in starts from transparent rather than
    /// refusing to start. A width that was never asked for is -1 there, and
    /// that IS MAUI's value: a view whose size is to be moved is one whose size
    /// was set.
    /// </remarks>
    /// <param name="value">What the platform answered.</param>
    /// <param name="shape">What the value is made of.</param>
    /// <param name="into">Filled with the lanes.</param>
    /// <returns>Whether the value was of the shape asked for.</returns>
    internal static bool Split(object? value, MotionValue shape, double[] into)
    {
        switch (value)
        {
            case double number when shape == MotionValue.Number:
                into[0] = number;
                return true;

            case int whole when shape == MotionValue.Whole:
                into[0] = whole;
                return true;

            case float single when shape == MotionValue.Single:
                into[0] = single;
                return true;

            case Color colour when shape == MotionValue.Colour:
                into[0] = colour.Red;
                into[1] = colour.Green;
                into[2] = colour.Blue;
                into[3] = colour.Alpha;
                return true;

            case Thickness edges when shape == MotionValue.Edges:
                into[0] = edges.Left;
                into[1] = edges.Top;
                into[2] = edges.Right;
                into[3] = edges.Bottom;
                return true;

            case CornerRadius corners when shape == MotionValue.Corners:
                into[0] = corners.TopLeft;
                into[1] = corners.TopRight;
                into[2] = corners.BottomLeft;
                into[3] = corners.BottomRight;
                return true;

            case Rect bounds when shape == MotionValue.Bounds:
                into[0] = bounds.X;
                into[1] = bounds.Y;
                into[2] = bounds.Width;
                into[3] = bounds.Height;
                return true;

            case null:
                // Nothing was ever written. A colour starts from transparent, a
                // thickness from no edges at all, a number from zero.
                Array.Clear(into);

                return shape is not (MotionValue.Number or MotionValue.Whole
                    or MotionValue.Single);

            default:
                return false;
        }
    }

    /// <summary>
    /// What MOVES this property to that value, and where the value's lanes are
    /// - or nothing at all where there is no half-way between two of them.
    /// </summary>
    /// <remarks>
    /// The one place that decides what a moving value IS, so the three callers
    /// that ask - a flight, a visual state, and the check that keeps a property
    /// in its message when neither can carry it - cannot drift apart.
    /// </remarks>
    /// <param name="target">The control.</param>
    /// <param name="property">Which of its properties.</param>
    /// <param name="value">The value it is going to.</param>
    /// <param name="fraction">Whether a number is a fraction of one.</param>
    /// <param name="moves">What will move it.</param>
    /// <param name="to">Where it is going, lane by lane.</param>
    /// <returns>Whether the value is one a control can travel to.</returns>
    internal static bool Of(
        BindableObject target,
        BindableProperty property,
        object value,
        bool fraction,
        out IMotionTarget moves,
        out double[] to)
    {
        if (value is Brush paint)
        {
            if (MotionPaint.Of(target, property, paint) is MotionPaint painting)
            {
                to = new double[painting.Lanes];

                if (painting.Take(paint, to))
                {
                    moves = painting;
                    return true;
                }
            }

            moves = null!;
            to = [];
            return false;
        }

        if (ShapeOf(value) is not MotionValue shape)
        {
            moves = null!;
            to = [];
            return false;
        }

        var property_ = new MotionProperty(target, property, shape, fraction);

        moves = property_;
        to = new double[property_.Lanes];
        Split(value, shape, to);

        return true;
    }

    /// <summary>What shape a value of this type is, or nothing when it does not move.</summary>
    /// <param name="value">The value, normally the one a message is walking to.</param>
    /// <returns>The shape, or null for a string, an enum, a brush - anything
    /// there is no half-way of.</returns>
    internal static MotionValue? ShapeOf(object? value) => value switch
    {
        double => MotionValue.Number,
        int => MotionValue.Whole,
        float => MotionValue.Single,
        Color => MotionValue.Colour,
        Thickness => MotionValue.Edges,
        CornerRadius => MotionValue.Corners,
        Rect => MotionValue.Bounds,
        _ => null,
    };
}

/// <summary>
/// Where a child SITS inside a layout, moved by arranging it there.
/// </summary>
/// <remarks>
/// <para>
/// A layout's arrangement is not a property of anything, which is why a view
/// that changes place has always JUMPED there while every colour and opacity
/// beside it could glide. This is the answer: the layout works out where its
/// children belong and hands each rectangle over as a setpoint, and the frames
/// in between are the engine's like any others.
/// </para>
/// <para>
/// Writing is <c>Arrange</c> alone - no measuring, no invalidating, nothing
/// that would ask the layout to think again - so a child moving across a page
/// costs one frame write and not one layout pass. That holds on three of the
/// four platforms, and Windows is the exception: see <see cref="Write"/>.
/// </para>
/// </remarks>
internal sealed class MotionFrame : IMotionTarget
{
    /// <summary>The one key every arrangement channel is filed under.</summary>
    /// <remarks>
    /// A child has exactly one place in its parent, so one key does for all of
    /// them - and it must not be a string, which another key could equal.
    /// </remarks>
    internal static readonly object Place = new();

    private readonly IView _child;

#if WINDOWS
    /// <summary>What arranges it - the one thing that can ask for a pass.</summary>
    private readonly Microsoft.Maui.Controls.Layout _layout;
#endif

    /// <summary>Names a child's place in its layout as something to move.</summary>
    /// <param name="child">The child.</param>
    /// <param name="layout">The layout that arranges it.</param>
    internal MotionFrame(IView child, Microsoft.Maui.Controls.Layout layout)
    {
        _child = child;

#if WINDOWS
        _layout = layout;
#endif
    }

    /// <inheritdoc/>
    public object Owner => _child;

    /// <inheritdoc/>
    public object Key => Place;

    /// <inheritdoc/>
    public int Lanes => 4;

    /// <inheritdoc/>
    public bool Read(double[] into)
    {
        Rect frame = _child.Frame;

        into[0] = frame.X;
        into[1] = frame.Y;
        into[2] = frame.Width;
        into[3] = frame.Height;

        return frame.Width >= 0 && frame.Height >= 0;
    }

    /// <summary>Puts the child there.</summary>
    /// <remarks>
    /// <para>
    /// WINDOWS ARRANGES BY ASKING, and between passes nothing is listening.
    /// Three platforms write a view's geometry straight onto it - Apple sets
    /// <c>Center</c> and <c>Bounds</c>, Android calls <c>Layout</c>, GTK4 puts
    /// the widget - so a rectangle handed over on a frame is on the screen at
    /// the next paint. WinUI's <c>Arrange</c> is a message to the XAML layout
    /// system instead, and outside that system's own pass it does nothing at
    /// all: measured on the gallery's Grid, a column widened over 188 ms of
    /// frames, every one of them written and every one of them ignored - the
    /// view stood at 208.5, 396.5 wide, until it jumped to the target in a
    /// single step, which is a reader seeing no motion whatever.
    /// </para>
    /// <para>
    /// So on Windows the pass is asked for, of the LAYOUT: its own arrangement
    /// is the arranger, which puts every child where the motion has reached, and
    /// a write made INSIDE a pass lands. Which is also why nothing is asked for
    /// while <see cref="MotionArranger.Arranging"/> says a pass is under way -
    /// that write has landed already, and asking would only dirty the pass
    /// making it.
    /// </para>
    /// </remarks>
    /// <param name="from">The lanes to write.</param>
    public void Write(double[] from)
    {
        _child.Arrange((Rect)Compose(from));

#if WINDOWS
        if (MotionArranger.Arranging == 0
            && _layout.Handler?.PlatformView is Microsoft.UI.Xaml.UIElement panel)
        {
            panel.InvalidateArrange();
        }
#endif
    }

    /// <inheritdoc/>
    public object Compose(double[] from) =>
        new Rect(from[0], from[1], Math.Max(from[2], 0), Math.Max(from[3], 0));
}

/// <summary>
/// A BRUSH, moved by crossing its colours.
/// </summary>
/// <remarks>
/// <para>
/// A gradient is the one value on this side made of a variable number of
/// numbers, which is why it is a target of its own rather than another shape:
/// how many lanes it has depends on how many stops it has.
/// </para>
/// <para>
/// Two brushes cross only when they are the same KIND and have the same number
/// of stops; anything else is a different picture rather than the same one
/// somewhere else, and arrives. That is what makes a theme change uniform - a
/// panel's flat colour and a header's gradient cross together, where the
/// gradient used to be the one thing on the screen that blinked.
/// </para>
/// </remarks>
internal sealed class MotionPaint : IMotionTarget
{
    /// <summary>The numbers a gradient's geometry is made of.</summary>
    private const int Geometry = 4;

    /// <summary>And one stop: a colour and where it sits.</summary>
    private const int PerStop = 5;

    private readonly BindableObject _target;
    private readonly BindableProperty _property;
    private readonly int _stops;
    private readonly bool _radial;

    private MotionPaint(
        BindableObject target, BindableProperty property, int stops, bool radial)
    {
        _target = target;
        _property = property;
        _stops = stops;
        _radial = radial;
    }

    /// <summary>
    /// Names a brush property as something to move, or nothing where the brush
    /// is of a kind with no numbers to cross.
    /// </summary>
    /// <param name="target">The control.</param>
    /// <param name="property">Which of its properties.</param>
    /// <param name="paint">The brush it is going to.</param>
    /// <returns>The target, or null.</returns>
    internal static MotionPaint? Of(BindableObject target, BindableProperty property, Brush paint) =>
        paint switch
        {
            SolidColorBrush => new MotionPaint(target, property, 0, false),
            LinearGradientBrush linear when linear.GradientStops.Count > 0 =>
                new MotionPaint(target, property, linear.GradientStops.Count, false),
            RadialGradientBrush radial when radial.GradientStops.Count > 0 =>
                new MotionPaint(target, property, radial.GradientStops.Count, true),
            _ => null,
        };

    /// <inheritdoc/>
    public object Owner => _target;

    /// <inheritdoc/>
    public object Key => _property;

    /// <inheritdoc/>
    public int Lanes => _stops == 0 ? 4 : Geometry + (_stops * PerStop);

    /// <inheritdoc/>
    public bool Read(double[] into) => Take(_target.GetValue(_property), into);

    /// <inheritdoc/>
    public void Write(double[] from) => _target.SetValue(_property, Compose(from));

    /// <summary>
    /// The lanes a brush is made of, or false where it is not the same picture
    /// as this one - a different kind, or a different number of stops.
    /// </summary>
    /// <param name="value">The brush.</param>
    /// <param name="into">Filled with its lanes.</param>
    /// <returns>Whether it could be read.</returns>
    internal bool Take(object? value, double[] into)
    {
        if (_stops == 0)
        {
            if (value is not SolidColorBrush solid || solid.Color is not Color colour)
            {
                return false;
            }

            Paint(colour, into, 0);
            return true;
        }

        if (value is not GradientBrush gradient
            || gradient.GradientStops.Count != _stops
            || gradient is RadialGradientBrush != _radial)
        {
            return false;
        }

        if (gradient is RadialGradientBrush ring)
        {
            into[0] = ring.Center.X;
            into[1] = ring.Center.Y;
            into[2] = ring.Radius;
            into[3] = 0;
        }
        else if (gradient is LinearGradientBrush line)
        {
            into[0] = line.StartPoint.X;
            into[1] = line.StartPoint.Y;
            into[2] = line.EndPoint.X;
            into[3] = line.EndPoint.Y;
        }

        for (int stop = 0; stop < _stops; stop++)
        {
            int at = Geometry + (stop * PerStop);

            Paint(gradient.GradientStops[stop].Color ?? Colors.Transparent, into, at);
            into[at + 4] = gradient.GradientStops[stop].Offset;
        }

        return true;
    }

    /// <inheritdoc/>
    public object Compose(double[] from)
    {
        if (_stops == 0)
        {
            return new SolidColorBrush(Shade(from, 0));
        }

        var stops = new GradientStopCollection();

        for (int stop = 0; stop < _stops; stop++)
        {
            int at = Geometry + (stop * PerStop);

            stops.Add(new GradientStop(Shade(from, at), (float)from[at + 4]));
        }

        // A NEW brush every frame, never the one that arrived: the brush in the
        // message is the tree's own value and may be shared by every view a
        // style covers, so writing through it would move all of them.
        return _radial
            ? new RadialGradientBrush(stops, new Point(from[0], from[1]), from[2])
            : new LinearGradientBrush(stops, new Point(from[0], from[1]), new Point(from[2], from[3]));
    }

    /// <summary>One colour into four lanes.</summary>
    private static void Paint(Color colour, double[] into, int at)
    {
        into[at] = colour.Red;
        into[at + 1] = colour.Green;
        into[at + 2] = colour.Blue;
        into[at + 3] = colour.Alpha;
    }

    /// <summary>And four lanes back into a colour.</summary>
    private static Color Shade(double[] from, int at) => new(
        (float)Math.Clamp(from[at], 0, 1),
        (float)Math.Clamp(from[at + 1], 0, 1),
        (float)Math.Clamp(from[at + 2], 0, 1),
        (float)Math.Clamp(from[at + 3], 0, 1));
}
