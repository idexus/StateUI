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
    public int Lanes => _shape == MotionValue.Number ? 1 : 4;

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
                return shape != MotionValue.Number;

            default:
                return false;
        }
    }

    /// <summary>What shape a value of this type is, or nothing when it does not move.</summary>
    /// <param name="value">The value, normally the one a message is walking to.</param>
    /// <returns>The shape, or null for a string, an enum, a brush - anything
    /// there is no half-way of.</returns>
    internal static MotionValue? ShapeOf(object? value) => value switch
    {
        double => MotionValue.Number,
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
/// costs one frame write and not one layout pass.
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

    /// <summary>Names a child's place in its layout as something to move.</summary>
    /// <param name="child">The child.</param>
    internal MotionFrame(IView child) => _child = child;

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

    /// <inheritdoc/>
    public void Write(double[] from) => _child.Arrange((Rect)Compose(from));

    /// <inheritdoc/>
    public object Compose(double[] from) =>
        new Rect(from[0], from[1], Math.Max(from[2], 0), Math.Max(from[3], 0));
}
