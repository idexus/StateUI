// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

namespace StateUI.Runtime.Rendering;

using Microsoft.Maui.Controls;
using Microsoft.Maui.Layouts;

/// <summary>
/// The layouts this renderer builds - MAUI's own, arranging through
/// <see cref="MotionArranger"/> so that a child which changes place TRAVELS
/// there.
/// </summary>
/// <remarks>
/// <para>
/// The measuring is MAUI's, unchanged and untouched: a stack's stacking, a
/// grid's stars and spans, a flex's wrapping are the arithmetic these classes
/// inherit, and there is no second copy of it anywhere here. What is ours is
/// the ARRANGEMENT - the one step where a layout says where each child goes -
/// and owning that one step is what makes every layout in the library animate
/// by construction rather than one at a time.
/// </para>
/// <para>
/// One class per layout because a manager is asked for by a virtual method with
/// no argument: there is nowhere else to hand a layout what it needs.
/// </para>
/// </remarks>
internal static class MotionLayouts
{
    /// <summary>A vertical stack whose children travel.</summary>
    internal sealed class Vertical : VerticalStackLayout
    {
        /// <summary>What carries this layout's children to their places.</summary>
        internal required MotionEngine Engine { get; init; }

        /// <inheritdoc/>
        protected override ILayoutManager CreateLayoutManager() =>
            new MotionArranger(this, base.CreateLayoutManager(), Engine);
    }

    /// <summary>A horizontal stack whose children travel.</summary>
    internal sealed class Horizontal : HorizontalStackLayout
    {
        /// <summary>What carries this layout's children to their places.</summary>
        internal required MotionEngine Engine { get; init; }

        /// <inheritdoc/>
        protected override ILayoutManager CreateLayoutManager() =>
            new MotionArranger(this, base.CreateLayoutManager(), Engine);
    }

    /// <summary>
    /// A grid whose children travel - so a column that changes width carries
    /// everything standing in it across.
    /// </summary>
    internal sealed class Rows : Grid
    {
        /// <summary>What carries this layout's children to their places.</summary>
        internal required MotionEngine Engine { get; init; }

        /// <inheritdoc/>
        protected override ILayoutManager CreateLayoutManager() =>
            new MotionArranger(this, base.CreateLayoutManager(), Engine);
    }

    /// <summary>
    /// An absolute layout whose children travel - which is what makes a
    /// placement written in Swift into a layout that moves.
    /// </summary>
    internal sealed class Placed : AbsoluteLayout
    {
        /// <summary>What carries this layout's children to their places.</summary>
        internal required MotionEngine Engine { get; init; }

        /// <inheritdoc/>
        protected override ILayoutManager CreateLayoutManager() =>
            new MotionArranger(this, base.CreateLayoutManager(), Engine);
    }

    /// <summary>A flex layout whose children travel.</summary>
    internal sealed class Flexed : FlexLayout
    {
        /// <summary>What carries this layout's children to their places.</summary>
        internal required MotionEngine Engine { get; init; }

        /// <inheritdoc/>
        protected override ILayoutManager CreateLayoutManager() =>
            new MotionArranger(this, base.CreateLayoutManager(), Engine);
    }
}
