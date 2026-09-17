// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

namespace StateUI.Maui.Rendering;

using Microsoft.Maui.Controls;
using StateUI.Maui.Protocol;

/// <summary>
/// A plain value on one property, set as it stands - a flag, a count, a number
/// that never travels, a choice, a day or a time.
/// </summary>
internal sealed class PlainAttachment : StateAttachment
{
    /// <summary>A plain value on one control's property.</summary>
    /// <param name="view">The control, held weakly.</param>
    /// <param name="entry">What the message said.</param>
    /// <param name="property">The property it is set on.</param>
    internal PlainAttachment(BindableObject view, HostStateBinding entry, BindableProperty property)
        : base(view, entry, property)
    {
    }

    /// <summary>
    /// Sets a plain value on the property, boxed to the property's own type,
    /// and only where the control does not already show it: one lane is a
    /// flag from nought and one, a count from a whole number, a number as it
    /// is, or a member; three are a date (year, month, day) on a
    /// <c>DateTime</c> property and a time (hour, minute, second) on a
    /// <c>TimeSpan</c> one.
    /// </summary>
    /// <remarks>
    /// THE ASSIGNMENT RUNS UNDER <see cref="Walker.Writing"/>: the
    /// platform raises the property's changed notification synchronously
    /// inside it, and that notification is this side's own write coming
    /// round - refused as an event by the renderer and as a report by the
    /// cycle, so a value the tree wrote never reaches a handler or lands on
    /// the state a second time.
    /// </remarks>
    /// <param name="lanes">The value, lane by lane.</param>
    internal void Set(double[] lanes)
    {
        if (Property is null || View is not BindableObject view || lanes.Length == 0)
        {
            return;
        }

        // BRANCH BY BRANCH, not one conditional: a nested conditional over
        // int, long, float and double is typed DOUBLE as a whole, and a
        // whole number boxed as 2.0 is refused by an int property in silence.
        Type type = Nullable.GetUnderlyingType(Property.ReturnType) ?? Property.ReturnType;
        double value = lanes[0];
        object? boxed;

        if (type == typeof(DateTime) || type == typeof(TimeSpan))
        {
            // THREE LANES MAKE A DAY OR A TIME, composed the way the described
            // value is (Values.GetDate / GetTime) and refused the same
            // way: a day that does not exist sets nothing, so the picker goes
            // on showing the one it had.
            if (lanes.Length < 3)
            {
                return;
            }

            try
            {
                boxed = type == typeof(DateTime)
                    ? new DateTime((int)Math.Round(lanes[0]), (int)Math.Round(lanes[1]), (int)Math.Round(lanes[2]))
                    : new TimeSpan((int)Math.Round(lanes[0]), (int)Math.Round(lanes[1]), (int)Math.Round(lanes[2]));
            }
            catch (ArgumentOutOfRangeException)
            {
                return;
            }
        }
        else if (type == typeof(bool)) { boxed = value != 0; }
        else if (type == typeof(int)) { boxed = (int)Math.Round(value); }
        else if (type == typeof(long)) { boxed = (long)Math.Round(value); }
        else if (type == typeof(float)) { boxed = (float)value; }
        else if (type == typeof(double)) { boxed = value; }
        else
        {
            // A CHOICE - an alignment, a keyboard, a line break, a set of
            // flags - through the SAME table a described property goes
            // through, handed the member number the way the wire carries one.
            // So a channel understands every member the tree can describe,
            // and a member added later is understood the day it arrives.
            boxed = PropertyTable.Value(Property, Said(Key, (int)Math.Round(value)), Key);

            if (boxed is null)
            {
                return;
            }
        }

        // AGAINST THE CONTROL, not against the last lane: a value the platform
        // coerced away - a choice landed before its list - is set again the
        // next time the state says it, and one the control already shows is
        // not set twice.
        if (Equals(view.GetValue(Property), boxed))
        {
            return;
        }

        Walker.Writing++;

        try
        {
            view.SetValue(Property, boxed);
        }
        finally
        {
            Walker.Writing--;
        }
    }

    /// <summary>
    /// A member number as a NODE says it - what the conversion table reads.
    /// </summary>
    /// <param name="key">Which property it is about.</param>
    /// <param name="member">The member's number, this library's own.</param>
    /// <returns>A node carrying that one value under that one key.</returns>
    private static HostPatch Said(HostPropKey key, int member)
    {
        var said = new HostPatch();

        if (key.Name is string own)
        {
            said.OwnProps = new Dictionary<string, HostValue> { [own] = HostValue.OfMember(member) };
        }
        else
        {
            said.Props = new Dictionary<HostProp, HostValue> { [key.Prop] = HostValue.OfMember(member) };
        }

        return said;
    }

    /// <inheritdoc/>
    internal override void Landed(byte[] bytes, Walker walker) => Set(StateBatch.Lanes(bytes));

    /// <inheritdoc/>
    internal override void Wear(byte[] bytes, ulong mask, Walker walker, Action<int, bool> land) =>
        Set(StateBatch.Lanes(bytes));
}
