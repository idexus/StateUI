// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

using System.Reflection;
using Microsoft.Maui.Graphics;

namespace StateUI.Runtime.Tests;

/// <summary>
/// The one member this library reaches for by name inside MAUI.
/// </summary>
public class ShapeWindingTests
{
    /// <summary>
    /// MAUI'S SHAPE DRAWABLE STILL TAKES A WINDING MODE, which is the whole of
    /// what `fillRule` rides on: the drawable clips the fill with it, nothing
    /// in MAUI ever sets it, and `ShapeWinding` sets it by reflection. A
    /// release that renames or drops the method would leave every self-crossing
    /// outline quietly filled solid again, so it is asserted here rather than
    /// found on a screen.
    /// </summary>
    [Fact]
    public void TheShapeDrawableStillTakesAWindingMode()
    {
        Type? drawable = typeof(IShapeView).Assembly
            .GetTypes()
            .FirstOrDefault(type => type.Name == "ShapeDrawable");

        Assert.NotNull(drawable);

        MethodInfo? carrier = drawable!.GetMethod(
            "UpdateWindingMode",
            BindingFlags.Public | BindingFlags.Instance,
            binder: null,
            types: [typeof(WindingMode)],
            modifiers: null);

        Assert.NotNull(carrier);
    }
}
