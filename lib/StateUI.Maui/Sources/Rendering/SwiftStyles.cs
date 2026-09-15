// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

using System.Numerics;
using Microsoft.Maui.Controls.Shapes;
using Microsoft.Maui.Layouts;
using StateUI.Maui.Protocol;

// MAUI's shape, not System.IO's - the two are both called Path and both in
// scope, and only one of them can be styled.
using Path = Microsoft.Maui.Controls.Shapes.Path;

namespace StateUI.Maui.Rendering;

/// <summary>
/// What a property NAME stands for - the table a visual state's setters and a
/// walked property's target are both resolved through.
/// </summary>
/// <remarks>
/// <para>
/// There is no <c>Style</c> here and no dictionary: a style is a bag of the
/// property values the Swift side already writes as modifiers, so it is
/// resolved THERE, into the controls it applies to, and what reaches this side
/// is a control with every value on it. See the header of Views/Style.swift.
/// </para>
/// <para>
/// What this file holds is the one thing a setter needs and a control does
/// not: the <see cref="BindableProperty"/> a name stands for, as an OBJECT. The
/// renderer assigns <c>label.TextColor</c> directly; a <see cref="Setter"/>
/// inside a <see cref="VisualState"/> has to name the property, and so does a
/// walk - which is why those two share this table and why a property
/// becomes walkable at the moment it becomes settable in a state.
/// </para>
/// <para>
/// The table is written out by hand rather than found by reflection:
/// <c>{Name}Property</c> lookup is what MAUI's own
/// <c>BindablePropertyConverter</c> does, and it does not survive trimming.
/// It mirrors the <c>Reconcile…</c> methods one for one - the same names, per
/// control - and a test insists on that: every property a control's fixture
/// sets must resolve here, or a state naming it would silently do nothing.
/// </para>
/// <para>
/// A themed colour costs this table nothing, though a Setter holds values, not
/// bindings, and MAUI's <c>AppThemeBinding</c> is internal: a colour picks its
/// half on the Swift side as it is written onto a node, so a setter holds one
/// colour like every other value and a theme change is an ordinary render.
/// See Types/Color.swift.
/// </para>
/// </remarks>
internal static class SwiftStyles
{
    /// <summary>
    /// The states a control describes, grouped as the VisualStateManager wants
    /// them.
    /// </summary>
    /// <remarks>
    /// Called from <c>StateUIRenderer.ApplyVisualStates</c>, which is the one
    /// caller: whether the states were written on the control or came from its
    /// style, the Swift side has already merged them into one arranged list.
    /// </remarks>
    internal static VisualStateGroupList BuildStates(
        HostNodeType targetType,
        string typeName,
        List<HostPatch> states,
        Dictionary<string, List<(HostPropKey Key, BindableProperty Property, object Value)>>? travelling = null)
    {
        var groups = new VisualStateGroupList();

        foreach (HostPatch node in states)
        {
            // A visual state's group and its name are NAMES: they ride the
            // session dictionary, so they read back through GetName. Read as
            // strings they would both answer null, and every state would land
            // in CommonStates under the empty name - which is to say every
            // state would be the same state.
            string name = node.GetName(HostProp.Group) ?? "CommonStates";
            VisualStateGroup? group = groups.FirstOrDefault(candidate => candidate.Name == name);

            if (group is null)
            {
                group = new VisualStateGroup { Name = name };
                groups.Add(group);
            }

            var state = new VisualState { Name = node.GetName(HostProp.Name) ?? "" };

            foreach (HostPatch child in node.Children ?? [])
            {
                if (child.Type == HostNodeType.Setters)
                {
                    List<(HostPropKey Key, BindableProperty Property, object Value)>? moves = null;

                    if (travelling is not null)
                    {
                        moves = [];
                        travelling[state.Name] = moves;
                    }

                    AddSetters(state.Setters, targetType, typeName, child, moves);
                }
            }

            group.States.Add(state);
        }

        return groups;
    }

    /// <summary>
    /// One setter per property the node carries that the target type has.
    /// </summary>
    /// <remarks>
    /// <para>
    /// In a fixed order, because a Setter list is applied in order and a few
    /// properties care: a Slider clamps its Value into the range as it is set,
    /// so the range has to arrive first. Sorting by name almost says that -
    /// Maximum and Minimum sort before Value - but not for a DatePicker, where
    /// "date" sorts before "maximumDate", so a date set in a state would be
    /// clamped against the DEFAULT range before its own bounds ran. The bounds
    /// are therefore ordered out in front explicitly, and the rest stays sorted
    /// by name.
    /// </para>
    /// <para>
    /// The order is by NAME, so a member's spelling is what it is read from -
    /// derived once per member by <see cref="TokenNames{TToken}"/> rather
    /// than per setter. Both bags go in: a registered control's own properties
    /// are as settable in a state as a Label's, and they sort among them.
    /// </para>
    /// </remarks>
    private static void AddSetters(
        IList<Setter> setters,
        HostNodeType targetType,
        string typeName,
        HostPatch node,
        IList<(HostPropKey Key, BindableProperty Property, object Value)>? travelling = null)
    {
        List<(HostPropKey Key, string Name)> keys = [];

        foreach (HostProp prop in node.Props?.Keys ?? Enumerable.Empty<HostProp>())
        {
            string spelling = TokenNames<HostProp>.Spelling(prop);
            keys.Add((HostPropKey.Of(prop, spelling), spelling));
        }

        foreach (string name in node.OwnProps?.Keys ?? Enumerable.Empty<string>())
        {
            keys.Add((HostPropKey.Own(name), name));
        }

        foreach ((HostPropKey key, string _) in keys
            .OrderBy(entry => entry.Name.StartsWith("min", StringComparison.Ordinal)
                || entry.Name.StartsWith("max", StringComparison.Ordinal) ? 0 : 1)
            .ThenBy(entry => entry.Name, StringComparer.Ordinal))
        {
            if (Property(targetType, typeName, key) is not BindableProperty property)
            {
                continue;
            }

            if (Value(property, node, key) is not object value)
            {
                continue;
            }

            // A VALUE WITH A HALF-WAY IS NOT A SETTER. MAUI applies a setter by
            // assigning, which is the one thing in this library that cannot be
            // animated from the outside - so a colour, an opacity, a size or a
            // set of edges is taken OUT of the state and carried by the walker
            // instead, at whatever the control's own motion says. A control
            // whose motion is none gets exactly what a setter gave it.
            //
            // A PLACEMENT stays a setter: where a child sits belongs to its
            // layout, and two things carrying it would fight.
            if (travelling is not null
                && MotionProperty.ShapeOf(value) is MotionValue shape
                && shape != MotionValue.Bounds)
            {
                travelling.Add((key, property, value));
                continue;
            }

            setters.Add(new Setter { Property = property, Value = value });
        }
    }

    // ---- What a value becomes ----------------------------------------------

    /// <summary>
    /// The setter's value, in the type the property takes.
    /// </summary>
    /// <remarks>
    /// Driven by <see cref="BindableProperty.ReturnType"/> rather than by the
    /// property's name, so the accessors in <see cref="SwiftValues"/> are reached
    /// once each instead of once per property. A type not listed here produces no
    /// setter, which is the same answer an unrecognized property gets everywhere
    /// else: ignored rather than guessed at.
    /// <para>
    /// Internal rather than private because a transition reads its target value
    /// through here as well - see <see cref="DescribedMotion"/>. The same table
    /// answers both questions, which is what keeps a property walkable the
    /// moment it becomes styleable.
    /// </para>
    /// </remarks>
    internal static object? Value(BindableProperty property, HostPatch node, HostPropKey key)
    {
        // Unwrapped, because MAUI 10 declares some of these nullable -
        // DatePicker.Date is a DateTime? - and a nullable type is equal to
        // no bare one: without looking through the wrapper, every date setter
        // in a style is silently dropped.
        Type type = Nullable.GetUnderlyingType(property.ReturnType) ?? property.ReturnType;

        // A solid brush is a colour - what a Brush-typed background says for one.
        if (type == typeof(Color)) { return node.GetColor(key) ?? (node.GetBrush(key) as SolidColorBrush)?.Color; }
        if (type == typeof(Brush)) { return node.GetBrush(key); }

        if (type == typeof(double)) { return node.GetNumber(key); }
        if (type == typeof(int)) { return node.GetInt(key); }
        if (type == typeof(bool)) { return node.GetBool(key); }
        if (type == typeof(bool?)) { return node.GetBool(key); }

        // Text OR a name: MAUI types both as a string, and the wire does not -
        // a caption is text someone wrote, while a font family and a radio
        // group are NAMES and ride the session's dictionary. One arm reads
        // both because the property's type is all there is to go on here.
        if (type == typeof(string)) { return node.GetString(key) ?? node.GetName(key); }

        // A number MAUI declares as a float where everything else is a double.
        if (type == typeof(float)) { return node.GetNumber(key) is double single ? (float)single : null; }

        if (type == typeof(Thickness)) { return node.GetThickness(key); }
        if (type == typeof(SafeAreaEdges)) { return node.GetSafeAreaEdges(key); }
        if (type == typeof(Rect)) { return node.GetRect(key); }
        if (type == typeof(CornerRadius)) { return node.GetCornerRadius(key); }
        if (type == typeof(LayoutOptions)) { return node.GetLayoutOptions(key); }
        if (type == typeof(FlowDirection)) { return node.GetFlowDirection(key); }
        if (type == typeof(SemanticHeadingLevel)) { return node.GetSemanticHeadingLevel(key); }
        if (type == typeof(Matrix3x2)) { return node.GetGeometryTransform(key); }
        if (type == typeof(Microsoft.Maui.Controls.Maps.PinType)) { return node.GetPinType(key); }
        if (type == typeof(TextAlignment)) { return node.GetTextAlignment(key); }
        if (type == typeof(FontAttributes)) { return node.GetFontAttributes(key); }
        if (type == typeof(TextDecorations)) { return node.GetTextDecorations(key); }
        if (type == typeof(TextTransform)) { return node.GetTextTransform(key); }
        if (type == typeof(LineBreakMode)) { return node.GetLineBreakMode(key); }
        if (type == typeof(Keyboard)) { return node.GetKeyboard(key); }
        if (type == typeof(ReturnType)) { return node.GetReturnType(key); }
        // Two Booleans MAUI spells as a choice of two.
        if (type == typeof(ClearButtonVisibility))
        {
            return node.GetBool(key) is bool clears
                ? clears ? ClearButtonVisibility.WhileEditing : ClearButtonVisibility.Never
                : null;
        }

        if (type == typeof(EditorAutoSizeOption))
        {
            return node.GetBool(key) is bool grows
                ? grows ? EditorAutoSizeOption.TextChanges : EditorAutoSizeOption.Disabled
                : null;
        }

        if (type == typeof(ScrollBarVisibility)) { return node.GetScrollBarVisibility(key); }
        if (type == typeof(ScrollOrientation)) { return node.GetScrollOrientation(key); }
        if (type == typeof(Aspect)) { return node.GetAspect(key); }
        if (type == typeof(DateTime)) { return node.GetDate(key); }
        if (type == typeof(TimeSpan)) { return node.GetTime(key); }

        // RadioButton.Content, the one property here MAUI types as object -
        // what crosses is the caption.
        if (type == typeof(object)) { return node.GetString(key); }

        if (type == typeof(AbsoluteLayoutFlags)) { return node.GetAbsoluteLayoutFlags(key); }

        // What a shape is drawn with, and what it is.
        if (type == typeof(Stretch)) { return node.GetShapeAspect(key); }
        if (type == typeof(PenLineCap)) { return node.GetPenLineCap(key); }
        if (type == typeof(PenLineJoin)) { return node.GetPenLineJoin(key); }
        if (type == typeof(FillRule)) { return node.GetFillRule(key); }
        if (type == typeof(DoubleCollection)) { return node.GetDoubleCollection(key); }
        if (type == typeof(PointCollection)) { return node.GetPoints(key); }
        if (type == typeof(Geometry)) { return node.GetGeometry(key); }
        if (type == typeof(IDrawable)) { return node.GetDrawable(key); }

        if (type == typeof(IndicatorShape)) { return node.GetIndicatorShape(key); }

        if (type == typeof(IShape)) { return node.GetStrokeShape(key); }

        if (type == typeof(RowDefinitionCollection)) { return node.GetRowDefinitions(key); }
        if (type == typeof(ColumnDefinitionCollection)) { return node.GetColumnDefinitions(key); }

        if (type == typeof(ImageSource)) { return node.GetImageSource(key); }
        if (type == typeof(Button.ButtonContentLayout.ImagePosition)) { return node.GetIconPosition(key); }
        if (type == typeof(WebViewSource)) { return node.GetWebViewSource(key); }
        if (type == typeof(Microsoft.Maui.Maps.MapType)) { return node.GetMapType(key); }

        return null;
    }

    // ---- The table ---------------------------------------------------------

    /// <summary>
    /// The BindableProperty a key stands for on a target type - THE ONE PLACE
    /// the two vocabularies meet.
    /// </summary>
    /// <remarks>
    /// <para>
    /// The library's tiers first, on members: two switches over dense little
    /// enums, which the compiler turns into a jump table each. That is what
    /// keeps a table this wide - fifty-two types, up to twenty-three properties
    /// apiece - to two indexed reads per lookup.
    /// </para>
    /// <para>
    /// The registry last, and it is the one door here that takes STRINGS - the
    /// only one that can, an application's control being
    /// <see cref="HostNodeType.None"/> with property names of its own
    /// invention. A key with no name never reaches it, which is every key the
    /// renderer itself asks with.
    /// </para>
    /// </remarks>
    /// <param name="targetType">The control's type, as the table switches on it.</param>
    /// <param name="typeName">The same, spelled - what the registry is asked by.</param>
    /// <param name="key">The property, in whichever vocabulary it belongs to.</param>
    /// <param name="target">
    /// The control itself where one is at hand: a Menu is MAUI's
    /// <see cref="MenuBarItem"/> on the menu bar and a <see cref="MenuFlyoutSubItem"/>
    /// anywhere else, and the two declare their properties separately.
    /// </param>
    internal static BindableProperty? Property(
        HostNodeType targetType, string typeName, HostPropKey key, BindableObject? target = null)
    {
        return Shared(key.Prop)
            ?? Own(targetType, key.Prop, target)
            ?? (key.Name is string name ? StateUIControls.PropertyOf(typeName, name) : null);
    }

    /// <summary>
    /// The properties MAUI declares once, high up, and every control inherits -
    /// the same tiers the Swift protocols mirror.
    /// </summary>
    private static BindableProperty? Shared(HostProp name)
    {
        return name switch
        {
            // VisualElement
            HostProp.IsVisible => VisualElement.IsVisibleProperty,
            HostProp.IsEnabled => VisualElement.IsEnabledProperty,
            HostProp.IgnoresInput => ComposedProperties.IgnoresInputProperty,
            HostProp.LetsInputThrough => ComposedProperties.LetsInputThroughProperty,
            HostProp.PanXChannel => StateUIRenderer.PanXChannelProperty,
            HostProp.PanYChannel => StateUIRenderer.PanYChannelProperty,
            HostProp.LayoutDirection => VisualElement.FlowDirectionProperty,

            // What the view says about itself, rather than how it is drawn.
            // Element declares the id and SemanticProperties the three the
            // reader hears; all four are cleared back the ordinary way, so a
            // description written under an `if` goes when the `if` does.
            HostProp.AccessibilityIdentifier => Element.AutomationIdProperty,
            HostProp.AccessibilityLabel => SemanticProperties.DescriptionProperty,
            HostProp.AccessibilityHint => SemanticProperties.HintProperty,
            HostProp.AccessibilityHeadingLevel => SemanticProperties.HeadingLevelProperty,
            HostProp.IsAccessibilityHidden => ComposedProperties.IsAccessibilityHiddenProperty,
            HostProp.AutomationExcludedWithChildren => AutomationProperties.ExcludedWithChildrenProperty,
            HostProp.Opacity => VisualElement.OpacityProperty,
            HostProp.Background => VisualElement.BackgroundColorProperty,
            HostProp.Tint => ComposedProperties.TintProperty,
            HostProp.Width => VisualElement.WidthRequestProperty,
            HostProp.Height => VisualElement.HeightRequestProperty,
            HostProp.MinimumWidth => VisualElement.MinimumWidthRequestProperty,
            HostProp.MinimumHeight => VisualElement.MinimumHeightRequestProperty,
            HostProp.MaximumWidth => VisualElement.MaximumWidthRequestProperty,
            HostProp.MaximumHeight => VisualElement.MaximumHeightRequestProperty,
            HostProp.Rotation => VisualElement.RotationProperty,
            HostProp.RotationX => VisualElement.RotationXProperty,
            HostProp.RotationY => VisualElement.RotationYProperty,
            HostProp.Scale => VisualElement.ScaleProperty,
            HostProp.ScaleX => VisualElement.ScaleXProperty,
            HostProp.ScaleY => VisualElement.ScaleYProperty,
            HostProp.TranslationX => VisualElement.TranslationXProperty,
            HostProp.TranslationY => VisualElement.TranslationYProperty,
            HostProp.PivotX => VisualElement.AnchorXProperty,
            HostProp.PivotY => VisualElement.AnchorYProperty,
            HostProp.ZIndex => VisualElement.ZIndexProperty,

            // View
            HostProp.Margin => View.MarginProperty,
            HostProp.HorizontalAlignment => View.HorizontalOptionsProperty,
            HostProp.VerticalAlignment => View.VerticalOptionsProperty,

            // Where a view sits in a Grid - attached, and written on the child.
            HostProp.GridRow => Grid.RowProperty,
            HostProp.GridColumn => Grid.ColumnProperty,
            HostProp.GridRowSpan => Grid.RowSpanProperty,
            HostProp.GridColumnSpan => Grid.ColumnSpanProperty,

            // And in an AbsoluteLayout, which reads a rectangle and which of
            // its numbers are fractions.
            HostProp.AbsoluteLayoutBounds => AbsoluteLayout.LayoutBoundsProperty,
            HostProp.AbsoluteLayoutProportions => AbsoluteLayout.LayoutFlagsProperty,

            _ => null,
        };
    }

    /// <summary>
    /// What a control declares itself. One arm per <c>Reconcile…</c> method, with
    /// the same names in it.
    /// </summary>
    private static BindableProperty? Own(HostNodeType targetType, HostProp name, BindableObject? target)
    {
        return targetType switch
        {
            // A page is not a style target - a Style in this library is
            // written against a control - but it stops describing properties
            // like anything else, and a property with no name here is one that
            // could never be CLEARED off it. See HostPatch.Cleared.
            HostNodeType.Page => PageProperty(name),

            HostNodeType.NavigationStack => PageProperty(name) ?? name switch
            {
                HostProp.BarBackgroundColor => NavigationPage.BarBackgroundColorProperty,
                HostProp.BarForegroundColor => NavigationPage.BarTextColorProperty,
                _ => null,
            },

            HostNodeType.TabbedView => PageProperty(name) ?? name switch
            {
                HostProp.BarBackgroundColor => TabbedPage.BarBackgroundColorProperty,
                _ => null,
            },

            HostNodeType.SplitView => PageProperty(name) ?? name switch
            {
                HostProp.IsSidebarVisible => FlyoutPage.IsPresentedProperty,
                _ => null,
            },

            HostNodeType.Window => name switch
            {
                HostProp.Title => Window.TitleProperty,
                HostProp.X => Window.XProperty,
                HostProp.Y => Window.YProperty,
                HostProp.Width => Window.WidthProperty,
                HostProp.Height => Window.HeightProperty,
                HostProp.IsMaximizable => Window.IsMaximizableProperty,
                HostProp.IsMinimizable => Window.IsMinimizableProperty,
                HostProp.MinimumWidth => Window.MinimumWidthProperty,
                HostProp.MinimumHeight => Window.MinimumHeightProperty,
                HostProp.MaximumWidth => Window.MaximumWidthProperty,
                HostProp.MaximumHeight => Window.MaximumHeightProperty,
                _ => null,
            },

            // Order and Priority are plain CLR properties on MAUI's
            // ToolbarItem, so there is no default to put back and no name to
            // do it by: Swift keeps them in Prop.notCleared and sends the item
            // again instead.
            HostNodeType.ToolbarItem => MenuItemProperty(name),

            // One Menu, two MAUI classes: MenuBarItem on the bar and
            // MenuFlyoutSubItem inside another menu, each declaring its own.
            HostNodeType.Menu => target is MenuBarItem ? MenuBarProperty(name) : MenuItemProperty(name),

            HostNodeType.MenuItem => MenuItemProperty(name),

            // A SwipeItem is a MenuItem too, which is why it needs no arm of
            // its own beyond that.
            HostNodeType.SwipeAction => MenuItemProperty(name),

            // Not a View either - it is the collection a SwipeView keeps its
            // items in. `side` is not MAUI's at all: it says WHICH of the four
            // collections these are, which is a decision the renderer makes
            // rather than a value it writes, so Swift keeps it in notCleared.
            HostNodeType.SwipeActions => name switch
            {
                HostProp.Mode => SwipeItems.ModeProperty,
                HostProp.SwipeBehaviorOnInvoked => SwipeItems.SwipeBehaviorOnInvokedProperty,
                _ => null,
            },

            // One run of a formatted string. MAUI declares the text and the
            // font on Span itself rather than through the interfaces a Label
            // wears, so none of it is answered by Shared.
            HostNodeType.Span => name switch
            {
                HostProp.Text => Span.TextProperty,
                HostProp.TextColor => Span.TextColorProperty,
                HostProp.CharacterSpacing => Span.CharacterSpacingProperty,
                HostProp.TextDecorations => Span.TextDecorationsProperty,
                HostProp.LineHeight => Span.LineHeightProperty,
                HostProp.FontSize => Span.FontSizeProperty,
                HostProp.FontFamily => Span.FontFamilyProperty,
                HostProp.FontAttributes => Span.FontAttributesProperty,
                HostProp.FontAutoScalingEnabled => Span.FontAutoScalingEnabledProperty,
                _ => null,
            },

            // One marker on a map.
            HostNodeType.Pin => name switch
            {
                HostProp.Label => Microsoft.Maui.Controls.Maps.Pin.LabelProperty,
                HostProp.Address => Microsoft.Maui.Controls.Maps.Pin.AddressProperty,
                HostProp.Type => Microsoft.Maui.Controls.Maps.Pin.TypeProperty,
                HostProp.Location => Microsoft.Maui.Controls.Maps.Pin.LocationProperty,
                _ => null,
            },

            HostNodeType.Label => name switch
            {
                HostProp.Text => Label.TextProperty,
                HostProp.TextColor => Label.TextColorProperty,
                HostProp.CharacterSpacing => Label.CharacterSpacingProperty,
                HostProp.TextCase => Label.TextTransformProperty,
                HostProp.HorizontalTextAlignment => Label.HorizontalTextAlignmentProperty,
                HostProp.VerticalTextAlignment => Label.VerticalTextAlignmentProperty,
                HostProp.LineBreak => Label.LineBreakModeProperty,
                HostProp.LineHeight => Label.LineHeightProperty,
                HostProp.MaximumLines => Label.MaxLinesProperty,
                HostProp.TextDecorations => Label.TextDecorationsProperty,
                HostProp.Padding => Label.PaddingProperty,
                HostProp.FontSize => Label.FontSizeProperty,
                HostProp.FontFamily => Label.FontFamilyProperty,
                HostProp.FontAttributes => Label.FontAttributesProperty,
                HostProp.FontAutoScalingEnabled => Label.FontAutoScalingEnabledProperty,
                _ => null,
            },

            HostNodeType.Button => name switch
            {
                HostProp.Text => Button.TextProperty,
                HostProp.TextColor => Button.TextColorProperty,
                HostProp.CharacterSpacing => Button.CharacterSpacingProperty,
                HostProp.TextCase => Button.TextTransformProperty,
                HostProp.BorderColor => Button.BorderColorProperty,
                HostProp.BorderWidth => Button.BorderWidthProperty,
                HostProp.CornerRadius => Button.CornerRadiusProperty,
                HostProp.LineBreak => Button.LineBreakModeProperty,
                HostProp.Icon => Button.ImageSourceProperty,
                HostProp.IconPosition => ComposedProperties.IconPositionProperty,
                HostProp.IconSpacing => ComposedProperties.IconSpacingProperty,
                HostProp.Padding => Button.PaddingProperty,
                HostProp.FontSize => Button.FontSizeProperty,
                HostProp.FontFamily => Button.FontFamilyProperty,
                HostProp.FontAttributes => Button.FontAttributesProperty,
                HostProp.FontAutoScalingEnabled => Button.FontAutoScalingEnabledProperty,
                _ => null,
            },

            HostNodeType.TextField => name switch
            {
                HostProp.Text => Entry.TextProperty,
                HostProp.TextColor => Entry.TextColorProperty,
                HostProp.CharacterSpacing => Entry.CharacterSpacingProperty,
                HostProp.TextCase => Entry.TextTransformProperty,
                HostProp.Placeholder => Entry.PlaceholderProperty,
                HostProp.PlaceholderColor => Entry.PlaceholderColorProperty,
                HostProp.IsPassword => Entry.IsPasswordProperty,
                HostProp.IsReadOnly => Entry.IsReadOnlyProperty,
                HostProp.CursorPosition => InputView.CursorPositionProperty,
                HostProp.SelectionLength => InputView.SelectionLengthProperty,
                HostProp.IsSpellCheckEnabled => InputView.IsSpellCheckEnabledProperty,
                HostProp.IsTextPredictionEnabled => InputView.IsTextPredictionEnabledProperty,
                HostProp.InputPurpose => Entry.KeyboardProperty,
                HostProp.MaximumLength => StateUIRenderer.MaxLengthProperty,
                HostProp.ReturnKey => Entry.ReturnTypeProperty,
                HostProp.ShowsClearButton => Entry.ClearButtonVisibilityProperty,
                HostProp.HorizontalTextAlignment => Entry.HorizontalTextAlignmentProperty,
                HostProp.VerticalTextAlignment => Entry.VerticalTextAlignmentProperty,
                HostProp.FontSize => Entry.FontSizeProperty,
                HostProp.FontFamily => Entry.FontFamilyProperty,
                HostProp.FontAttributes => Entry.FontAttributesProperty,
                HostProp.FontAutoScalingEnabled => Entry.FontAutoScalingEnabledProperty,
                _ => null,
            },

            HostNodeType.TextEditor => name switch
            {
                HostProp.Text => Editor.TextProperty,
                HostProp.TextColor => Editor.TextColorProperty,
                HostProp.CharacterSpacing => Editor.CharacterSpacingProperty,
                HostProp.TextCase => Editor.TextTransformProperty,
                HostProp.Placeholder => Editor.PlaceholderProperty,
                HostProp.PlaceholderColor => Editor.PlaceholderColorProperty,
                HostProp.IsReadOnly => Editor.IsReadOnlyProperty,
                HostProp.CursorPosition => InputView.CursorPositionProperty,
                HostProp.SelectionLength => InputView.SelectionLengthProperty,
                HostProp.IsSpellCheckEnabled => InputView.IsSpellCheckEnabledProperty,
                HostProp.IsTextPredictionEnabled => InputView.IsTextPredictionEnabledProperty,
                HostProp.MaximumLength => StateUIRenderer.MaxLengthProperty,
                HostProp.InputPurpose => Editor.KeyboardProperty,
                HostProp.GrowsWithText => Editor.AutoSizeProperty,
                HostProp.HorizontalTextAlignment => Editor.HorizontalTextAlignmentProperty,
                HostProp.VerticalTextAlignment => Editor.VerticalTextAlignmentProperty,
                HostProp.FontSize => Editor.FontSizeProperty,
                HostProp.FontFamily => Editor.FontFamilyProperty,
                HostProp.FontAttributes => Editor.FontAttributesProperty,
                HostProp.FontAutoScalingEnabled => Editor.FontAutoScalingEnabledProperty,
                _ => null,
            },

            HostNodeType.Picker => name switch
            {
                HostProp.SelectedIndex => Picker.SelectedIndexProperty,
                HostProp.IsOpen => Picker.IsOpenProperty,
                HostProp.Title => Picker.TitleProperty,
                HostProp.TextColor => Picker.TextColorProperty,
                HostProp.CharacterSpacing => Picker.CharacterSpacingProperty,
                HostProp.HorizontalTextAlignment => Picker.HorizontalTextAlignmentProperty,
                HostProp.VerticalTextAlignment => Picker.VerticalTextAlignmentProperty,
                HostProp.FontSize => Picker.FontSizeProperty,
                HostProp.FontFamily => Picker.FontFamilyProperty,
                HostProp.FontAttributes => Picker.FontAttributesProperty,
                HostProp.FontAutoScalingEnabled => Picker.FontAutoScalingEnabledProperty,
                _ => null,
            },

            HostNodeType.DatePicker => name switch
            {
                HostProp.Date => DatePicker.DateProperty,
                HostProp.IsOpen => DatePicker.IsOpenProperty,
                HostProp.MinimumDate => DatePicker.MinimumDateProperty,
                HostProp.MaximumDate => DatePicker.MaximumDateProperty,
                HostProp.Format => DatePicker.FormatProperty,
                HostProp.TextColor => DatePicker.TextColorProperty,
                HostProp.CharacterSpacing => DatePicker.CharacterSpacingProperty,
                HostProp.FontSize => DatePicker.FontSizeProperty,
                HostProp.FontFamily => DatePicker.FontFamilyProperty,
                HostProp.FontAttributes => DatePicker.FontAttributesProperty,
                HostProp.FontAutoScalingEnabled => DatePicker.FontAutoScalingEnabledProperty,
                _ => null,
            },

            HostNodeType.TimePicker => name switch
            {
                HostProp.Time => TimePicker.TimeProperty,
                HostProp.IsOpen => TimePicker.IsOpenProperty,
                HostProp.Format => TimePicker.FormatProperty,
                HostProp.TextColor => TimePicker.TextColorProperty,
                HostProp.CharacterSpacing => TimePicker.CharacterSpacingProperty,
                HostProp.FontSize => TimePicker.FontSizeProperty,
                HostProp.FontFamily => TimePicker.FontFamilyProperty,
                HostProp.FontAttributes => TimePicker.FontAttributesProperty,
                HostProp.FontAutoScalingEnabled => TimePicker.FontAutoScalingEnabledProperty,
                _ => null,
            },

            HostNodeType.Switch => name switch
            {
                HostProp.IsOn => Switch.IsToggledProperty,
                _ => null,
            },

            HostNodeType.CheckBox => name switch
            {
                HostProp.IsOn => CheckBox.IsCheckedProperty,
                _ => null,
            },

            HostNodeType.RadioButton => name switch
            {
                HostProp.Text => RadioButton.ContentProperty,
                HostProp.IsOn => RadioButton.IsCheckedProperty,
                HostProp.GroupName => RadioButton.GroupNameProperty,
                HostProp.TextColor => RadioButton.TextColorProperty,
                HostProp.CharacterSpacing => RadioButton.CharacterSpacingProperty,
                HostProp.TextCase => RadioButton.TextTransformProperty,
                HostProp.BorderColor => RadioButton.BorderColorProperty,
                HostProp.BorderWidth => RadioButton.BorderWidthProperty,
                HostProp.CornerRadius => RadioButton.CornerRadiusProperty,
                HostProp.Padding => RadioButton.PaddingProperty,
                HostProp.FontSize => RadioButton.FontSizeProperty,
                HostProp.FontFamily => RadioButton.FontFamilyProperty,
                HostProp.FontAttributes => RadioButton.FontAttributesProperty,
                HostProp.FontAutoScalingEnabled => RadioButton.FontAutoScalingEnabledProperty,
                _ => null,
            },

            HostNodeType.Slider => name switch
            {
                HostProp.Minimum => Slider.MinimumProperty,
                HostProp.Maximum => Slider.MaximumProperty,
                HostProp.Value => Slider.ValueProperty,
                _ => null,
            },

            HostNodeType.Stepper => name switch
            {
                HostProp.Minimum => Stepper.MinimumProperty,
                HostProp.Maximum => Stepper.MaximumProperty,
                HostProp.Step => Stepper.IncrementProperty,
                HostProp.Value => Stepper.ValueProperty,
                _ => null,
            },

            HostNodeType.SearchField => name switch
            {
                HostProp.Text => SearchBar.TextProperty,
                HostProp.TextColor => SearchBar.TextColorProperty,
                HostProp.CharacterSpacing => SearchBar.CharacterSpacingProperty,
                HostProp.TextCase => SearchBar.TextTransformProperty,
                HostProp.Placeholder => SearchBar.PlaceholderProperty,
                HostProp.PlaceholderColor => SearchBar.PlaceholderColorProperty,
                HostProp.IsReadOnly => SearchBar.IsReadOnlyProperty,
                HostProp.CursorPosition => InputView.CursorPositionProperty,
                HostProp.SelectionLength => InputView.SelectionLengthProperty,
                HostProp.IsSpellCheckEnabled => InputView.IsSpellCheckEnabledProperty,
                HostProp.IsTextPredictionEnabled => InputView.IsTextPredictionEnabledProperty,
                HostProp.MaximumLength => StateUIRenderer.MaxLengthProperty,
                HostProp.InputPurpose => SearchBar.KeyboardProperty,
                HostProp.ReturnKey => SearchBar.ReturnTypeProperty,
                HostProp.HorizontalTextAlignment => SearchBar.HorizontalTextAlignmentProperty,
                HostProp.VerticalTextAlignment => SearchBar.VerticalTextAlignmentProperty,
                HostProp.FontSize => SearchBar.FontSizeProperty,
                HostProp.FontFamily => SearchBar.FontFamilyProperty,
                HostProp.FontAttributes => SearchBar.FontAttributesProperty,
                HostProp.FontAutoScalingEnabled => SearchBar.FontAutoScalingEnabledProperty,
                _ => null,
            },

            HostNodeType.ActivityIndicator => name switch
            {
                HostProp.IsRunning => ActivityIndicator.IsRunningProperty,
                _ => null,
            },

            HostNodeType.ProgressBar => name switch
            {
                HostProp.Progress => ProgressBar.ProgressProperty,
                _ => null,
            },

            HostNodeType.Image => name switch
            {
                HostProp.Source => Image.SourceProperty,
                HostProp.Aspect => Image.AspectProperty,
                HostProp.IsAnimating => Image.IsAnimationPlayingProperty,
                _ => null,
            },

            HostNodeType.ColorBox => name switch
            {
                HostProp.Color => BoxView.ColorProperty,
                HostProp.CornerRadius => BoxView.CornerRadiusProperty,
                _ => null,
            },

            HostNodeType.Border => name switch
            {
                HostProp.Stroke => Border.StrokeProperty,
                HostProp.StrokeWidth => Border.StrokeThicknessProperty,
                HostProp.Shape => Border.StrokeShapeProperty,
                HostProp.StrokeDashPattern => Border.StrokeDashArrayProperty,
                HostProp.StrokeDashOffset => Border.StrokeDashOffsetProperty,
                HostProp.StrokeLineCap => Border.StrokeLineCapProperty,
                HostProp.StrokeLineJoin => Border.StrokeLineJoinProperty,
                HostProp.StrokeMiterLimit => Border.StrokeMiterLimitProperty,
                HostProp.Padding => Border.PaddingProperty,
                _ => null,
            },

            HostNodeType.PositionIndicator => name switch
            {
                HostProp.Count => IndicatorView.CountProperty,
                HostProp.Position => IndicatorView.PositionProperty,
                HostProp.IndicatorColor => IndicatorView.IndicatorColorProperty,
                HostProp.SelectedIndicatorColor => IndicatorView.SelectedIndicatorColorProperty,
                HostProp.IndicatorSize => IndicatorView.IndicatorSizeProperty,
                HostProp.MaximumVisible => IndicatorView.MaximumVisibleProperty,
                HostProp.IndicatorsShape => IndicatorView.IndicatorsShapeProperty,
                HostProp.HideSingle => IndicatorView.HideSingleProperty,
                _ => null,
            },

            HostNodeType.Grid => name switch
            {
                HostProp.Rows => Grid.RowDefinitionsProperty,
                HostProp.Columns => Grid.ColumnDefinitionsProperty,
                HostProp.RowSpacing => Grid.RowSpacingProperty,
                HostProp.ColumnSpacing => Grid.ColumnSpacingProperty,
                HostProp.Padding => Grid.PaddingProperty,
                HostProp.AvoidsSafeArea => Grid.SafeAreaEdgesProperty,
                HostProp.ClipsContent => Grid.IsClippedToBoundsProperty,
                _ => null,
            },

            HostNodeType.VStack => name switch
            {
                HostProp.Spacing => VerticalStackLayout.SpacingProperty,
                HostProp.Padding => VerticalStackLayout.PaddingProperty,
                HostProp.AvoidsSafeArea => VerticalStackLayout.SafeAreaEdgesProperty,
                HostProp.ClipsContent => VerticalStackLayout.IsClippedToBoundsProperty,
                _ => null,
            },

            HostNodeType.HStack => name switch
            {
                HostProp.Spacing => HorizontalStackLayout.SpacingProperty,
                HostProp.Padding => HorizontalStackLayout.PaddingProperty,
                HostProp.AvoidsSafeArea => HorizontalStackLayout.SafeAreaEdgesProperty,
                HostProp.ClipsContent => HorizontalStackLayout.IsClippedToBoundsProperty,
                _ => null,
            },

            HostNodeType.ScrollView => name switch
            {
                HostProp.Orientation => ScrollView.OrientationProperty,
                HostProp.Padding => ScrollView.PaddingProperty,
                HostProp.VerticalScrollBarVisibility => ScrollView.VerticalScrollBarVisibilityProperty,
                HostProp.HorizontalScrollBarVisibility => ScrollView.HorizontalScrollBarVisibilityProperty,
                _ => null,
            },

            HostNodeType.WebView => name switch
            {
                HostProp.Source => WebView.SourceProperty,
                HostProp.UserAgent => WebView.UserAgentProperty,
                _ => null,
            },

            HostNodeType.TitleBar => name switch
            {
                HostProp.Title => TitleBar.TitleProperty,
                HostProp.Subtitle => TitleBar.SubtitleProperty,
                HostProp.Icon => TitleBar.IconProperty,
                HostProp.BarForegroundColor => TitleBar.ForegroundColorProperty,
                _ => null,
            },

            HostNodeType.Map => name switch
            {
                HostProp.MapType => Microsoft.Maui.Controls.Maps.Map.MapTypeProperty,
                HostProp.IsScrollEnabled => Microsoft.Maui.Controls.Maps.Map.IsScrollEnabledProperty,
                HostProp.IsZoomEnabled => Microsoft.Maui.Controls.Maps.Map.IsZoomEnabledProperty,
                HostProp.IsTrafficEnabled => Microsoft.Maui.Controls.Maps.Map.IsTrafficEnabledProperty,
                HostProp.ShowsUserLocation => Microsoft.Maui.Controls.Maps.Map.IsShowingUserProperty,
                _ => null,
            },

            HostNodeType.AbsoluteLayout => name switch
            {
                HostProp.Padding => AbsoluteLayout.PaddingProperty,
                HostProp.AvoidsSafeArea => AbsoluteLayout.SafeAreaEdgesProperty,
                HostProp.ClipsContent => AbsoluteLayout.IsClippedToBoundsProperty,
                _ => null,
            },

            HostNodeType.RefreshView => name switch
            {
                HostProp.IsRefreshing => RefreshView.IsRefreshingProperty,
                HostProp.IsRefreshEnabled => RefreshView.IsRefreshEnabledProperty,
                _ => null,
            },

            HostNodeType.SwipeView => name switch
            {
                HostProp.Threshold => SwipeView.ThresholdProperty,
                _ => null,
            },

            // The shapes. Each falls through to the tier MAUI declares once, on
            // Shape - which is why there is a method for it rather than seven
            // copies of the same nine names.
            HostNodeType.Rectangle => name switch
            {
                HostProp.CornerRadius => SwiftRoundRectangle.CornerRadiusProperty,
                _ => ShapeProperty(name),
            },

            HostNodeType.Ellipse => ShapeProperty(name),

            HostNodeType.Line => name switch
            {
                HostProp.X1 => SwiftLine.X1Property,
                HostProp.Y1 => SwiftLine.Y1Property,
                HostProp.X2 => SwiftLine.X2Property,
                HostProp.Y2 => SwiftLine.Y2Property,
                _ => ShapeProperty(name),
            },

            HostNodeType.Path => name switch
            {
                HostProp.Data => SwiftPath.DataProperty,
                _ => ShapeProperty(name),
            },

            HostNodeType.Polygon => name switch
            {
                HostProp.Points => SwiftPolygon.PointsProperty,
                HostProp.FillRule => SwiftPolygon.FillRuleProperty,
                _ => ShapeProperty(name),
            },

            HostNodeType.Polyline => name switch
            {
                HostProp.Points => SwiftPolyline.PointsProperty,
                HostProp.FillRule => SwiftPolyline.FillRuleProperty,
                _ => ShapeProperty(name),
            },

            HostNodeType.Canvas => name switch
            {
                HostProp.Drawable => GraphicsView.DrawableProperty,
                _ => null,
            },

            _ => null,
        };
    }

    /// <summary>
    /// What every page has, whichever kind it is - MAUI declares these on
    /// <see cref="Page"/>, and the rest are attached properties written ON a
    /// page by the arrangement holding it.
    /// </summary>
    /// <remarks>
    /// Not in <see cref="Shared"/>: a page is a VisualElement, so what it
    /// shares with a control is already answered there, and these belong to
    /// the pages alone. What a page asks of the navigation bar -
    /// <c>hasNavigationBar</c>, <c>hasBackButton</c>, <c>backButtonTitle</c> -
    /// is NavigationPage's attached properties, which is why they are read
    /// here rather than on the stack: a page carries what it asks of whatever
    /// stack it lands in.
    /// </remarks>
    /// <param name="name">The property, by member.</param>
    private static BindableProperty? PageProperty(HostProp name)
    {
        return name switch
        {
            HostProp.Title => Page.TitleProperty,
            HostProp.Icon => Page.IconImageSourceProperty,
            HostProp.Padding => Page.PaddingProperty,
            HostProp.HasNavigationBar => NavigationPage.HasNavigationBarProperty,
            HostProp.HasBackButton => NavigationPage.HasBackButtonProperty,
            HostProp.BackButtonTitle => NavigationPage.BackButtonTitleProperty,

            _ => null,
        };
    }

    /// <summary>What a Menu on the menu bar has - MAUI's MenuBarItem.</summary>
    /// <param name="name">The property, by member.</param>
    private static BindableProperty? MenuBarProperty(HostProp name)
    {
        return name switch
        {
            HostProp.Text => MenuBarItem.TextProperty,
            HostProp.IsEnabled => MenuBarItem.IsEnabledProperty,
            _ => null,
        };
    }

    /// <summary>
    /// What a toolbar item and a flyout entry share, MAUI declaring both on
    /// <see cref="MenuItem"/>.
    /// </summary>
    /// <remarks>
    /// None of these is a View, so none is a style target either - they are
    /// here so that an entry that stops describing its text or its icon has
    /// that property cleared rather than the whole item rebuilt.
    /// </remarks>
    /// <param name="name">The property, by member.</param>
    private static BindableProperty? MenuItemProperty(HostProp name)
    {
        return name switch
        {
            HostProp.Text => MenuItem.TextProperty,
            HostProp.Icon => MenuItem.IconImageSourceProperty,
            HostProp.IsDestructive => MenuItem.IsDestructiveProperty,
            HostProp.IsEnabled => MenuItem.IsEnabledProperty,
            _ => null,
        };
    }

    /// <summary>
    /// What every shape has, because MAUI declares it once on
    /// <see cref="Shape"/>.
    /// </summary>
    /// <remarks>
    /// Not in <see cref="Shared"/>, where it would answer for a Label as well:
    /// these belong to the shapes and to nothing else.
    /// </remarks>
    private static BindableProperty? ShapeProperty(HostProp name)
    {
        return name switch
        {
            HostProp.Fill => Shape.FillProperty,
            HostProp.Stroke => Shape.StrokeProperty,
            HostProp.StrokeWidth => Shape.StrokeThicknessProperty,
            HostProp.StrokeDashPattern => Shape.StrokeDashArrayProperty,
            HostProp.StrokeDashOffset => Shape.StrokeDashOffsetProperty,
            HostProp.StrokeLineCap => Shape.StrokeLineCapProperty,
            HostProp.StrokeLineJoin => Shape.StrokeLineJoinProperty,
            HostProp.StrokeMiterLimit => Shape.StrokeMiterLimitProperty,
            HostProp.Aspect => Shape.AspectProperty,
            HostProp.RenderTransform => SwiftShapes.GeometryTransformProperty,
            _ => null,
        };
    }
}
