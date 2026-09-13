// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if ANDROID
namespace StateUI.Runtime.Rendering;

using Microsoft.Maui;
using Microsoft.Maui.Handlers;
using Microsoft.Maui.Platform;
using AView = Android.Views.View;

/// <summary>
/// Keeps a view's transform on the one platform view MAUI arranges, when the
/// platform wraps the view in a container.
/// </summary>
/// <remarks>
/// <para>
/// On Android a view that needs a container - a border's stroke, a clip, a
/// shadow - is wrapped AFTER its properties were first mapped, and the wrap
/// re-applies nothing: every value written before it stays on the inner view,
/// about a pivot computed before the view had a frame, while every write
/// after it lands on the wrapper. The platform then draws BOTH, composed.
/// Measured on the placed gallery: a card born turned kept that turn, about
/// its own corner, through every shape that followed - the row's upright
/// cards leaned, and each shape's size multiplied the birth shape's.
/// </para>
/// <para>
/// MAUI already re-maps Visibility when the container appears; this does the
/// same for the transforms, the anchor and the opacity - the stale copy on
/// the inner view is cleared and the mappers run again, landing on whichever
/// view MAUI arranges from now on.
/// </para>
/// </remarks>
internal static class WrappedTransforms
{
    /// <summary>Whether the re-mapping is already appended.</summary>
    private static bool _armed;

    /// <summary>
    /// Appends the re-mapping to the shared view mapper. Called once from
    /// hosting; a second host in one process must not append it twice.
    /// </summary>
    internal static void Arm()
    {
        if (_armed)
        {
            return;
        }

        _armed = true;

        ViewHandler.ViewMapper.AppendToMapping(
            nameof(IViewHandler.ContainerView),
            MoveTransforms);
    }

    /// <summary>
    /// Clears the inner view's copy and writes the values onto the view MAUI
    /// now arranges.
    /// </summary>
    /// <remarks>
    /// The platform extensions are called DIRECTLY, never through
    /// <c>UpdateValue</c>: every transform mapper is a no-op while the handler
    /// is CONNECTING - the first application is one batched call, second in
    /// the mapper and so already made, to the not-yet-wrapped view - and this
    /// runs from that same connecting pass whenever the wrap came with the
    /// view's own properties.
    /// </remarks>
    /// <param name="handler">The handler whose container just changed.</param>
    /// <param name="view">The view it draws.</param>
    private static void MoveTransforms(IViewHandler handler, IView view)
    {
        if (handler.PlatformView is not AView inner)
        {
            return;
        }

        AView target = handler.ContainerView as AView ?? inner;

        if (!ReferenceEquals(target, inner))
        {
            // Identity, so only the wrapper's values draw. The inner pivot no
            // longer matters once nothing turns about it.
            inner.TranslationX = 0;
            inner.TranslationY = 0;
            inner.ScaleX = 1;
            inner.ScaleY = 1;
            inner.Rotation = 0;
            inner.RotationX = 0;
            inner.RotationY = 0;
            inner.Alpha = 1;
        }

        target.UpdateTranslationX(view);
        target.UpdateTranslationY(view);
        target.UpdateScale(view);
        target.UpdateRotation(view);
        target.UpdateRotationX(view);
        target.UpdateRotationY(view);
        target.UpdateAnchorX(view);
        target.UpdateAnchorY(view);
        target.UpdateOpacity(view);
    }
}
#endif
