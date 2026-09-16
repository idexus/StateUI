// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

using Microsoft.Maui.Controls.Shapes;
using StateUI.Maui.Protocol;

namespace StateUI.Maui.Rendering;

/// <summary>
/// How this host realizes one element: which of the element's members its
/// control takes, and what each one does to it.
/// </summary>
/// <remarks>
/// <para>
/// The registration IS the realization record. What a member's setter is given
/// has already been read as the type the member declares, so a control is
/// written with a value rather than with a wire shape - and a member the
/// message does not carry is not offered at all, since a patch names only what
/// changed.
/// </para>
/// <para>
/// A member is named by its <see cref="HostProp"/> until the contracts are
/// generated as typed C# accessors, when the same call site reads
/// <c>r.Property(ProgressBarContract.Progress, …)</c> and the value's type
/// comes from the member instead of from the call.
/// </para>
/// </remarks>
internal abstract class Realization
{
    /// <summary>One member and what it writes onto the control.</summary>
    /// <param name="Member">The member, as this side names it.</param>
    /// <param name="Write">Writes the member's value onto the control.</param>
    internal sealed record Applier(HostProp Member, Action<View, HostPatch> Write);

    /// <summary>The members this realization writes, in the order registered.</summary>
    internal List<Applier> Appliers { get; } = [];

    /// <summary>What the control is subscribed to, once, where it is made.</summary>
    internal List<Action<View, StateUIRenderer>> Wiring { get; } = [];

    /// <summary>
    /// Subscribes the control to what it reports, once - where it is made,
    /// the rule every built-in follows.
    /// </summary>
    /// <param name="view">The control.</param>
    /// <param name="renderer">The renderer its reports go to.</param>
    internal void Wire(View view, StateUIRenderer renderer)
    {
        foreach (Action<View, StateUIRenderer> wire in Wiring)
        {
            wire(view, renderer);
        }
    }

    /// <summary>
    /// Writes every member the message carries onto the control.
    /// </summary>
    /// <remarks>
    /// A member absent from the patch is one this message says nothing about,
    /// and is left exactly as it stands - the rule the whole wire follows.
    /// </remarks>
    /// <param name="view">The control.</param>
    /// <param name="node">The message about it.</param>
    internal void Apply(View view, HostPatch node)
    {
        foreach (Applier applier in Appliers)
        {
            if (node.Props?.ContainsKey(applier.Member) == true)
            {
                applier.Write(view, node);
            }
        }
    }
}

/// <summary>
/// The realization of one element, typed to the control this host makes for it -
/// so every setter is written against the real class rather than against
/// <see cref="View"/>.
/// </summary>
/// <typeparam name="TControl">The control's own class.</typeparam>
internal sealed class Realization<TControl> : Realization
    where TControl : View
{
    /// <summary>
    /// Registers one of the element's properties: the member, and what its
    /// value does to the control.
    /// </summary>
    /// <remarks>
    /// The setter runs only when a message CARRIES the member, so it is handed
    /// a value rather than an absence - and a control keeps what it has where
    /// the tree says nothing, which is what a sparse patch means.
    /// </remarks>
    /// <typeparam name="TValue">
    /// The type the member's value crosses as - <see cref="double"/>,
    /// <see cref="bool"/>, <see cref="string"/> or <see cref="int"/> for a
    /// member of a closed vocabulary.
    /// </typeparam>
    /// <param name="member">The member this host realizes.</param>
    /// <param name="write">What the value does to the control.</param>
    /// <returns>The same realization, so members chain.</returns>
    internal Realization<TControl> Property<TValue>(HostProp member, Action<TControl, TValue> write)
    {
        Appliers.Add(new Applier(member, (view, node) =>
        {
            if (Read<TValue>(node, member) is TValue value)
            {
                write((TControl)view, value);
            }
        }));

        return this;
    }

    /// <summary>
    /// Registers a property whose value has a READER of its own - a colour,
    /// a thickness, a member of a vocabulary this side maps onto MAUI's.
    /// </summary>
    /// <remarks>
    /// <para>
    /// The conversions live in <see cref="Values"/>, one per kind, and this
    /// takes one rather than growing a second copy of that table: the
    /// mechanism does not know the library's vocabulary, it carries it. A
    /// reader answering null is a value of another kind, and writes nothing -
    /// the same answer every reader on this side gives.
    /// </para>
    /// <para>
    /// This one takes a VALUE and <see cref="Held{TValue}"/> a reference, and
    /// that is the C# of it rather than a choice: <c>TValue?</c> means
    /// <c>Nullable&lt;TValue&gt;</c> for a struct and the plain reference for a
    /// class, so one method taking both leaves the compiler unable to infer
    /// which - and it then guesses at the other overload, reporting the failure
    /// as a reader called on the control. The constraints tell the two apart; a
    /// call site names neither.
    /// </para>
    /// </remarks>
    /// <typeparam name="TValue">What the reader answers.</typeparam>
    /// <param name="member">The member this host realizes.</param>
    /// <param name="read">Reads the member's value out of the message.</param>
    /// <param name="write">What the value does to the control.</param>
    internal Realization<TControl> Property<TValue>(
        HostProp member,
        Func<HostPatch, HostProp, TValue?> read,
        Action<TControl, TValue> write)
        where TValue : struct
    {
        Appliers.Add(new Applier(member, (view, node) =>
        {
            if (read(node, member) is TValue value)
            {
                write((TControl)view, value);
            }
        }));

        return this;
    }

    /// <summary>
    /// The same, for a value whose reader answers a REFERENCE - a colour, a
    /// name, a text.
    /// </summary>
    /// <remarks>
    /// A name of its own rather than another <c>Property</c>: <c>TValue?</c>
    /// means <c>Nullable&lt;TValue&gt;</c> for a struct and the plain reference
    /// for a class, so two overloads of one name leave the compiler unable to
    /// infer which is meant - and it then reports the failure as a reader
    /// called on the control, which says nothing about the real cause. Two
    /// names cost one word at each call site and nothing anywhere else.
    /// </remarks>
    /// <typeparam name="TValue">What the reader answers.</typeparam>
    /// <param name="member">The member this host realizes.</param>
    /// <param name="read">Reads the member's value out of the message.</param>
    /// <param name="write">What the value does to the control.</param>
    internal Realization<TControl> Held<TValue>(
        HostProp member,
        Func<HostPatch, HostProp, TValue?> read,
        Action<TControl, TValue> write)
        where TValue : class
    {
        Appliers.Add(new Applier(member, (view, node) =>
        {
            if (read(node, member) is TValue value)
            {
                write((TControl)view, value);
            }
        }));

        return this;
    }

    /// <summary>
    /// Registers the FONT the control draws its text in - the four members of
    /// the font tier, together, because they are one tier and not four
    /// properties of this control.
    /// </summary>
    /// <remarks>
    /// <para>
    /// The setters are the registration's because MAUI's
    /// <c>IFontElement</c> declares these GET-ONLY and the controls wearing
    /// them share no base class, so only a caller that knows the class can
    /// assign them. That is the whole reason this host had one font method per
    /// control; here the tier is declared once and the class is named four
    /// times instead of ten methods being written out.
    /// </para>
    /// <para>
    /// The FAMILY is a NAME, never text: it names a font an author registered
    /// and repeats on every control wearing it, so it rides the session's
    /// dictionary. Read as text it answers null, which is a font silently not
    /// applied.
    /// </para>
    /// </remarks>
    /// <param name="size">Takes the font's size.</param>
    /// <param name="family">Takes the font's family, by name.</param>
    /// <param name="attributes">Takes bold and italic.</param>
    /// <param name="scaling">Takes whether it follows the reader's text size.</param>
    internal Realization<TControl> Font(
        Action<TControl, double> size,
        Action<TControl, string> family,
        Action<TControl, FontAttributes> attributes,
        Action<TControl, bool> scaling) =>
        Property(HostProp.FontSize, static (node, member) => node.GetNumber(member), size)
            .Held(HostProp.FontFamily, static (node, member) => node.GetName(member), family)
            .Property(
                HostProp.FontAttributes,
                static (node, member) => node.GetFontAttributes(member),
                attributes)
            .Property(
                HostProp.FontAutoScalingEnabled,
                static (node, member) => node.GetBool(member),
                scaling);

    /// <summary>
    /// Registers what the READER changes: the member whose value they moved,
    /// the control's own property carrying it, and the event the tree hears.
    /// </summary>
    /// <remarks>
    /// <para>
    /// ONE call, because the two halves have ONE order and it is not the
    /// registration's to choose: the value goes onto the state that carries it
    /// FIRST, and only then does the event reach its handler - which is what
    /// every arm of this renderer that reports a reader's value does, from a
    /// picker's choice to a switch's flip. A registration that could write them
    /// the other way round would be a registration that could get it wrong.
    /// </para>
    /// <para>
    /// The subscription is made where the control is MADE, once, and lives as
    /// long as it does.
    /// </para>
    /// <para>
    /// The MEMBER is not named again here: <c>Property</c> already declares
    /// which member this control realizes, and a second spelling of it would
    /// be a second place to get it wrong.
    /// </para>
    /// </remarks>
    /// <typeparam name="TReported">What the reader's value is, as the event carries it.</typeparam>
    /// <param name="property">The control's own property carrying the value.</param>
    /// <param name="raised">The event the tree hears.</param>
    /// <param name="subscribe">
    /// Subscribes to the control's own notification, and hands back what the
    /// reader made it.
    /// </param>
    internal Realization<TControl> Reports<TReported>(
        BindableProperty property,
        HostEvent raised,
        Action<TControl, Action<TReported>> subscribe)
    {
        Wiring.Add((view, renderer) =>
        {
            var control = (TControl)view;

            subscribe(control, reported =>
            {
                renderer.Reported(control, property, Lanes(reported));
                renderer.Raise(control, raised, Value(reported));
            });
        });

        return this;
    }

    /// <summary>
    /// Registers a value the reader MOVES - a slider dragged, a stepper
    /// stepped - which is a different channel from a value they merely change.
    /// </summary>
    /// <remarks>
    /// <para>
    /// A moved value lands on the state WITH ITS DESTINATION: the reader has
    /// just put it where it stands, so whatever was carrying it there stops
    /// pulling, and every other control on the same number is written the
    /// reader's own number. That is what <c>CarriedReports.Reader</c> does and
    /// <c>Reported</c> does not - and the two are told apart by the attachment
    /// the state wears, not by the control, so a registration has to say which
    /// it means.
    /// </para>
    /// <para>
    /// The event follows the landing, the order every arm of this renderer
    /// keeps.
    /// </para>
    /// </remarks>
    /// <param name="property">The control's own property carrying the value.</param>
    /// <param name="raised">The event the tree hears.</param>
    /// <param name="subscribe">Subscribes to the control's own notification.</param>
    internal Realization<TControl> Moves(
        BindableProperty property,
        HostEvent raised,
        Action<TControl, Action<double>> subscribe)
    {
        Wiring.Add((view, renderer) =>
        {
            var control = (TControl)view;

            subscribe(control, moved =>
            {
                renderer.Moved(control, property, moved);
                renderer.Raise(control, raised, HostValue.Of(moved));
            });
        });

        return this;
    }

    /// <summary>
    /// Registers an event the control raises with NOTHING to say - a drag
    /// begun, a drag ended.
    /// </summary>
    /// <remarks>
    /// No value goes onto a state here, because none was moved: the two ends of
    /// a drag are moments, not values, and the value between them has already
    /// travelled through <see cref="Moves"/>.
    /// </remarks>
    /// <param name="raised">The event the tree hears.</param>
    /// <param name="subscribe">Subscribes to the control's own notification.</param>
    internal Realization<TControl> Raises(HostEvent raised, Action<TControl, Action> subscribe)
    {
        Wiring.Add((view, renderer) =>
        {
            var control = (TControl)view;

            subscribe(control, () => renderer.Raise(control, raised));
        });

        return this;
    }

    /// <summary>
    /// Registers the two members of the text-style tier - the colour text is
    /// drawn in, and the room between its letters.
    /// </summary>
    /// <param name="colour">Takes the text's colour.</param>
    /// <param name="spacing">Takes the space between letters.</param>
    internal Realization<TControl> TextStyle(
        Action<TControl, Color> colour,
        Action<TControl, double> spacing) =>
        Held(HostProp.TextColor, static (node, member) => node.GetColor(member), colour)
            .Property(
                HostProp.CharacterSpacing,
                static (node, member) => node.GetNumber(member),
                spacing);

    /// <summary>
    /// Registers the two members of the text-alignment tier - where the text
    /// sits across its control, and down it.
    /// </summary>
    /// <param name="across">Takes the alignment across.</param>
    /// <param name="down">Takes the alignment down.</param>
    internal Realization<TControl> TextAligned(
        Action<TControl, TextAlignment> across,
        Action<TControl, TextAlignment> down) =>
        Property(
                HostProp.HorizontalTextAlignment,
                static (node, member) => node.GetTextAlignment(member),
                across)
            .Property(
                HostProp.VerticalTextAlignment,
                static (node, member) => node.GetTextAlignment(member),
                down);

    /// <summary>A reported value as the lanes a state carries it in.</summary>
    private static double[] Lanes<TReported>(TReported reported) => reported switch
    {
        bool flag => [flag ? 1 : 0],
        double number => [number],
        int member => [member],
        _ => throw new NotSupportedException(
            $"a reader's value cannot be carried as {typeof(TReported).Name}: a state "
            + "carries flags, numbers and members of a closed vocabulary."),
    };

    /// <summary>The same value as the event's payload.</summary>
    private static HostValue Value<TReported>(TReported reported) => reported switch
    {
        bool flag => HostValue.Of(flag),
        double number => HostValue.Of(number),
        int member => HostValue.Of((double)member),
        _ => throw new NotSupportedException(
            $"an event cannot carry {typeof(TReported).Name}."),
    };

    /// <summary>
    /// A member's value in the type it is declared as, or null where the
    /// message carries another kind - which is a Swift side and a host that
    /// disagree about the member, never something to guess at.
    /// </summary>
    private static TValue? Read<TValue>(HostPatch node, HostProp member)
    {
        object? value = default(TValue) switch
        {
            double => node.GetNumber(member),
            bool => node.GetBool(member),
            int => node.GetEnumeration(member),
            _ when typeof(TValue) == typeof(string) => node.GetString(member),
            _ => throw new NotSupportedException(
                $"a member cannot be realized as {typeof(TValue).Name}: the kinds a "
                + "property crosses as are number, flag, text and a member of a closed "
                + "vocabulary."),
        };

        return value is TValue read ? read : default;
    }
}

/// <summary>
/// The tiers a realization can only declare for a control of a certain KIND.
/// </summary>
/// <remarks>
/// Extensions rather than methods on the realization itself, because a
/// constraint cannot be added to the class's own type parameter one method at a
/// time. The font tier needs none of this - its setters belong to the
/// registration, so the mechanism never has to know the class - while the input
/// tier's belong here, MAUI having a real <c>InputView</c> base class to assign
/// through.
/// </remarks>
internal static class RealizedTiers
{
    /// <summary>
    /// Registers what a reader TYPES, and with it the whole of the input tier -
    /// the members every field wears, and the one channel a text goes down.
    /// </summary>
    /// <remarks>
    /// <para>
    /// A text is a third channel, neither of the other two: it crosses WHOLE,
    /// its length and its letters, and the attachment remembers the words so
    /// the state's echo is not written back under the reader's caret. The
    /// renderer owns that call because it owns the two things around it - the
    /// cap a field was given, which the platform does not keep on its own, and
    /// the <c>textChanged</c> the tier declares. So a registration says the
    /// tier is worn; it does not say them again one at a time.
    /// </para>
    /// <para>
    /// Every member here belongs to <c>InputView</c>, which MAUI has as a real
    /// base class - so, unlike the font tier, the setters are this method's
    /// rather than the registration's.
    /// </para>
    /// </remarks>
    /// <param name="realization">The realization the tier is declared on.</param>
    /// <param name="subscribe">Subscribes to the control's own text notification.</param>
    internal static Realization<TControl> Input<TControl>(
        this Realization<TControl> realization,
        Action<TControl, Action<string?>> subscribe)
        where TControl : InputView
    {
        realization.Wiring.Add((view, renderer) =>
        {
            var control = (TControl)view;

            subscribe(control, words => renderer.Typed(control, words));
        });

        return realization
            .Held(HostProp.Text,
                static (node, member) => node.GetString(member),
                static (view, text) => view.Text = text)
            .Held(HostProp.Placeholder,
                static (node, member) => node.GetString(member),
                static (view, placeholder) => view.Placeholder = placeholder)
            .Held(HostProp.PlaceholderColor,
                static (node, member) => node.GetColor(member),
                static (view, colour) => view.PlaceholderColor = colour)
            .Property(HostProp.IsReadOnly,
                static (node, member) => node.GetBool(member),
                static (view, only) => view.IsReadOnly = only)

            // The cap is kept on the control rather than handed to MAUI, whose
            // own MaxLength holds the value and lets the platform view show
            // what was typed. See StateUIRenderer.MaxLengthProperty.
            .Property(HostProp.MaximumLength,
                static (node, member) => node.GetInt(member),
                static (view, length) => view.SetValue(StateUIRenderer.MaxLengthProperty, length))
            .Held(HostProp.InputPurpose,
                static (node, member) => node.GetKeyboard(member),
                static (view, keyboard) => view.Keyboard = keyboard)
            .Property(HostProp.IsSpellCheckEnabled,
                static (node, member) => node.GetBool(member),
                static (view, checking) => view.IsSpellCheckEnabled = checking)
            .Property(HostProp.IsTextPredictionEnabled,
                static (node, member) => node.GetBool(member),
                static (view, predicting) => view.IsTextPredictionEnabled = predicting)
            .Property(HostProp.CursorPosition,
                static (node, member) => node.GetInt(member),
                static (view, caret) => view.CursorPosition = caret)
            .Property(HostProp.SelectionLength,
                static (node, member) => node.GetInt(member),
                static (view, length) => view.SelectionLength = length);
    }

    /// <summary>
    /// Registers the SHAPE tier - what every drawn outline has, whichever
    /// outline it is: how it is filled, how it is stroked, and the one matrix
    /// its path is run through.
    /// </summary>
    /// <remarks>
    /// <para>
    /// The setters are this method's, not the registration's, for the reason
    /// the input tier's are: MAUI has a real <c>Shape</c> base class to assign
    /// through, so six registrations say the tier is worn rather than writing
    /// ten members out apiece.
    /// </para>
    /// <para>
    /// The transform does not land on the shape but BESIDE it, on the attached
    /// matrix each wrapper runs its own path through - which is why a shape
    /// can be turned without MAUI having a per-shape handler for it.
    /// </para>
    /// </remarks>
    /// <param name="realization">The realization the tier is declared on.</param>
    internal static Realization<TControl> Shaped<TControl>(this Realization<TControl> realization)
        where TControl : Shape =>
        realization
            .Property(HostProp.Aspect,
                static (node, member) => node.GetShapeAspect(member),
                static (view, aspect) => view.Aspect = aspect)
            .Held(HostProp.Fill,
                static (node, member) => node.GetBrush(member),
                static (view, brush) => view.Fill = brush)
            .Property(HostProp.RenderTransform,
                static (node, member) => node.GetGeometryTransform(member),
                static (view, matrix) =>
                    view.SetValue(ShapeTransform.GeometryTransformProperty, matrix))
            .Held(HostProp.Stroke,
                static (node, member) => node.GetBrush(member),
                static (view, brush) => view.Stroke = brush)
            .Property(HostProp.StrokeDashOffset,
                static (node, member) => node.GetNumber(member),
                static (view, offset) => view.StrokeDashOffset = offset)
            .Held(HostProp.StrokeDashPattern,
                static (node, member) => node.GetDoubleCollection(member),
                static (view, dashes) => view.StrokeDashArray = dashes)
            .Property(HostProp.StrokeLineCap,
                static (node, member) => node.GetPenLineCap(member),
                static (view, cap) => view.StrokeLineCap = cap)
            .Property(HostProp.StrokeLineJoin,
                static (node, member) => node.GetPenLineJoin(member),
                static (view, join) => view.StrokeLineJoin = join)
            .Property(HostProp.StrokeMiterLimit,
                static (node, member) => node.GetNumber(member),
                static (view, miter) => view.StrokeMiterLimit = miter)
            .Property(HostProp.StrokeWidth,
                static (node, member) => node.GetNumber(member),
                static (view, width) => view.StrokeThickness = width);
}
