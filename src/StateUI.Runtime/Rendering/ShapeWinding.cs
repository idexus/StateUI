// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

using System.Reflection;
using Microsoft.Maui.Controls.Shapes;
using Microsoft.Maui.Graphics;

namespace StateUI.Runtime.Rendering;

/// <summary>
/// Which crossings of a self-crossing outline count as inside - the fill rule,
/// pushed onto the drawable MAUI made, because MAUI never pushes it itself.
/// </summary>
/// <remarks>
/// <para>
/// A shape drawn by Microsoft.Maui.Graphics is filled in two steps: the
/// drawable CLIPS the path with its own winding mode and fills the clipped
/// region, so an even-odd rule reaches the picture through that clip and by no
/// other road. Nothing ever sets it. The shape handler's mapper list has no
/// entry for a winding mode, and MAUI's own Polygon answers a changed
/// <c>FillRule</c> by re-mapping <c>IShapeView.Shape</c>, which rebuilds the
/// path and leaves the mode at its default - so the value lands on the
/// control, passes every test, and draws nothing. Measured on Mac Catalyst and
/// on Android as a pentagram filled solid under both rules.
/// </para>
/// <para>
/// The drawable is reached through the platform view's own public
/// <c>Drawable</c> property and told through <c>UpdateWindingMode</c>, which is
/// a public method on a type that is not public, so the call is made by
/// reflection - the one member, once, cached. That is the whole of the reach
/// into another library's insides, and the reason it is affordable is that
/// <c>TheShapeDrawableStillTakesAWindingMode</c> fails the suite the day a MAUI
/// release renames it, which is the one way a patch like this could go quiet.
/// </para>
/// </remarks>
internal static class ShapeWinding
{
    /// <summary>The method that carries the rule, looked up once per drawable
    /// type - null where this platform's drawable has none.</summary>
    private static readonly Dictionary<Type, MethodInfo?> Carriers = [];

    /// <summary>Tells the shape's drawable which crossings to count as inside,
    /// and asks for the redraw that shows it.</summary>
    /// <remarks>
    /// <para>
    /// CALLED AFTER THE PATH IS RE-MAPPED, NEVER BEFORE: mapping
    /// <c>IShapeView.Shape</c> hands the platform view a BRAND NEW drawable,
    /// so a winding mode written first is thrown away with the drawable that
    /// carried it - which is why every geometry change goes through
    /// <c>SwiftShapes.Poke</c> and this runs at the end of it. Measured: with
    /// the two the other way round the pentagram drew solid under both rules,
    /// exactly as it did with no patch at all.
    /// </para>
    /// <para>
    /// Answers quietly where there is no platform view yet: a wrapper asks
    /// again from its own <c>HandlerChanged</c>, which is when the drawable
    /// exists. It is an ordinary event with no platform observation behind it,
    /// where <c>Loaded</c> would keep the view alive for the life of the
    /// process (see <c>StateUIRenderer.WatchFrame</c>).
    /// </para>
    /// </remarks>
    /// <param name="shape">The shape whose fill is being ruled - anything else
    /// is left alone, having no rule to wear.</param>
    public static void Wear(BindableObject shape)
    {
        FillRule rule = shape switch
        {
            SwiftPolygon polygon => polygon.FillRule,
            SwiftPolyline polyline => polyline.FillRule,
            _ => FillRule.Nonzero,
        };

        if (shape is not SwiftPolygon and not SwiftPolyline
            || (shape as VisualElement)?.Handler?.PlatformView is not object platform
            || platform.GetType().GetProperty("Drawable")?.GetValue(platform) is not object drawable)
        {
            return;
        }

        Carrier(drawable.GetType())?.Invoke(
            drawable,
            [rule == FillRule.EvenOdd ? WindingMode.EvenOdd : WindingMode.NonZero]);

        // A redraw that keeps the drawable, where the shape mapping would
        // replace it and lose the mode again.
        platform.GetType()
            .GetMethod("InvalidateDrawable", BindingFlags.Public | BindingFlags.Instance, [])
            ?.Invoke(platform, null);
    }

    /// <summary>The drawable type's winding-mode method, or null.</summary>
    /// <param name="drawable">The type the platform view is drawn by.</param>
    /// <returns>The method to call, looked up once.</returns>
    private static MethodInfo? Carrier(Type drawable)
    {
        lock (Carriers)
        {
            if (!Carriers.TryGetValue(drawable, out MethodInfo? carrier))
            {
                carrier = drawable.GetMethod(
                    "UpdateWindingMode",
                    BindingFlags.Public | BindingFlags.Instance,
                    binder: null,
                    types: [typeof(WindingMode)],
                    modifiers: null);

                Carriers[drawable] = carrier;
            }

            return carrier;
        }
    }
}
