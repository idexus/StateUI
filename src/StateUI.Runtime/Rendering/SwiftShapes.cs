// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

using System.Numerics;
using Microsoft.Maui.Controls.Shapes;
using Microsoft.Maui.Graphics;

namespace StateUI.Runtime.Rendering;

/// <summary>
/// The geometry transform every shape wears - the Swift side's one
/// <c>ViewTransform</c>, run over the path a shape hands the platform.
/// </summary>
/// <remarks>
/// <para>
/// MAUI declares <c>RenderTransform</c> on <c>Path</c> alone and seals every
/// concrete shape, so the renderer builds each shape as this library's own
/// <c>Shape</c> subclass holding the MAUI original as its GEOMETRY ENGINE:
/// the original answers <c>IShape.PathForBounds</c> - its own arithmetic,
/// stroke insets and aspect fitting, byte for byte - and the wrapper runs
/// that answer through the matrix kept here. One mechanism for all seven
/// shapes, and every platform rasterizes from the same transformed path,
/// which is what makes the transform the same picture everywhere.
/// </para>
/// <para>
/// The property is attached rather than declared per wrapper so a style's
/// setter can name it once for any shape - and every write pokes the
/// handler's <c>Shape</c> mapping, which redraws the platform view without
/// rebuilding it. A walked transform lands here the same way, one matrix per
/// frame, nothing crossing the wire.
/// </para>
/// </remarks>
internal static class SwiftShapes
{
    /// <summary>The matrix a shape's path is run through, or null for the
    /// path as the shape made it.</summary>
    public static readonly BindableProperty GeometryTransformProperty =
        BindableProperty.CreateAttached(
            "GeometryTransform",
            typeof(Matrix3x2?),
            typeof(SwiftShapes),
            null,
            propertyChanged: static (bindable, _, _) => Poke(bindable));

    /// <summary>The attached matrix, or null - the getter MAUI's attached
    /// property contract asks for.</summary>
    public static Matrix3x2? GetGeometryTransform(BindableObject bindable) =>
        (Matrix3x2?)bindable.GetValue(GeometryTransformProperty);

    /// <summary>
    /// Registers the seven wrappers with MAUI's handler collection, all on
    /// the one handler every shape shares - the base
    /// <c>ShapeViewHandler</c>, whose mapper carries the whole
    /// <c>IShapeView</c> surface. The per-shape data rides
    /// <see cref="Poke"/> instead of a per-shape handler.
    /// </summary>
    public static void AddHandlers(IMauiHandlersCollection handlers)
    {
        handlers.AddHandler<SwiftRectangle, Microsoft.Maui.Handlers.ShapeViewHandler>();
        handlers.AddHandler<SwiftRoundRectangle, Microsoft.Maui.Handlers.ShapeViewHandler>();
        handlers.AddHandler<SwiftEllipse, Microsoft.Maui.Handlers.ShapeViewHandler>();
        handlers.AddHandler<SwiftLine, Microsoft.Maui.Handlers.ShapeViewHandler>();
        handlers.AddHandler<SwiftPath, Microsoft.Maui.Handlers.ShapeViewHandler>();
        handlers.AddHandler<SwiftPolygon, Microsoft.Maui.Handlers.ShapeViewHandler>();
        handlers.AddHandler<SwiftPolyline, Microsoft.Maui.Handlers.ShapeViewHandler>();
    }

    /// <summary>The path the platform draws: the MAUI original's own answer
    /// for these bounds - its aspect and stroke inset included - through the
    /// wrapper's matrix.</summary>
    public static PathF PathFor(Shape wrapper, Shape geometry, Microsoft.Maui.Graphics.Rect bounds)
    {
        // The two properties the original reads while making the path; the
        // rest of the tier (fill, stroke, dashes) is the wrapper's and never
        // enters the path.
        geometry.Aspect = wrapper.Aspect;
        geometry.StrokeThickness = wrapper.StrokeThickness;

        PathF path = ((IShape)geometry).PathForBounds(bounds);

        if (GetGeometryTransform(wrapper) is Matrix3x2 matrix) { path.Transform(matrix); }
        return path;
    }

    /// <summary>Redraws the shape: the handler re-reads
    /// <c>IShapeView.Shape</c>, which is what makes a changed matrix or a
    /// changed point show up without the view being rebuilt.</summary>
    public static void Poke(BindableObject bindable) =>
        (bindable as VisualElement)?.Handler?.UpdateValue(nameof(IShapeView.Shape));
}

/// <summary>A Rectangle whose path wears the attached transform.
/// MAUI's own Rectangle is the geometry engine.</summary>
internal sealed class SwiftRectangle : Shape, IShape
{
    private readonly Microsoft.Maui.Controls.Shapes.Rectangle _geometry = new();

    /// <summary>See Rectangle.RadiusX.</summary>
    public static readonly BindableProperty RadiusXProperty = BindableProperty.Create(
        nameof(RadiusX), typeof(double), typeof(SwiftRectangle), 0.0,
        propertyChanged: static (bindable, _, made) =>
        {
            ((SwiftRectangle)bindable)._geometry.RadiusX = (double)made;
            SwiftShapes.Poke(bindable);
        });

    /// <summary>See Rectangle.RadiusY.</summary>
    public static readonly BindableProperty RadiusYProperty = BindableProperty.Create(
        nameof(RadiusY), typeof(double), typeof(SwiftRectangle), 0.0,
        propertyChanged: static (bindable, _, made) =>
        {
            ((SwiftRectangle)bindable)._geometry.RadiusY = (double)made;
            SwiftShapes.Poke(bindable);
        });

    /// <summary>The corner rounding across. MAUI: Rectangle.RadiusX.</summary>
    public double RadiusX
    {
        get => (double)GetValue(RadiusXProperty);
        set => SetValue(RadiusXProperty, value);
    }

    /// <summary>The corner rounding down. MAUI: Rectangle.RadiusY.</summary>
    public double RadiusY
    {
        get => (double)GetValue(RadiusYProperty);
        set => SetValue(RadiusYProperty, value);
    }

    /// <inheritdoc/>
    public override PathF GetPath() => _geometry.GetPath();

    PathF IShape.PathForBounds(Microsoft.Maui.Graphics.Rect bounds) => SwiftShapes.PathFor(this, _geometry, bounds);
}

/// <summary>A RoundRectangle whose path wears the attached transform.</summary>
internal sealed class SwiftRoundRectangle : Shape, IShape
{
    private readonly RoundRectangle _geometry = new();

    /// <summary>See RoundRectangle.CornerRadius.</summary>
    public static readonly BindableProperty CornerRadiusProperty = BindableProperty.Create(
        nameof(CornerRadius), typeof(CornerRadius), typeof(SwiftRoundRectangle), new CornerRadius(),
        propertyChanged: static (bindable, _, made) =>
        {
            ((SwiftRoundRectangle)bindable)._geometry.CornerRadius = (CornerRadius)made;
            SwiftShapes.Poke(bindable);
        });

    /// <summary>Each corner's rounding, named separately.
    /// MAUI: RoundRectangle.CornerRadius.</summary>
    public CornerRadius CornerRadius
    {
        get => (CornerRadius)GetValue(CornerRadiusProperty);
        set => SetValue(CornerRadiusProperty, value);
    }

    /// <inheritdoc/>
    public override PathF GetPath() => _geometry.GetPath();

    PathF IShape.PathForBounds(Microsoft.Maui.Graphics.Rect bounds) => SwiftShapes.PathFor(this, _geometry, bounds);
}

/// <summary>An Ellipse whose path wears the attached transform.</summary>
internal sealed class SwiftEllipse : Shape, IShape
{
    private readonly Microsoft.Maui.Controls.Shapes.Ellipse _geometry = new();

    /// <inheritdoc/>
    public override PathF GetPath() => _geometry.GetPath();

    PathF IShape.PathForBounds(Microsoft.Maui.Graphics.Rect bounds) => SwiftShapes.PathFor(this, _geometry, bounds);
}

/// <summary>A Line whose path wears the attached transform.</summary>
internal sealed class SwiftLine : Shape, IShape
{
    private readonly Line _geometry = new();

    /// <summary>See Line.X1.</summary>
    public static readonly BindableProperty X1Property = BindableProperty.Create(
        nameof(X1), typeof(double), typeof(SwiftLine), 0.0,
        propertyChanged: static (bindable, _, made) =>
        {
            ((SwiftLine)bindable)._geometry.X1 = (double)made;
            SwiftShapes.Poke(bindable);
        });

    /// <summary>See Line.Y1.</summary>
    public static readonly BindableProperty Y1Property = BindableProperty.Create(
        nameof(Y1), typeof(double), typeof(SwiftLine), 0.0,
        propertyChanged: static (bindable, _, made) =>
        {
            ((SwiftLine)bindable)._geometry.Y1 = (double)made;
            SwiftShapes.Poke(bindable);
        });

    /// <summary>See Line.X2.</summary>
    public static readonly BindableProperty X2Property = BindableProperty.Create(
        nameof(X2), typeof(double), typeof(SwiftLine), 0.0,
        propertyChanged: static (bindable, _, made) =>
        {
            ((SwiftLine)bindable)._geometry.X2 = (double)made;
            SwiftShapes.Poke(bindable);
        });

    /// <summary>See Line.Y2.</summary>
    public static readonly BindableProperty Y2Property = BindableProperty.Create(
        nameof(Y2), typeof(double), typeof(SwiftLine), 0.0,
        propertyChanged: static (bindable, _, made) =>
        {
            ((SwiftLine)bindable)._geometry.Y2 = (double)made;
            SwiftShapes.Poke(bindable);
        });

    /// <summary>Where the line starts, across. MAUI: Line.X1.</summary>
    public double X1 { get => (double)GetValue(X1Property); set => SetValue(X1Property, value); }

    /// <summary>Where the line starts, down. MAUI: Line.Y1.</summary>
    public double Y1 { get => (double)GetValue(Y1Property); set => SetValue(Y1Property, value); }

    /// <summary>Where the line ends, across. MAUI: Line.X2.</summary>
    public double X2 { get => (double)GetValue(X2Property); set => SetValue(X2Property, value); }

    /// <summary>Where the line ends, down. MAUI: Line.Y2.</summary>
    public double Y2 { get => (double)GetValue(Y2Property); set => SetValue(Y2Property, value); }

    /// <inheritdoc/>
    public override PathF GetPath() => _geometry.GetPath();

    PathF IShape.PathForBounds(Microsoft.Maui.Graphics.Rect bounds) => SwiftShapes.PathFor(this, _geometry, bounds);
}

/// <summary>A Path whose path wears the attached transform - through the one
/// mechanism every shape shares, rather than MAUI's own
/// <c>RenderTransform</c>, so there is one and not two.</summary>
internal sealed class SwiftPath : Shape, IShape
{
    private readonly Microsoft.Maui.Controls.Shapes.Path _geometry = new();

    /// <summary>See Path.Data.</summary>
    public static readonly BindableProperty DataProperty = BindableProperty.Create(
        nameof(Data), typeof(Geometry), typeof(SwiftPath), null,
        propertyChanged: static (bindable, _, made) =>
        {
            ((SwiftPath)bindable)._geometry.Data = (Geometry?)made;
            SwiftShapes.Poke(bindable);
        });

    /// <summary>The outline the path draws. MAUI: Path.Data.</summary>
    public Geometry? Data
    {
        get => (Geometry?)GetValue(DataProperty);
        set => SetValue(DataProperty, value);
    }

    /// <inheritdoc/>
    public override PathF GetPath() => _geometry.GetPath();

    PathF IShape.PathForBounds(Microsoft.Maui.Graphics.Rect bounds) => SwiftShapes.PathFor(this, _geometry, bounds);
}

/// <summary>A Polygon whose path wears the attached transform.</summary>
internal sealed class SwiftPolygon : Shape, IShape
{
    private readonly Polygon _geometry = new();

    /// <summary>See Polygon.Points.</summary>
    public static readonly BindableProperty PointsProperty = BindableProperty.Create(
        nameof(Points), typeof(PointCollection), typeof(SwiftPolygon), null,
        propertyChanged: static (bindable, _, made) =>
        {
            ((SwiftPolygon)bindable)._geometry.Points = (PointCollection?)made ?? [];
            SwiftShapes.Poke(bindable);
        });

    /// <summary>See Polygon.FillRule.</summary>
    public static readonly BindableProperty FillRuleProperty = BindableProperty.Create(
        nameof(FillRule), typeof(FillRule), typeof(SwiftPolygon), FillRule.EvenOdd,
        propertyChanged: static (bindable, _, made) =>
        {
            ((SwiftPolygon)bindable)._geometry.FillRule = (FillRule)made;
            SwiftShapes.Poke(bindable);
        });

    /// <summary>The corners, in order; the last closes back to the first.
    /// MAUI: Polygon.Points.</summary>
    public PointCollection? Points
    {
        get => (PointCollection?)GetValue(PointsProperty);
        set => SetValue(PointsProperty, value);
    }

    /// <summary>Which crossings count as inside. MAUI: Polygon.FillRule.</summary>
    public FillRule FillRule
    {
        get => (FillRule)GetValue(FillRuleProperty);
        set => SetValue(FillRuleProperty, value);
    }

    /// <inheritdoc/>
    public override PathF GetPath() => _geometry.GetPath();

    PathF IShape.PathForBounds(Microsoft.Maui.Graphics.Rect bounds) => SwiftShapes.PathFor(this, _geometry, bounds);
}

/// <summary>A Polyline whose path wears the attached transform.</summary>
internal sealed class SwiftPolyline : Shape, IShape
{
    private readonly Polyline _geometry = new();

    /// <summary>See Polyline.Points.</summary>
    public static readonly BindableProperty PointsProperty = BindableProperty.Create(
        nameof(Points), typeof(PointCollection), typeof(SwiftPolyline), null,
        propertyChanged: static (bindable, _, made) =>
        {
            ((SwiftPolyline)bindable)._geometry.Points = (PointCollection?)made ?? [];
            SwiftShapes.Poke(bindable);
        });

    /// <summary>See Polyline.FillRule.</summary>
    public static readonly BindableProperty FillRuleProperty = BindableProperty.Create(
        nameof(FillRule), typeof(FillRule), typeof(SwiftPolyline), FillRule.EvenOdd,
        propertyChanged: static (bindable, _, made) =>
        {
            ((SwiftPolyline)bindable)._geometry.FillRule = (FillRule)made;
            SwiftShapes.Poke(bindable);
        });

    /// <summary>The corners, in order, left open. MAUI: Polyline.Points.</summary>
    public PointCollection? Points
    {
        get => (PointCollection?)GetValue(PointsProperty);
        set => SetValue(PointsProperty, value);
    }

    /// <summary>Which crossings count as inside. MAUI: Polyline.FillRule.</summary>
    public FillRule FillRule
    {
        get => (FillRule)GetValue(FillRuleProperty);
        set => SetValue(FillRuleProperty, value);
    }

    /// <inheritdoc/>
    public override PathF GetPath() => _geometry.GetPath();

    PathF IShape.PathForBounds(Microsoft.Maui.Graphics.Rect bounds) => SwiftShapes.PathFor(this, _geometry, bounds);
}
