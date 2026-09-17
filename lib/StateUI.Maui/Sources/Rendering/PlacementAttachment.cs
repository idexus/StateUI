// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

namespace StateUI.Maui.Rendering;

using System.Runtime.CompilerServices;
using Microsoft.Maui.Controls;
using StateUI.Maui.Protocol;

/// <summary>
/// A run of placements, worn by a layout's children - one journey per view,
/// under the run's own law.
/// </summary>
internal sealed class PlacementAttachment : StateAttachment
{
    /// <summary>A run of placements on one layout.</summary>
    /// <param name="view">The layout, held weakly.</param>
    /// <param name="entry">What the message said.</param>
    internal PlacementAttachment(BindableObject view, HostStateBinding entry)
        : base(view, entry, null)
    {
    }

    /// <summary>Every lane, for a run nothing has been told about yet.</summary>
    private const ulong All = ~0UL;

    /// <summary>Where each placed view's journey is kept.</summary>
    /// <remarks>
    /// WEAK, because these outlive nothing: a view taken out of the run is a
    /// view this must let go of, and the attachment belongs to a layout that
    /// belongs to a page.
    /// </remarks>
    private readonly ConditionalWeakTable<View, MotionPlacement> _seats = new();

    /// <summary>Whether a turn is already booked to write the sizes owing.</summary>
    private bool _settling;

    /// <inheritdoc/>
    /// <remarks>
    /// WHOLE, because nothing has been placed yet - and every one of them
    /// arrives rather than travelling, a view nobody has placed having
    /// nowhere to travel from.
    /// </remarks>
    internal override void Landed(byte[] bytes, Walker walker) => Placed(bytes, All, walker);

    /// <inheritdoc/>
    internal override void Wear(byte[] bytes, ulong mask, Walker walker, Action<int, bool> land) =>
        Placed(bytes, mask, walker);

    /// <summary>
    /// A run of placements, worn by the layout's children.
    /// </summary>
    /// <remarks>
    /// <para>
    /// ONE JOURNEY PER VIEW. The law is the RUN's - written by whoever worked
    /// the placements out, so the same arithmetic lands at once while a hand
    /// is moving it and travels when the shape of the layout changes - and a
    /// run written during a journey BENDS it rather than starting it again,
    /// which is what lets a finger go on moving cards that are crossing.
    /// </para>
    /// <para>
    /// A run shorter than the views leaves the rest where they are; one longer
    /// is read as far as there are views to wear it. Neither is a fault: the
    /// tree and the state are written by different halves at different moments,
    /// and the next cycle settles it.
    /// </para>
    /// </remarks>
    /// <param name="bytes">The run, whole.</param>
    /// <param name="mask">Which lanes moved.</param>
    /// <param name="walker">What moves the values.</param>
    private void Placed(byte[] bytes, ulong mask, Walker walker)
    {
        if (View is not Microsoft.Maui.Controls.Layout layout)
        {
            return;
        }

        double[] lanes = StateBatch.Lanes(bytes);
        int width = MotionPlacement.Fields;
        int run = Math.Min((lanes.Length - JourneyCodec.LawLanes) / width, layout.Count);

        if (run <= 0)
        {
            return;
        }

        HostMotion spec = walker.Law(lanes, lanes.Length - JourneyCodec.LawLanes);
        bool owing = false;

        for (int index = 0; index < run; index++)
        {
            if (layout[index] is not View child || !Moved(mask, index, width))
            {
                continue;
            }

            Array.Copy(lanes, index * width, _place, 0, width);

            MotionPlacement seat = _seats.GetValue(child, static held => new MotionPlacement(held));

            if (seat.Wearing(_place))
            {
                continue;
            }

            seat.Holding(_place);

            if (spec.Instant)
            {
                // AT ONCE, and whatever was carrying this view lets go: the
                // arithmetic has just said where the view is, which is not a
                // destination but a fact.
                walker.Halt(child, MotionPlacement.Seat, TripEnd.Nothing);
                seat.Write(_place);
            }
            else
            {
                walker.Aim(seat, _place, spec);
            }

            owing |= seat.Owing;
        }

        if (owing)
        {
            Settle(layout);
        }
    }

    /// <summary>One view's twelve lanes, kept rather than made per frame.</summary>
    private readonly double[] _place = new double[MotionPlacement.Fields];

    /// <summary>Whether any of one view's lanes is named by the mask.</summary>
    /// <remarks>
    /// A DIRTY MASK IS A WORD OF BITS and a run is twelve lanes a view, so
    /// past lane 62 there is no bit left to name one: every lane from there on
    /// shares the highest, and the views they belong to are all told together.
    /// Which costs the platform nothing - a view given the place it already
    /// has is skipped here, before any write is made.
    /// </remarks>
    /// <param name="mask">Which lanes moved.</param>
    /// <param name="index">Which view.</param>
    /// <param name="width">How many lanes one view takes.</param>
    /// <returns>Whether this view has anything to hear.</returns>
    private static bool Moved(ulong mask, int index, int width)
    {
        for (int lane = index * width; lane < (index + 1) * width; lane++)
        {
            if ((mask & (1UL << Math.Min(lane, 63))) != 0)
            {
                return true;
            }
        }

        return false;
    }

    /// <summary>
    /// Writes the sizes a layout pass would not take, on the turn after it.
    /// </summary>
    /// <remarks>
    /// One turn per layout at a time: every view that could not have its
    /// rectangle written is waiting for the same moment, which is the first
    /// one outside the pass. See <see cref="MotionPlacement.Wear"/>.
    /// </remarks>
    /// <param name="layout">The layout whose children are owed a size.</param>
    private void Settle(Microsoft.Maui.Controls.Layout layout)
    {
        if (_settling)
        {
            return;
        }

        _settling = true;

        layout.Dispatcher.Dispatch(() =>
        {
            _settling = false;

            for (int index = 0; index < layout.Count; index++)
            {
                if (layout[index] is View child && _seats.TryGetValue(child, out MotionPlacement? seat))
                {
                    seat.Settle();
                }
            }
        });
    }
}
