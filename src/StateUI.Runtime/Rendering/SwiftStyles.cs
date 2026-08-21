using Microsoft.Maui.Controls.Shapes;
using Microsoft.Maui.Layouts;
using StateUI.Runtime.Protocol;

// MAUI's shape, not System.IO's - the two are both called Path and both in
// scope, and only one of them can be styled.
using Path = Microsoft.Maui.Controls.Shapes.Path;

namespace StateUI.Runtime.Rendering;

/// <summary>
/// What a property NAME stands for - the table a visual state's setters and a
/// flight's target are both resolved through.
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
/// flight - which is why those two share this table and why a property
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
        SwiftNodeType targetType, string typeName, List<SwiftNode> states)
    {
        var groups = new VisualStateGroupList();

        foreach (SwiftNode node in states)
        {
            // A visual state's group and its name are NAMES: they ride the
            // session dictionary, so they read back through GetName. Read as
            // strings they would both answer null, and every state would land
            // in CommonStates under the empty name - which is to say every
            // state would be the same state.
            string name = node.GetName(SwiftProp.Group) ?? "CommonStates";
            VisualStateGroup? group = groups.FirstOrDefault(candidate => candidate.Name == name);

            if (group is null)
            {
                group = new VisualStateGroup { Name = name };
                groups.Add(group);
            }

            var state = new VisualState { Name = node.GetName(SwiftProp.Name) ?? "" };

            foreach (SwiftNode child in node.Children ?? [])
            {
                if (child.Type == SwiftNodeType.Setters)
                {
                    AddSetters(state.Setters, targetType, typeName, child);
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
    /// derived once per member by <see cref="SwiftTokenNames{TToken}"/> rather
    /// than per setter. Both bags go in: a registered control's own properties
    /// are as settable in a state as a Label's, and they sort among them.
    /// </para>
    /// </remarks>
    private static void AddSetters(
        IList<Setter> setters, SwiftNodeType targetType, string typeName, SwiftNode node)
    {
        List<(SwiftKey Key, string Name)> keys = [];

        foreach (SwiftProp prop in node.Props?.Keys ?? Enumerable.Empty<SwiftProp>())
        {
            string spelling = SwiftTokenNames<SwiftProp>.Spelling(prop);
            keys.Add((SwiftKey.Of(prop, spelling), spelling));
        }

        foreach (string name in node.OwnProps?.Keys ?? Enumerable.Empty<string>())
        {
            keys.Add((SwiftKey.Own(name), name));
        }

        foreach ((SwiftKey key, string _) in keys
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
    /// Internal rather than private because a flight reads its target value
    /// through here as well - see <see cref="SwiftFlights"/>. The same table
    /// answers both questions, which is what keeps a property walkable the
    /// moment it becomes styleable.
    /// </para>
    /// </remarks>
    internal static object? Value(BindableProperty property, SwiftNode node, SwiftKey key)
    {
        // Unwrapped, because MAUI 10 declares some of these nullable -
        // DatePicker.Date is a DateTime? - and a nullable type is equal to
        // no bare one: without looking through the wrapper, every date setter
        // in a style is silently dropped.
        Type type = Nullable.GetUnderlyingType(property.ReturnType) ?? property.ReturnType;

        if (type == typeof(Color)) { return node.GetColor(key); }
        if (type == typeof(Brush)) { return node.GetBrush(key); }

        if (type == typeof(double)) { return node.GetNumber(key); }
        if (type == typeof(int)) { return node.GetInt(key); }
        if (type == typeof(bool)) { return node.GetBool(key); }

        // Text OR a name: MAUI types both as a string, and the wire does not -
        // a caption is text someone wrote, while a font family and a radio
        // group are NAMES and ride the session's dictionary. One arm reads
        // both because the property's type is all there is to go on here.
        if (type == typeof(string)) { return node.GetString(key) ?? node.GetName(key); }

        // A FlexLayout's Grow and Shrink, which MAUI declares as floats where
        // everything else here is a double.
        if (type == typeof(float)) { return node.GetNumber(key) is double single ? (float)single : null; }

        if (type == typeof(Thickness)) { return node.GetThickness(key); }
        if (type == typeof(SafeAreaEdges)) { return node.GetSafeAreaEdges(key); }
        if (type == typeof(Rect)) { return node.GetRect(key); }
        if (type == typeof(CornerRadius)) { return node.GetCornerRadius(key); }
        if (type == typeof(LayoutOptions)) { return node.GetLayoutOptions(key); }
        if (type == typeof(FlowDirection)) { return node.GetFlowDirection(key); }
        if (type == typeof(TextType)) { return node.GetTextType(key); }
        if (type == typeof(Transform)) { return node.GetTransform(key); }
        if (type == typeof(Microsoft.Maui.Controls.Maps.PinType)) { return node.GetPinType(key); }
        if (type == typeof(TextAlignment)) { return node.GetTextAlignment(key); }
        if (type == typeof(FontAttributes)) { return node.GetFontAttributes(key); }
        if (type == typeof(TextDecorations)) { return node.GetTextDecorations(key); }
        if (type == typeof(TextTransform)) { return node.GetTextTransform(key); }
        if (type == typeof(LineBreakMode)) { return node.GetLineBreakMode(key); }
        if (type == typeof(Keyboard)) { return node.GetKeyboard(key); }
        if (type == typeof(ReturnType)) { return node.GetReturnType(key); }
        if (type == typeof(ClearButtonVisibility)) { return node.GetClearButtonVisibility(key); }
        if (type == typeof(EditorAutoSizeOption)) { return node.GetEditorAutoSize(key); }
        if (type == typeof(ScrollBarVisibility)) { return node.GetScrollBarVisibility(key); }
        if (type == typeof(ScrollOrientation)) { return node.GetScrollOrientation(key); }
        if (type == typeof(Aspect)) { return node.GetAspect(key); }
        if (type == typeof(DateTime)) { return node.GetDate(key); }
        if (type == typeof(TimeSpan)) { return node.GetTime(key); }

        // RadioButton.Content, the one property here MAUI types as object -
        // what crosses is the caption.
        if (type == typeof(object)) { return node.GetString(key); }

        if (type == typeof(AbsoluteLayoutFlags)) { return node.GetAbsoluteLayoutFlags(key); }
        if (type == typeof(FlexDirection)) { return node.GetFlexDirection(key); }
        if (type == typeof(FlexWrap)) { return node.GetFlexWrap(key); }
        if (type == typeof(FlexJustify)) { return node.GetFlexJustify(key); }
        if (type == typeof(FlexAlignItems)) { return node.GetFlexAlignItems(key); }
        if (type == typeof(FlexAlignContent)) { return node.GetFlexAlignContent(key); }
        if (type == typeof(FlexAlignSelf)) { return node.GetFlexAlignSelf(key); }
        if (type == typeof(FlexPosition)) { return node.GetFlexPosition(key); }
        if (type == typeof(FlexBasis)) { return node.GetFlexBasis(key); }

        // What a shape is drawn with, and what it is.
        if (type == typeof(Stretch)) { return node.GetStretch(key); }
        if (type == typeof(PenLineCap)) { return node.GetPenLineCap(key); }
        if (type == typeof(PenLineJoin)) { return node.GetPenLineJoin(key); }
        if (type == typeof(FillRule)) { return node.GetFillRule(key); }
        if (type == typeof(DoubleCollection)) { return node.GetDoubleCollection(key); }
        if (type == typeof(PointCollection)) { return node.GetPoints(key); }
        if (type == typeof(Geometry)) { return node.GetGeometry(key); }
        if (type == typeof(IDrawable)) { return node.GetDrawable(key); }

        if (type == typeof(IndicatorShape)) { return node.GetIndicatorShape(key); }

        if (type == typeof(IShape)) { return node.GetStrokeShape(key); }

        // Assignable rather than equal: an items view may declare its layout as
        // the interface, CarouselView as LinearItemsLayout - one string
        // converter serves both.
        if (typeof(IItemsLayout).IsAssignableFrom(type)) { return node.GetItemsLayout(key); }
        if (type == typeof(RowDefinitionCollection)) { return node.GetRowDefinitions(key); }
        if (type == typeof(ColumnDefinitionCollection)) { return node.GetColumnDefinitions(key); }

        if (type == typeof(ImageSource)) { return node.GetImageSource(key); }
        if (type == typeof(Button.ButtonContentLayout)) { return node.GetButtonContentLayout(key); }
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
    /// keeps a table this wide - thirty-five types, up to thirty properties
    /// apiece - to two indexed reads per lookup.
    /// </para>
    /// <para>
    /// The registry last, and it is the one door here that takes STRINGS - the
    /// only one that can, an application's control being
    /// <see cref="SwiftNodeType.None"/> with property names of its own
    /// invention. A key with no name never reaches it, which is every key the
    /// renderer itself asks with.
    /// </para>
    /// </remarks>
    /// <param name="targetType">The control's type, as the table switches on it.</param>
    /// <param name="typeName">The same, spelled - what the registry is asked by.</param>
    /// <param name="key">The property, in whichever vocabulary it belongs to.</param>
    internal static BindableProperty? Property(
        SwiftNodeType targetType, string typeName, SwiftKey key)
    {
        return Shared(key.Prop)
            ?? Own(targetType, key.Prop)
            ?? (key.Name is string name ? StateUIControls.PropertyOf(typeName, name) : null);
    }

    /// <summary>
    /// The properties MAUI declares once, high up, and every control inherits -
    /// the same tiers the Swift protocols mirror.
    /// </summary>
    private static BindableProperty? Shared(SwiftProp name)
    {
        return name switch
        {
            // VisualElement
            SwiftProp.IsVisible => VisualElement.IsVisibleProperty,
            SwiftProp.IsEnabled => VisualElement.IsEnabledProperty,
            SwiftProp.InputTransparent => VisualElement.InputTransparentProperty,
            SwiftProp.FlowDirection => VisualElement.FlowDirectionProperty,
            SwiftProp.Opacity => VisualElement.OpacityProperty,
            SwiftProp.BackgroundColor => VisualElement.BackgroundColorProperty,
            SwiftProp.Background => VisualElement.BackgroundProperty,
            SwiftProp.WidthRequest => VisualElement.WidthRequestProperty,
            SwiftProp.HeightRequest => VisualElement.HeightRequestProperty,
            SwiftProp.MinimumWidthRequest => VisualElement.MinimumWidthRequestProperty,
            SwiftProp.MinimumHeightRequest => VisualElement.MinimumHeightRequestProperty,
            SwiftProp.MaximumWidthRequest => VisualElement.MaximumWidthRequestProperty,
            SwiftProp.MaximumHeightRequest => VisualElement.MaximumHeightRequestProperty,
            SwiftProp.Rotation => VisualElement.RotationProperty,
            SwiftProp.RotationX => VisualElement.RotationXProperty,
            SwiftProp.RotationY => VisualElement.RotationYProperty,
            SwiftProp.Scale => VisualElement.ScaleProperty,
            SwiftProp.ScaleX => VisualElement.ScaleXProperty,
            SwiftProp.ScaleY => VisualElement.ScaleYProperty,
            SwiftProp.TranslationX => VisualElement.TranslationXProperty,
            SwiftProp.TranslationY => VisualElement.TranslationYProperty,
            SwiftProp.AnchorX => VisualElement.AnchorXProperty,
            SwiftProp.AnchorY => VisualElement.AnchorYProperty,
            SwiftProp.ZIndex => VisualElement.ZIndexProperty,

            // View
            SwiftProp.Margin => View.MarginProperty,
            SwiftProp.HorizontalOptions => View.HorizontalOptionsProperty,
            SwiftProp.VerticalOptions => View.VerticalOptionsProperty,

            // Where a view sits in a Grid - attached, and written on the child.
            SwiftProp.GridRow => Grid.RowProperty,
            SwiftProp.GridColumn => Grid.ColumnProperty,
            SwiftProp.GridRowSpan => Grid.RowSpanProperty,
            SwiftProp.GridColumnSpan => Grid.ColumnSpanProperty,

            // And in an AbsoluteLayout, which reads a rectangle and the flags
            // that say which of its numbers are fractions.
            SwiftProp.AbsoluteLayoutBounds => AbsoluteLayout.LayoutBoundsProperty,
            SwiftProp.AbsoluteLayoutFlags => AbsoluteLayout.LayoutFlagsProperty,

            // And what a view asks a FlexLayout for.
            SwiftProp.FlexLayoutOrder => FlexLayout.OrderProperty,
            SwiftProp.FlexLayoutGrow => FlexLayout.GrowProperty,
            SwiftProp.FlexLayoutShrink => FlexLayout.ShrinkProperty,
            SwiftProp.FlexLayoutAlignSelf => FlexLayout.AlignSelfProperty,
            SwiftProp.FlexLayoutBasis => FlexLayout.BasisProperty,

            _ => null,
        };
    }

    /// <summary>
    /// What a control declares itself. One arm per <c>Reconcile…</c> method, with
    /// the same names in it.
    /// </summary>
    private static BindableProperty? Own(SwiftNodeType targetType, SwiftProp name)
    {
        return targetType switch
        {
            // A page is not a style target - a Style in this library is
            // written against a control - but it stops describing properties
            // like anything else, and a property with no name here is one that
            // could never be CLEARED off it. See SwiftNode.Cleared.
            SwiftNodeType.ContentPage => PageProperty(name) ?? name switch
            {
                SwiftProp.HideSoftInputOnTapped => ContentPage.HideSoftInputOnTappedProperty,
                _ => null,
            },

            SwiftNodeType.NavigationPage => PageProperty(name) ?? name switch
            {
                SwiftProp.BarBackgroundColor => NavigationPage.BarBackgroundColorProperty,
                SwiftProp.BarBackground => NavigationPage.BarBackgroundProperty,
                SwiftProp.BarTextColor => NavigationPage.BarTextColorProperty,
                _ => null,
            },

            SwiftNodeType.TabbedPage => PageProperty(name) ?? name switch
            {
                SwiftProp.BarBackgroundColor => TabbedPage.BarBackgroundColorProperty,
                SwiftProp.BarTextColor => TabbedPage.BarTextColorProperty,
                SwiftProp.SelectedTabColor => TabbedPage.SelectedTabColorProperty,
                SwiftProp.UnselectedTabColor => TabbedPage.UnselectedTabColorProperty,
                _ => null,
            },

            SwiftNodeType.FlyoutPage => PageProperty(name) ?? name switch
            {
                SwiftProp.FlyoutLayoutBehavior => FlyoutPage.FlyoutLayoutBehaviorProperty,
                SwiftProp.IsGestureEnabled => FlyoutPage.IsGestureEnabledProperty,
                SwiftProp.IsPresented => FlyoutPage.IsPresentedProperty,
                _ => null,
            },

            SwiftNodeType.Window => name switch
            {
                SwiftProp.Title => Window.TitleProperty,
                SwiftProp.X => Window.XProperty,
                SwiftProp.Y => Window.YProperty,
                SwiftProp.Width => Window.WidthProperty,
                SwiftProp.Height => Window.HeightProperty,
                SwiftProp.IsMaximizable => Window.IsMaximizableProperty,
                SwiftProp.IsMinimizable => Window.IsMinimizableProperty,
                SwiftProp.MinimumWidth => Window.MinimumWidthProperty,
                SwiftProp.MinimumHeight => Window.MinimumHeightProperty,
                SwiftProp.MaximumWidth => Window.MaximumWidthProperty,
                SwiftProp.MaximumHeight => Window.MaximumHeightProperty,
                _ => null,
            },

            // Order and Priority are plain CLR properties on MAUI's
            // ToolbarItem, so there is no default to put back and no name to
            // do it by: Swift keeps them in Prop.notCleared and sends the item
            // again instead.
            SwiftNodeType.ToolbarItem => MenuItemProperty(name),

            SwiftNodeType.MenuBarItem => name switch
            {
                SwiftProp.Text => MenuBarItem.TextProperty,
                _ => null,
            },

            SwiftNodeType.MenuFlyoutItem => MenuItemProperty(name),
            SwiftNodeType.MenuFlyoutSubItem => MenuItemProperty(name),

            // A SwipeItem is a MenuItem too, which is why it needs no arm of
            // its own beyond that.
            SwiftNodeType.SwipeItem => MenuItemProperty(name),

            // Not a View either - it is the collection a SwipeView keeps its
            // items in. `side` is not MAUI's at all: it says WHICH of the four
            // collections these are, which is a decision the renderer makes
            // rather than a value it writes, so Swift keeps it in notCleared.
            SwiftNodeType.SwipeItems => name switch
            {
                SwiftProp.Mode => SwipeItems.ModeProperty,
                SwiftProp.SwipeBehaviorOnInvoked => SwipeItems.SwipeBehaviorOnInvokedProperty,
                _ => null,
            },

            // One run of a formatted string. MAUI declares the text and the
            // font on Span itself rather than through the interfaces a Label
            // wears, so none of it is answered by Shared.
            SwiftNodeType.Span => name switch
            {
                SwiftProp.Text => Span.TextProperty,
                SwiftProp.TextColor => Span.TextColorProperty,
                SwiftProp.CharacterSpacing => Span.CharacterSpacingProperty,
                SwiftProp.TextDecorations => Span.TextDecorationsProperty,
                SwiftProp.LineHeight => Span.LineHeightProperty,
                SwiftProp.FontSize => Span.FontSizeProperty,
                SwiftProp.FontFamily => Span.FontFamilyProperty,
                SwiftProp.FontAttributes => Span.FontAttributesProperty,
                SwiftProp.FontAutoScalingEnabled => Span.FontAutoScalingEnabledProperty,
                _ => null,
            },

            // One marker on a map.
            SwiftNodeType.Pin => name switch
            {
                SwiftProp.Label => Microsoft.Maui.Controls.Maps.Pin.LabelProperty,
                SwiftProp.Address => Microsoft.Maui.Controls.Maps.Pin.AddressProperty,
                SwiftProp.Type => Microsoft.Maui.Controls.Maps.Pin.TypeProperty,
                SwiftProp.Location => Microsoft.Maui.Controls.Maps.Pin.LocationProperty,
                _ => null,
            },

            SwiftNodeType.Label => name switch
            {
                SwiftProp.Text => Label.TextProperty,
                SwiftProp.TextColor => Label.TextColorProperty,
                SwiftProp.CharacterSpacing => Label.CharacterSpacingProperty,
                SwiftProp.TextTransform => Label.TextTransformProperty,
                SwiftProp.HorizontalTextAlignment => Label.HorizontalTextAlignmentProperty,
                SwiftProp.VerticalTextAlignment => Label.VerticalTextAlignmentProperty,
                SwiftProp.LineBreakMode => Label.LineBreakModeProperty,
                SwiftProp.TextType => Label.TextTypeProperty,
                SwiftProp.LineHeight => Label.LineHeightProperty,
                SwiftProp.MaxLines => Label.MaxLinesProperty,
                SwiftProp.TextDecorations => Label.TextDecorationsProperty,
                SwiftProp.Padding => Label.PaddingProperty,
                SwiftProp.FontSize => Label.FontSizeProperty,
                SwiftProp.FontFamily => Label.FontFamilyProperty,
                SwiftProp.FontAttributes => Label.FontAttributesProperty,
                SwiftProp.FontAutoScalingEnabled => Label.FontAutoScalingEnabledProperty,
                _ => null,
            },

            SwiftNodeType.Button => name switch
            {
                SwiftProp.Text => Button.TextProperty,
                SwiftProp.TextColor => Button.TextColorProperty,
                SwiftProp.CharacterSpacing => Button.CharacterSpacingProperty,
                SwiftProp.TextTransform => Button.TextTransformProperty,
                SwiftProp.BorderColor => Button.BorderColorProperty,
                SwiftProp.BorderWidth => Button.BorderWidthProperty,
                SwiftProp.CornerRadius => Button.CornerRadiusProperty,
                SwiftProp.LineBreakMode => Button.LineBreakModeProperty,
                SwiftProp.ImageSource => Button.ImageSourceProperty,
                SwiftProp.ContentLayout => Button.ContentLayoutProperty,
                SwiftProp.Padding => Button.PaddingProperty,
                SwiftProp.FontSize => Button.FontSizeProperty,
                SwiftProp.FontFamily => Button.FontFamilyProperty,
                SwiftProp.FontAttributes => Button.FontAttributesProperty,
                SwiftProp.FontAutoScalingEnabled => Button.FontAutoScalingEnabledProperty,
                _ => null,
            },

            SwiftNodeType.Entry => name switch
            {
                SwiftProp.Text => Entry.TextProperty,
                SwiftProp.TextColor => Entry.TextColorProperty,
                SwiftProp.CharacterSpacing => Entry.CharacterSpacingProperty,
                SwiftProp.TextTransform => Entry.TextTransformProperty,
                SwiftProp.Placeholder => Entry.PlaceholderProperty,
                SwiftProp.PlaceholderColor => Entry.PlaceholderColorProperty,
                SwiftProp.IsPassword => Entry.IsPasswordProperty,
                SwiftProp.IsReadOnly => Entry.IsReadOnlyProperty,
                SwiftProp.CursorPosition => InputView.CursorPositionProperty,
                SwiftProp.SelectionLength => InputView.SelectionLengthProperty,
                SwiftProp.IsSpellCheckEnabled => InputView.IsSpellCheckEnabledProperty,
                SwiftProp.IsTextPredictionEnabled => InputView.IsTextPredictionEnabledProperty,
                SwiftProp.Keyboard => Entry.KeyboardProperty,
                SwiftProp.MaxLength => Entry.MaxLengthProperty,
                SwiftProp.ReturnType => Entry.ReturnTypeProperty,
                SwiftProp.ClearButtonVisibility => Entry.ClearButtonVisibilityProperty,
                SwiftProp.HorizontalTextAlignment => Entry.HorizontalTextAlignmentProperty,
                SwiftProp.VerticalTextAlignment => Entry.VerticalTextAlignmentProperty,
                SwiftProp.FontSize => Entry.FontSizeProperty,
                SwiftProp.FontFamily => Entry.FontFamilyProperty,
                SwiftProp.FontAttributes => Entry.FontAttributesProperty,
                SwiftProp.FontAutoScalingEnabled => Entry.FontAutoScalingEnabledProperty,
                _ => null,
            },

            SwiftNodeType.Editor => name switch
            {
                SwiftProp.Text => Editor.TextProperty,
                SwiftProp.TextColor => Editor.TextColorProperty,
                SwiftProp.CharacterSpacing => Editor.CharacterSpacingProperty,
                SwiftProp.TextTransform => Editor.TextTransformProperty,
                SwiftProp.Placeholder => Editor.PlaceholderProperty,
                SwiftProp.PlaceholderColor => Editor.PlaceholderColorProperty,
                SwiftProp.IsReadOnly => Editor.IsReadOnlyProperty,
                SwiftProp.CursorPosition => InputView.CursorPositionProperty,
                SwiftProp.SelectionLength => InputView.SelectionLengthProperty,
                SwiftProp.IsSpellCheckEnabled => InputView.IsSpellCheckEnabledProperty,
                SwiftProp.IsTextPredictionEnabled => InputView.IsTextPredictionEnabledProperty,
                SwiftProp.MaxLength => Editor.MaxLengthProperty,
                SwiftProp.Keyboard => Editor.KeyboardProperty,
                SwiftProp.AutoSize => Editor.AutoSizeProperty,
                SwiftProp.HorizontalTextAlignment => Editor.HorizontalTextAlignmentProperty,
                SwiftProp.VerticalTextAlignment => Editor.VerticalTextAlignmentProperty,
                SwiftProp.FontSize => Editor.FontSizeProperty,
                SwiftProp.FontFamily => Editor.FontFamilyProperty,
                SwiftProp.FontAttributes => Editor.FontAttributesProperty,
                SwiftProp.FontAutoScalingEnabled => Editor.FontAutoScalingEnabledProperty,
                _ => null,
            },

            SwiftNodeType.Picker => name switch
            {
                SwiftProp.SelectedIndex => Picker.SelectedIndexProperty,
                SwiftProp.IsOpen => Picker.IsOpenProperty,
                SwiftProp.Title => Picker.TitleProperty,
                SwiftProp.TitleColor => Picker.TitleColorProperty,
                SwiftProp.TextColor => Picker.TextColorProperty,
                SwiftProp.CharacterSpacing => Picker.CharacterSpacingProperty,
                SwiftProp.HorizontalTextAlignment => Picker.HorizontalTextAlignmentProperty,
                SwiftProp.VerticalTextAlignment => Picker.VerticalTextAlignmentProperty,
                SwiftProp.FontSize => Picker.FontSizeProperty,
                SwiftProp.FontFamily => Picker.FontFamilyProperty,
                SwiftProp.FontAttributes => Picker.FontAttributesProperty,
                SwiftProp.FontAutoScalingEnabled => Picker.FontAutoScalingEnabledProperty,
                _ => null,
            },

            SwiftNodeType.DatePicker => name switch
            {
                SwiftProp.Date => DatePicker.DateProperty,
                SwiftProp.IsOpen => DatePicker.IsOpenProperty,
                SwiftProp.MinimumDate => DatePicker.MinimumDateProperty,
                SwiftProp.MaximumDate => DatePicker.MaximumDateProperty,
                SwiftProp.Format => DatePicker.FormatProperty,
                SwiftProp.TextColor => DatePicker.TextColorProperty,
                SwiftProp.CharacterSpacing => DatePicker.CharacterSpacingProperty,
                SwiftProp.FontSize => DatePicker.FontSizeProperty,
                SwiftProp.FontFamily => DatePicker.FontFamilyProperty,
                SwiftProp.FontAttributes => DatePicker.FontAttributesProperty,
                SwiftProp.FontAutoScalingEnabled => DatePicker.FontAutoScalingEnabledProperty,
                _ => null,
            },

            SwiftNodeType.TimePicker => name switch
            {
                SwiftProp.Time => TimePicker.TimeProperty,
                SwiftProp.IsOpen => TimePicker.IsOpenProperty,
                SwiftProp.Format => TimePicker.FormatProperty,
                SwiftProp.TextColor => TimePicker.TextColorProperty,
                SwiftProp.CharacterSpacing => TimePicker.CharacterSpacingProperty,
                SwiftProp.FontSize => TimePicker.FontSizeProperty,
                SwiftProp.FontFamily => TimePicker.FontFamilyProperty,
                SwiftProp.FontAttributes => TimePicker.FontAttributesProperty,
                SwiftProp.FontAutoScalingEnabled => TimePicker.FontAutoScalingEnabledProperty,
                _ => null,
            },

            SwiftNodeType.Switch => name switch
            {
                SwiftProp.IsToggled => Switch.IsToggledProperty,
                SwiftProp.OnColor => Switch.OnColorProperty,
                SwiftProp.OffColor => Switch.OffColorProperty,
                SwiftProp.ThumbColor => Switch.ThumbColorProperty,
                _ => null,
            },

            SwiftNodeType.CheckBox => name switch
            {
                SwiftProp.IsChecked => CheckBox.IsCheckedProperty,
                SwiftProp.Color => CheckBox.ColorProperty,
                _ => null,
            },

            SwiftNodeType.RadioButton => name switch
            {
                SwiftProp.Content => RadioButton.ContentProperty,
                SwiftProp.IsChecked => RadioButton.IsCheckedProperty,
                SwiftProp.GroupName => RadioButton.GroupNameProperty,
                SwiftProp.TextColor => RadioButton.TextColorProperty,
                SwiftProp.CharacterSpacing => RadioButton.CharacterSpacingProperty,
                SwiftProp.TextTransform => RadioButton.TextTransformProperty,
                SwiftProp.BorderColor => RadioButton.BorderColorProperty,
                SwiftProp.BorderWidth => RadioButton.BorderWidthProperty,
                SwiftProp.CornerRadius => RadioButton.CornerRadiusProperty,
                SwiftProp.Padding => RadioButton.PaddingProperty,
                SwiftProp.FontSize => RadioButton.FontSizeProperty,
                SwiftProp.FontFamily => RadioButton.FontFamilyProperty,
                SwiftProp.FontAttributes => RadioButton.FontAttributesProperty,
                SwiftProp.FontAutoScalingEnabled => RadioButton.FontAutoScalingEnabledProperty,
                _ => null,
            },

            SwiftNodeType.Slider => name switch
            {
                SwiftProp.Minimum => Slider.MinimumProperty,
                SwiftProp.Maximum => Slider.MaximumProperty,
                SwiftProp.Value => Slider.ValueProperty,
                SwiftProp.MinimumTrackColor => Slider.MinimumTrackColorProperty,
                SwiftProp.MaximumTrackColor => Slider.MaximumTrackColorProperty,
                SwiftProp.ThumbColor => Slider.ThumbColorProperty,
                SwiftProp.ThumbImageSource => Slider.ThumbImageSourceProperty,
                _ => null,
            },

            SwiftNodeType.Stepper => name switch
            {
                SwiftProp.Minimum => Stepper.MinimumProperty,
                SwiftProp.Maximum => Stepper.MaximumProperty,
                SwiftProp.Increment => Stepper.IncrementProperty,
                SwiftProp.Value => Stepper.ValueProperty,
                _ => null,
            },

            SwiftNodeType.SearchBar => name switch
            {
                SwiftProp.Text => SearchBar.TextProperty,
                SwiftProp.TextColor => SearchBar.TextColorProperty,
                SwiftProp.CharacterSpacing => SearchBar.CharacterSpacingProperty,
                SwiftProp.TextTransform => SearchBar.TextTransformProperty,
                SwiftProp.Placeholder => SearchBar.PlaceholderProperty,
                SwiftProp.PlaceholderColor => SearchBar.PlaceholderColorProperty,
                SwiftProp.IsReadOnly => SearchBar.IsReadOnlyProperty,
                SwiftProp.CursorPosition => InputView.CursorPositionProperty,
                SwiftProp.SelectionLength => InputView.SelectionLengthProperty,
                SwiftProp.IsSpellCheckEnabled => InputView.IsSpellCheckEnabledProperty,
                SwiftProp.IsTextPredictionEnabled => InputView.IsTextPredictionEnabledProperty,
                SwiftProp.MaxLength => SearchBar.MaxLengthProperty,
                SwiftProp.Keyboard => SearchBar.KeyboardProperty,
                SwiftProp.ReturnType => SearchBar.ReturnTypeProperty,
                SwiftProp.CancelButtonColor => SearchBar.CancelButtonColorProperty,
                SwiftProp.SearchIconColor => SearchBar.SearchIconColorProperty,
                SwiftProp.HorizontalTextAlignment => SearchBar.HorizontalTextAlignmentProperty,
                SwiftProp.VerticalTextAlignment => SearchBar.VerticalTextAlignmentProperty,
                SwiftProp.FontSize => SearchBar.FontSizeProperty,
                SwiftProp.FontFamily => SearchBar.FontFamilyProperty,
                SwiftProp.FontAttributes => SearchBar.FontAttributesProperty,
                SwiftProp.FontAutoScalingEnabled => SearchBar.FontAutoScalingEnabledProperty,
                _ => null,
            },

            SwiftNodeType.ActivityIndicator => name switch
            {
                SwiftProp.IsRunning => ActivityIndicator.IsRunningProperty,
                SwiftProp.Color => ActivityIndicator.ColorProperty,
                _ => null,
            },

            SwiftNodeType.ProgressBar => name switch
            {
                SwiftProp.Progress => ProgressBar.ProgressProperty,
                SwiftProp.ProgressColor => ProgressBar.ProgressColorProperty,
                _ => null,
            },

            SwiftNodeType.Image => name switch
            {
                SwiftProp.Source => Image.SourceProperty,
                SwiftProp.Aspect => Image.AspectProperty,
                SwiftProp.IsAnimationPlaying => Image.IsAnimationPlayingProperty,
                SwiftProp.IsOpaque => Image.IsOpaqueProperty,
                _ => null,
            },

            SwiftNodeType.ImageButton => name switch
            {
                SwiftProp.Source => ImageButton.SourceProperty,
                SwiftProp.Aspect => ImageButton.AspectProperty,
                SwiftProp.IsOpaque => ImageButton.IsOpaqueProperty,
                SwiftProp.BorderColor => ImageButton.BorderColorProperty,
                SwiftProp.BorderWidth => ImageButton.BorderWidthProperty,
                SwiftProp.CornerRadius => ImageButton.CornerRadiusProperty,
                SwiftProp.Padding => ImageButton.PaddingProperty,
                _ => null,
            },

            SwiftNodeType.BoxView => name switch
            {
                SwiftProp.Color => BoxView.ColorProperty,
                SwiftProp.CornerRadius => BoxView.CornerRadiusProperty,
                _ => null,
            },

            SwiftNodeType.Border => name switch
            {
                SwiftProp.Stroke => Border.StrokeProperty,
                SwiftProp.StrokeThickness => Border.StrokeThicknessProperty,
                SwiftProp.StrokeShape => Border.StrokeShapeProperty,
                SwiftProp.StrokeDashArray => Border.StrokeDashArrayProperty,
                SwiftProp.StrokeDashOffset => Border.StrokeDashOffsetProperty,
                SwiftProp.StrokeLineCap => Border.StrokeLineCapProperty,
                SwiftProp.StrokeLineJoin => Border.StrokeLineJoinProperty,
                SwiftProp.StrokeMiterLimit => Border.StrokeMiterLimitProperty,
                SwiftProp.Padding => Border.PaddingProperty,
                _ => null,
            },

            SwiftNodeType.CarouselView => name switch
            {
                SwiftProp.Loop => CarouselView.LoopProperty,
                SwiftProp.IsSwipeEnabled => CarouselView.IsSwipeEnabledProperty,
                SwiftProp.IsBounceEnabled => CarouselView.IsBounceEnabledProperty,
                SwiftProp.IsScrollAnimated => CarouselView.IsScrollAnimatedProperty,
                SwiftProp.RemainingItemsThreshold => CarouselView.RemainingItemsThresholdProperty,
                SwiftProp.PeekAreaInsets => CarouselView.PeekAreaInsetsProperty,
                SwiftProp.Position => CarouselView.PositionProperty,
                SwiftProp.ItemsLayout => CarouselView.ItemsLayoutProperty,
                SwiftProp.VerticalScrollBarVisibility => CarouselView.VerticalScrollBarVisibilityProperty,
                SwiftProp.HorizontalScrollBarVisibility => CarouselView.HorizontalScrollBarVisibilityProperty,
                _ => null,
            },

            SwiftNodeType.IndicatorView => name switch
            {
                SwiftProp.Count => IndicatorView.CountProperty,
                SwiftProp.Position => IndicatorView.PositionProperty,
                SwiftProp.IndicatorColor => IndicatorView.IndicatorColorProperty,
                SwiftProp.SelectedIndicatorColor => IndicatorView.SelectedIndicatorColorProperty,
                SwiftProp.IndicatorSize => IndicatorView.IndicatorSizeProperty,
                SwiftProp.MaximumVisible => IndicatorView.MaximumVisibleProperty,
                SwiftProp.IndicatorsShape => IndicatorView.IndicatorsShapeProperty,
                SwiftProp.HideSingle => IndicatorView.HideSingleProperty,
                _ => null,
            },

            SwiftNodeType.Grid => name switch
            {
                SwiftProp.RowDefinitions => Grid.RowDefinitionsProperty,
                SwiftProp.ColumnDefinitions => Grid.ColumnDefinitionsProperty,
                SwiftProp.RowSpacing => Grid.RowSpacingProperty,
                SwiftProp.ColumnSpacing => Grid.ColumnSpacingProperty,
                SwiftProp.Padding => Grid.PaddingProperty,
                SwiftProp.SafeAreaEdges => Grid.SafeAreaEdgesProperty,
                SwiftProp.IsClippedToBounds => Grid.IsClippedToBoundsProperty,
                SwiftProp.CascadeInputTransparent => Grid.CascadeInputTransparentProperty,
                _ => null,
            },

            SwiftNodeType.VerticalStackLayout => name switch
            {
                SwiftProp.Spacing => VerticalStackLayout.SpacingProperty,
                SwiftProp.Padding => VerticalStackLayout.PaddingProperty,
                SwiftProp.SafeAreaEdges => VerticalStackLayout.SafeAreaEdgesProperty,
                SwiftProp.IsClippedToBounds => VerticalStackLayout.IsClippedToBoundsProperty,
                SwiftProp.CascadeInputTransparent => VerticalStackLayout.CascadeInputTransparentProperty,
                _ => null,
            },

            SwiftNodeType.HorizontalStackLayout => name switch
            {
                SwiftProp.Spacing => HorizontalStackLayout.SpacingProperty,
                SwiftProp.Padding => HorizontalStackLayout.PaddingProperty,
                SwiftProp.SafeAreaEdges => HorizontalStackLayout.SafeAreaEdgesProperty,
                SwiftProp.IsClippedToBounds => HorizontalStackLayout.IsClippedToBoundsProperty,
                SwiftProp.CascadeInputTransparent => HorizontalStackLayout.CascadeInputTransparentProperty,
                _ => null,
            },

            SwiftNodeType.ScrollView => name switch
            {
                SwiftProp.Orientation => ScrollView.OrientationProperty,
                SwiftProp.Padding => ScrollView.PaddingProperty,
                SwiftProp.VerticalScrollBarVisibility => ScrollView.VerticalScrollBarVisibilityProperty,
                SwiftProp.HorizontalScrollBarVisibility => ScrollView.HorizontalScrollBarVisibilityProperty,
                _ => null,
            },

            SwiftNodeType.WebView => name switch
            {
                SwiftProp.Source => WebView.SourceProperty,
                SwiftProp.UserAgent => WebView.UserAgentProperty,
                _ => null,
            },

            SwiftNodeType.TitleBar => name switch
            {
                SwiftProp.Title => TitleBar.TitleProperty,
                SwiftProp.Subtitle => TitleBar.SubtitleProperty,
                SwiftProp.Icon => TitleBar.IconProperty,
                SwiftProp.ForegroundColor => TitleBar.ForegroundColorProperty,
                _ => null,
            },

            SwiftNodeType.Map => name switch
            {
                SwiftProp.MapType => Microsoft.Maui.Controls.Maps.Map.MapTypeProperty,
                SwiftProp.IsScrollEnabled => Microsoft.Maui.Controls.Maps.Map.IsScrollEnabledProperty,
                SwiftProp.IsZoomEnabled => Microsoft.Maui.Controls.Maps.Map.IsZoomEnabledProperty,
                SwiftProp.IsTrafficEnabled => Microsoft.Maui.Controls.Maps.Map.IsTrafficEnabledProperty,
                SwiftProp.IsShowingUser => Microsoft.Maui.Controls.Maps.Map.IsShowingUserProperty,
                _ => null,
            },

            SwiftNodeType.AbsoluteLayout => name switch
            {
                SwiftProp.Padding => AbsoluteLayout.PaddingProperty,
                SwiftProp.SafeAreaEdges => AbsoluteLayout.SafeAreaEdgesProperty,
                SwiftProp.IsClippedToBounds => AbsoluteLayout.IsClippedToBoundsProperty,
                SwiftProp.CascadeInputTransparent => AbsoluteLayout.CascadeInputTransparentProperty,
                _ => null,
            },

            SwiftNodeType.FlexLayout => name switch
            {
                SwiftProp.Direction => FlexLayout.DirectionProperty,
                SwiftProp.Wrap => FlexLayout.WrapProperty,
                SwiftProp.JustifyContent => FlexLayout.JustifyContentProperty,
                SwiftProp.AlignItems => FlexLayout.AlignItemsProperty,
                SwiftProp.AlignContent => FlexLayout.AlignContentProperty,
                SwiftProp.Position => FlexLayout.PositionProperty,
                SwiftProp.Padding => FlexLayout.PaddingProperty,
                SwiftProp.SafeAreaEdges => FlexLayout.SafeAreaEdgesProperty,
                SwiftProp.IsClippedToBounds => FlexLayout.IsClippedToBoundsProperty,
                SwiftProp.CascadeInputTransparent => FlexLayout.CascadeInputTransparentProperty,
                _ => null,
            },

            SwiftNodeType.RefreshView => name switch
            {
                SwiftProp.IsRefreshing => RefreshView.IsRefreshingProperty,
                SwiftProp.RefreshColor => RefreshView.RefreshColorProperty,
                SwiftProp.IsRefreshEnabled => RefreshView.IsRefreshEnabledProperty,
                _ => null,
            },

            SwiftNodeType.SwipeView => name switch
            {
                SwiftProp.Threshold => SwipeView.ThresholdProperty,
                _ => null,
            },

            // The shapes. Each falls through to the tier MAUI declares once, on
            // Shape - which is why there is a method for it rather than seven
            // copies of the same nine names.
            SwiftNodeType.Rectangle => name switch
            {
                SwiftProp.RadiusX => Rectangle.RadiusXProperty,
                SwiftProp.RadiusY => Rectangle.RadiusYProperty,
                _ => ShapeProperty(name),
            },

            SwiftNodeType.RoundRectangle => name switch
            {
                SwiftProp.CornerRadius => RoundRectangle.CornerRadiusProperty,
                _ => ShapeProperty(name),
            },

            SwiftNodeType.Ellipse => ShapeProperty(name),

            SwiftNodeType.Line => name switch
            {
                SwiftProp.X1 => Line.X1Property,
                SwiftProp.Y1 => Line.Y1Property,
                SwiftProp.X2 => Line.X2Property,
                SwiftProp.Y2 => Line.Y2Property,
                _ => ShapeProperty(name),
            },

            SwiftNodeType.Path => name switch
            {
                SwiftProp.Data => Path.DataProperty,
                SwiftProp.RenderTransform => Path.RenderTransformProperty,
                _ => ShapeProperty(name),
            },

            SwiftNodeType.Polygon => name switch
            {
                SwiftProp.Points => Polygon.PointsProperty,
                SwiftProp.FillRule => Polygon.FillRuleProperty,
                _ => ShapeProperty(name),
            },

            SwiftNodeType.Polyline => name switch
            {
                SwiftProp.Points => Polyline.PointsProperty,
                SwiftProp.FillRule => Polyline.FillRuleProperty,
                _ => ShapeProperty(name),
            },

            SwiftNodeType.GraphicsView => name switch
            {
                SwiftProp.Drawable => GraphicsView.DrawableProperty,
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
    /// the pages alone. The <c>navigationPage…</c> five are NavigationPage's
    /// attached properties, which is why they are read here rather than on the
    /// stack - a page carries what it asks of whatever stack it lands in.
    /// </remarks>
    /// <param name="name">The property, by member.</param>
    private static BindableProperty? PageProperty(SwiftProp name)
    {
        return name switch
        {
            SwiftProp.Title => Page.TitleProperty,
            SwiftProp.IconImageSource => Page.IconImageSourceProperty,
            SwiftProp.Padding => Page.PaddingProperty,
            SwiftProp.IsBusy => Page.IsBusyProperty,
            SwiftProp.BackgroundImageSource => Page.BackgroundImageSourceProperty,

            // Deprecated in favour of per-edge SafeAreaEdges, and deliberately
            // still the one written - see SwiftPages.ApplyPageChrome for the
            // measured reason. This has to name the SAME property, or clearing
            // it would silently leave the inset where it was.
#pragma warning disable CS0618
            SwiftProp.UseSafeArea =>
                Microsoft.Maui.Controls.PlatformConfiguration.iOSSpecific.Page.UseSafeAreaProperty,
#pragma warning restore CS0618

            SwiftProp.ModalPresentationStyle =>
                Microsoft.Maui.Controls.PlatformConfiguration.iOSSpecific.Page
                    .ModalPresentationStyleProperty,

            SwiftProp.NavigationPageHasNavigationBar => NavigationPage.HasNavigationBarProperty,
            SwiftProp.NavigationPageHasBackButton => NavigationPage.HasBackButtonProperty,
            SwiftProp.NavigationPageBackButtonTitle => NavigationPage.BackButtonTitleProperty,
            SwiftProp.NavigationPageTitleIconImageSource =>
                NavigationPage.TitleIconImageSourceProperty,
            SwiftProp.NavigationPageIconColor => NavigationPage.IconColorProperty,

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
    private static BindableProperty? MenuItemProperty(SwiftProp name)
    {
        return name switch
        {
            SwiftProp.Text => MenuItem.TextProperty,
            SwiftProp.IconImageSource => MenuItem.IconImageSourceProperty,
            SwiftProp.IsDestructive => MenuItem.IsDestructiveProperty,
            SwiftProp.IsEnabled => MenuItem.IsEnabledProperty,
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
    private static BindableProperty? ShapeProperty(SwiftProp name)
    {
        return name switch
        {
            SwiftProp.Fill => Shape.FillProperty,
            SwiftProp.Stroke => Shape.StrokeProperty,
            SwiftProp.StrokeThickness => Shape.StrokeThicknessProperty,
            SwiftProp.StrokeDashArray => Shape.StrokeDashArrayProperty,
            SwiftProp.StrokeDashOffset => Shape.StrokeDashOffsetProperty,
            SwiftProp.StrokeLineCap => Shape.StrokeLineCapProperty,
            SwiftProp.StrokeLineJoin => Shape.StrokeLineJoinProperty,
            SwiftProp.StrokeMiterLimit => Shape.StrokeMiterLimitProperty,
            SwiftProp.Aspect => Shape.AspectProperty,
            _ => null,
        };
    }
}
