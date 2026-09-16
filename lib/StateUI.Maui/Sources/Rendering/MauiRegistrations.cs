// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

using StateUI.Maui.Protocol;

namespace StateUI.Maui.Rendering;

/// <summary>
/// How this host realizes the library's own elements - one registration per
/// element contract, through the road an application's own control takes.
/// </summary>
/// <remarks>
/// <para>
/// There is no second mechanism here: a <c>ProgressBar</c> is registered
/// exactly as a <c>Gallery.TrafficLight</c> is, so what the library can say
/// about an element is what an application can say about its own. A family
/// still served by the renderer's own <c>Reconcile…</c> method is simply one
/// that has not moved yet - the dispatch reaches the registry through its
/// default arm, so the two roads stand side by side while the move goes on.
/// </para>
/// <para>
/// The shared tier - margins, opacity, tint, gestures, focus, frame reports -
/// is applied around every registration by the renderer, exactly as it is for
/// an application's control, so no registration here writes one of those.
/// </para>
/// </remarks>
internal static class MauiRegistrations
{
    /// <summary>Registers every family that has moved.</summary>
    internal static void Install()
    {
        Indicators();
        Toggles();
        Values();
        Fields();
        Shapes();
        Pictures();
        Pickers();
        Buttons();
        Web();
        Drawing();
    }

    /// <summary>
    /// A surface the Swift side draws on, and the touches it answers.
    /// </summary>
    /// <remarks>
    /// The drawing is a VALUE: a list of records, one per canvas call, read
    /// whole by <c>Values.GetDrawable</c> - so nothing here has to know what a
    /// drawing is, only that it replaces the one before it. A canvas is told to
    /// redraw as the new one lands, which nothing else would do for it.
    /// </remarks>
    private static void Drawing()
    {
        StateUIControls.Add("Canvas",
            create: _ => new GraphicsView(),
            realize: canvas => canvas
                .Held(HostProp.Drawable,
                    static (node, member) => node.GetDrawable(member),
                    (view, drawable) =>
                    {
                        view.Drawable = drawable;
                        view.Invalidate();
                    })

                // Where a touch was, in the canvas's own coordinates - the ones
                // the drawing instructions use. MAUI reports every finger; this
                // carries the first, which is what a drawing surface acts on,
                // and a report with none is left empty rather than invented.
                .Carries(HostEvent.Pressed,
                    (view, at) => view.StartInteraction += (_, e) => at(Touch(e)))
                .Carries(HostEvent.Dragged,
                    (view, at) => view.DragInteraction += (_, e) => at(Touch(e)))
                .Carries(HostEvent.Released,
                    (view, at) => view.EndInteraction += (_, e) => at(Touch(e))));
    }

    /// <summary>Where a touch happened, or nothing where no finger is named.</summary>
    private static HostValue[] Touch(TouchEventArgs e) =>
        e.Touches is [PointF point, ..] ? [HostValue.Of(point.X, point.Y)] : [];

    /// <summary>
    /// A page of the web, and the journeys it makes.
    /// </summary>
    /// <remarks>
    /// <para>
    /// Its four acts - back, forward, reload, and running a script - are NOT
    /// registered here. An act names the view it is aimed at and is performed
    /// by the session against that identity, because a description has no
    /// control to call a method on; see <c>ActPerformer</c>.
    /// </para>
    /// <para>
    /// Nor are <c>canGoBackChanged</c> and <c>canGoForwardChanged</c>: MAUI
    /// gives neither an event, so both are heard by watching the property, and
    /// that watch is set on every view the tree asks it of - a registration
    /// and a renderer arm alike.
    /// </para>
    /// </remarks>
    private static void Web()
    {
        StateUIControls.Add("WebView",
            create: _ => new WebView(),
            realize: web => web

                // The agent before the source: a page that starts loading as
                // its address arrives should already carry who is asking.
                .Property<string>(HostProp.UserAgent, (view, agent) => view.UserAgent = agent)

                // Assigned only when the message carries it - a source that
                // did not change must not navigate the view again.
                .Held(HostProp.Source,
                    static (node, member) => node.GetWebViewSource(member),
                    (view, source) => view.Source = source)

                // Each payload's values ride in the order MAUI declares them -
                // why, then where; how it ended, why, then where - and the
                // Swift side reads them by position.
                .Carries(HostEvent.Navigating,
                    (view, carried) => view.Navigating += (_, e) => carried(
                    [
                        HostValue.OfMember((int)StateUIRenderer.Member(e.NavigationEvent)),
                        HostValue.Of(e.Url ?? ""),
                    ]))
                .Carries(HostEvent.Navigated,
                    (view, carried) => view.Navigated += (_, e) => carried(
                    [
                        HostValue.OfMember((int)StateUIRenderer.Member(e.Result)),
                        HostValue.OfMember((int)StateUIRenderer.Member(e.NavigationEvent)),
                        HostValue.Of(e.Url ?? ""),
                    ]))
                .Raises(HostEvent.ProcessTerminated,
                    (view, gone) => view.ProcessTerminated += (_, _) => gone()));
    }

    /// <summary>
    /// The control a reader presses: a caption, a picture beside it, and the
    /// three moments of a press.
    /// </summary>
    /// <remarks>
    /// Where the icon sits and how far it stands from the caption are two
    /// members here and one <c>ContentLayout</c> in MAUI - so each is written
    /// on its own, and <c>ComposedProperties</c> makes the pair into the one
    /// object, the way it makes one tint into whichever colour a control keeps
    /// it in.
    /// </remarks>
    private static void Buttons()
    {
        StateUIControls.Add("Button",
            create: _ => new Button(),
            realize: button => button
                .Property<string>(HostProp.Text, (view, text) => view.Text = text)
                .TextStyle(
                    (view, colour) => view.TextColor = colour,
                    (view, spacing) => view.CharacterSpacing = spacing)
                .Property(HostProp.TextCase,
                    static (node, member) => node.GetTextTransform(member),
                    (view, transform) => view.TextTransform = transform)
                .Held(HostProp.BorderColor,
                    static (node, member) => node.GetColor(member),
                    (view, colour) => view.BorderColor = colour)
                .Property<double>(HostProp.BorderWidth, (view, width) => view.BorderWidth = width)
                .Property(HostProp.CornerRadius,
                    static (node, member) => node.GetInt(member),
                    (view, radius) => view.CornerRadius = radius)
                .Property(HostProp.LineBreak,
                    static (node, member) => node.GetLineBreakMode(member),
                    (view, mode) => view.LineBreakMode = mode)
                .Property(HostProp.Padding,
                    static (node, member) => node.GetThickness(member),
                    (view, padding) => view.Padding = padding)
                .Held(HostProp.Icon,
                    static (node, member) => node.GetImageSource(member),
                    (view, icon) => view.ImageSource = icon)
                .Property(HostProp.IconPosition,
                    static (node, member) => node.GetIconPosition(member),
                    (view, position) =>
                        view.SetValue(ComposedProperties.IconPositionProperty, position))
                .Property<double>(HostProp.IconSpacing,
                    (view, spacing) =>
                        view.SetValue(ComposedProperties.IconSpacingProperty, spacing))
                .Font(
                    (view, size) => view.FontSize = size,
                    (view, family) => view.FontFamily = family,
                    (view, attributes) => view.FontAttributes = attributes,
                    (view, scaling) => view.FontAutoScalingEnabled = scaling)
                .Raises(HostEvent.Clicked, (view, clicked) => view.Clicked += (_, _) => clicked())
                .Raises(HostEvent.Pressed, (view, pressed) => view.Pressed += (_, _) => pressed())
                .Raises(HostEvent.Released,
                    (view, released) => view.Released += (_, _) => released()));
    }

    /// <summary>
    /// The controls that offer a reader a choice and then show it: one of a
    /// list, a day of a calendar, a time of a clock.
    /// </summary>
    /// <remarks>
    /// All three open and shut, and MAUI reports those two moments only for a
    /// control a handler stands behind - so the events are registered whether
    /// or not a given platform ever raises them, which is what the contract
    /// promises and what each host honours as it can.
    /// </remarks>
    private static void Pickers()
    {
        StateUIControls.Add("Picker",
            create: _ => new Picker(),
            realize: picker => picker

                // THE LIST BEFORE THE CHOICE, and the order here is the order
                // the members are applied in: an index means nothing until
                // there is something to count. Measured: an index set on an
                // empty picker reads back as -1, and comes back as itself once
                // the list arrives - so the order reads as the list holding
                // the choice, which is what it means.
                .Held(HostProp.Options,
                    static (node, member) => node.GetStrings(member),
                    (view, options) => view.ItemsSource = options)
                .Property(HostProp.SelectedIndex,
                    static (node, member) => node.GetInt(member),
                    (view, index) => view.SelectedIndex = index)
                .Property<bool>(HostProp.IsOpen, (view, open) => view.IsOpen = open)
                .Property<string>(HostProp.Title, (view, title) => view.Title = title)
                .TextStyle(
                    (view, colour) => view.TextColor = colour,
                    (view, spacing) => view.CharacterSpacing = spacing)
                .TextAligned(
                    (view, across) => view.HorizontalTextAlignment = across,
                    (view, down) => view.VerticalTextAlignment = down)
                .Font(
                    (view, size) => view.FontSize = size,
                    (view, family) => view.FontFamily = family,
                    (view, attributes) => view.FontAttributes = attributes,
                    (view, scaling) => view.FontAutoScalingEnabled = scaling)

                // The chosen index is read off the CONTROL: the notification
                // carries nothing, and the index is what settled.
                .Changes(Picker.SelectedIndexProperty, HostEvent.SelectedIndexChanged,
                    view => [view.SelectedIndex],
                    view => [HostValue.Of(view.SelectedIndex)],
                    (view, chosen) => view.SelectedIndexChanged += (_, _) => chosen())
                .Raises(HostEvent.Opened, (view, opened) => view.Opened += (_, _) => opened())
                .Raises(HostEvent.Closed, (view, closed) => view.Closed += (_, _) => closed()));

        StateUIControls.Add("DatePicker",
            create: _ => new DatePicker(),
            realize: picker => picker
                .Property(HostProp.MinimumDate,
                    static (node, member) => node.GetDate(member),
                    (view, day) => view.MinimumDate = day)
                .Property(HostProp.MaximumDate,
                    static (node, member) => node.GetDate(member),
                    (view, day) => view.MaximumDate = day)
                .Property(HostProp.Date,
                    static (node, member) => node.GetDate(member),
                    (view, day) => view.Date = day)
                .Property<bool>(HostProp.IsOpen, (view, open) => view.IsOpen = open)
                .Property<string>(HostProp.Format, (view, format) => view.Format = format)
                .TextStyle(
                    (view, colour) => view.TextColor = colour,
                    (view, spacing) => view.CharacterSpacing = spacing)
                .Font(
                    (view, size) => view.FontSize = size,
                    (view, family) => view.FontFamily = family,
                    (view, attributes) => view.FontAttributes = attributes,
                    (view, scaling) => view.FontAutoScalingEnabled = scaling)

                // A day lands on the state as its three parts and reaches the
                // handler as one value of three.
                .Changes(DatePicker.DateProperty, HostEvent.DateChanged,
                    view => view.Date is DateTime day ? [day.Year, day.Month, day.Day] : [],
                    view => view.Date is DateTime day
                        ? [HostValue.Of(day.Year, day.Month, day.Day)]
                        : [],
                    (view, chosen) => view.DateSelected += (_, _) => chosen())
                .Raises(HostEvent.Opened, (view, opened) => view.Opened += (_, _) => opened())
                .Raises(HostEvent.Closed, (view, closed) => view.Closed += (_, _) => closed()));

        StateUIControls.Add("TimePicker",
            create: _ => new TimePicker(),
            realize: picker => picker
                .Property(HostProp.Time,
                    static (node, member) => node.GetTime(member),
                    (view, time) => view.Time = time)
                .Property<bool>(HostProp.IsOpen, (view, open) => view.IsOpen = open)
                .Property<string>(HostProp.Format, (view, format) => view.Format = format)
                .TextStyle(
                    (view, colour) => view.TextColor = colour,
                    (view, spacing) => view.CharacterSpacing = spacing)
                .Font(
                    (view, size) => view.FontSize = size,
                    (view, family) => view.FontFamily = family,
                    (view, attributes) => view.FontAttributes = attributes,
                    (view, scaling) => view.FontAutoScalingEnabled = scaling)

                // A TimeSpan can hold whole days; a time of day cannot, so
                // only the day's part crosses - hours, minutes, seconds.
                .Changes(TimePicker.TimeProperty, HostEvent.TimeChanged,
                    view => view.Time is TimeSpan time
                        ? [time.Hours, time.Minutes, time.Seconds]
                        : [],
                    view => view.Time is TimeSpan time
                        ? [HostValue.Of(time.Hours, time.Minutes, time.Seconds)]
                        : [],
                    (view, chosen) => view.TimeSelected += (_, _) => chosen())
                .Raises(HostEvent.Opened, (view, opened) => view.Opened += (_, _) => opened())
                .Raises(HostEvent.Closed, (view, closed) => view.Closed += (_, _) => closed()));
    }

    /// <summary>
    /// What is drawn rather than operated: a picture from the application's
    /// resources, and a rectangle of plain colour.
    /// </summary>
    /// <remarks>
    /// A picture's file is named rather than carried - the differ has already
    /// picked the half of a picture drawn per theme, so what arrives is one
    /// name MAUI resolves against what it built.
    /// </remarks>
    private static void Pictures()
    {
        StateUIControls.Add("Image",
            create: _ => new Image(),
            realize: image => image
                .Held(HostProp.Source,
                    static (node, member) => node.GetImageSource(member),
                    (view, source) => view.Source = source)
                .Property(HostProp.Aspect,
                    static (node, member) => node.GetAspect(member),
                    (view, aspect) => view.Aspect = aspect)
                .Property<bool>(HostProp.IsAnimating,
                    (view, playing) => view.IsAnimationPlaying = playing));

        StateUIControls.Add("ColorBox",
            create: _ => new BoxView(),
            realize: box => box
                .Held(HostProp.Color,
                    static (node, member) => node.GetColor(member),
                    (view, colour) => view.Color = colour)
                .Property(HostProp.CornerRadius,
                    static (node, member) => node.GetCornerRadius(member),
                    (view, radius) => view.CornerRadius = radius));
    }

    /// <summary>
    /// The drawn outlines. Six elements, one tier, and between them almost
    /// nothing: what each adds is the geometry it IS.
    /// </summary>
    /// <remarks>
    /// An ellipse adds nothing at all - it is the room it is given, and
    /// everything it can do is the tier's. Each is made as this host's own
    /// wrapper over MAUI's shape, so the one matrix beside it reaches the path
    /// the shape draws.
    /// </remarks>
    private static void Shapes()
    {
        StateUIControls.Add("Rectangle",
            create: _ => new TransformedRoundRectangle(),
            realize: rectangle => rectangle
                .Property(HostProp.CornerRadius,
                    static (node, member) => node.GetCornerRadius(member),
                    (view, radius) => view.CornerRadius = radius)
                .Shaped());

        StateUIControls.Add("Ellipse",
            create: _ => new TransformedEllipse(),
            realize: ellipse => ellipse.Shaped());

        StateUIControls.Add("Line",
            create: _ => new TransformedLine(),
            realize: line => line
                .Property<double>(HostProp.X1, (view, x) => view.X1 = x)
                .Property<double>(HostProp.X2, (view, x) => view.X2 = x)
                .Property<double>(HostProp.Y1, (view, y) => view.Y1 = y)
                .Property<double>(HostProp.Y2, (view, y) => view.Y2 = y)
                .Shaped());

        StateUIControls.Add("Path",
            create: _ => new TransformedPath(),
            realize: path => path
                .Held(HostProp.Data,
                    static (node, member) => node.GetGeometry(member),
                    (view, data) => view.Data = data)
                .Shaped());

        StateUIControls.Add("Polygon",
            create: _ => new TransformedPolygon(),
            realize: polygon => polygon
                .Property(HostProp.FillRule,
                    static (node, member) => node.GetFillRule(member),
                    (view, rule) => view.FillRule = rule)
                .Held(HostProp.Points,
                    static (node, member) => node.GetPoints(member),
                    (view, points) => view.Points = points)
                .Shaped());

        StateUIControls.Add("Polyline",
            create: _ => new TransformedPolyline(),
            realize: polyline => polyline
                .Property(HostProp.FillRule,
                    static (node, member) => node.GetFillRule(member),
                    (view, rule) => view.FillRule = rule)
                .Held(HostProp.Points,
                    static (node, member) => node.GetPoints(member),
                    (view, points) => view.Points = points)
                .Shaped());
    }

    /// <summary>
    /// The three controls a reader types into: a line, a page, and a line that
    /// asks a question.
    /// </summary>
    /// <remarks>
    /// All three wear the input tier, which carries the text itself and the
    /// event the typing raises - so none of them declares <c>textChanged</c>
    /// of its own. What differs is the little each adds: whether the letters
    /// are hidden, what the return key says, whether the field clears itself,
    /// and whether it grows with what it holds.
    /// </remarks>
    private static void Fields()
    {
        StateUIControls.Add("TextField",
            create: _ => new Entry(),
            realize: field => field
                .Input((view, typed) => view.TextChanged += (_, e) => typed(e.NewTextValue))
                .TextStyle(
                    (view, colour) => view.TextColor = colour,
                    (view, spacing) => view.CharacterSpacing = spacing)
                .TextAligned(
                    (view, across) => view.HorizontalTextAlignment = across,
                    (view, down) => view.VerticalTextAlignment = down)
                .Property(HostProp.TextCase,
                    static (node, member) => node.GetTextTransform(member),
                    (view, transform) => view.TextTransform = transform)
                .Property<bool>(HostProp.IsPassword, (view, hidden) => view.IsPassword = hidden)
                .Property(HostProp.ReturnKey,
                    static (node, member) => node.GetReturnType(member),
                    (view, key) => view.ReturnType = key)

                // One flag here, two states in MAUI: the button shows while the
                // reader is in the field, or it does not show at all.
                .Property<bool>(HostProp.ShowsClearButton,
                    (view, clears) => view.ClearButtonVisibility =
                        clears ? ClearButtonVisibility.WhileEditing : ClearButtonVisibility.Never)
                .Font(
                    (view, size) => view.FontSize = size,
                    (view, family) => view.FontFamily = family,
                    (view, attributes) => view.FontAttributes = attributes,
                    (view, scaling) => view.FontAutoScalingEnabled = scaling)
                .Raises(HostEvent.Submitted,
                    (view, submitted) => view.Completed += (_, _) => submitted()));

        StateUIControls.Add("TextEditor",
            create: _ => new Editor(),
            realize: editor => editor
                .Input((view, typed) => view.TextChanged += (_, e) => typed(e.NewTextValue))
                .TextStyle(
                    (view, colour) => view.TextColor = colour,
                    (view, spacing) => view.CharacterSpacing = spacing)
                .TextAligned(
                    (view, across) => view.HorizontalTextAlignment = across,
                    (view, down) => view.VerticalTextAlignment = down)
                .Property(HostProp.TextCase,
                    static (node, member) => node.GetTextTransform(member),
                    (view, transform) => view.TextTransform = transform)
                .Property<bool>(HostProp.GrowsWithText,
                    (view, grows) => view.AutoSize =
                        grows ? EditorAutoSizeOption.TextChanges : EditorAutoSizeOption.Disabled)
                .Font(
                    (view, size) => view.FontSize = size,
                    (view, family) => view.FontFamily = family,
                    (view, attributes) => view.FontAttributes = attributes,
                    (view, scaling) => view.FontAutoScalingEnabled = scaling));

        StateUIControls.Add("SearchField",
            create: _ => new SearchBar(),
            realize: search => search
                .Input((view, typed) => view.TextChanged += (_, e) => typed(e.NewTextValue))
                .TextStyle(
                    (view, colour) => view.TextColor = colour,
                    (view, spacing) => view.CharacterSpacing = spacing)
                .TextAligned(
                    (view, across) => view.HorizontalTextAlignment = across,
                    (view, down) => view.VerticalTextAlignment = down)
                .Property(HostProp.TextCase,
                    static (node, member) => node.GetTextTransform(member),
                    (view, transform) => view.TextTransform = transform)
                .Property(HostProp.ReturnKey,
                    static (node, member) => node.GetReturnType(member),
                    (view, key) => view.ReturnType = key)
                .Font(
                    (view, size) => view.FontSize = size,
                    (view, family) => view.FontFamily = family,
                    (view, attributes) => view.FontAttributes = attributes,
                    (view, scaling) => view.FontAutoScalingEnabled = scaling)
                .Raises(HostEvent.Submitted,
                    (view, submitted) => view.SearchButtonPressed += (_, _) => submitted()));
    }

    /// <summary>
    /// The controls a reader moves a number with: a slider dragged along its
    /// track, a stepper stepped through its range.
    /// </summary>
    /// <remarks>
    /// The range is declared before the value it holds, and a registration's
    /// members are applied in the order they are declared. MAUI clamps a value
    /// into the range as it is set - but it keeps what it was given and clamps
    /// again whenever a bound moves, so a value that arrived first comes back
    /// once the range widens. Measured both ways, on both controls: the order
    /// reads as the range holding the value, which is what it means, rather
    /// than standing between a reader and their number.
    /// </remarks>
    private static void Values()
    {
        StateUIControls.Add("Slider",
            create: _ => new Slider(),
            realize: slider => slider
                .Property<double>(HostProp.Maximum, (view, maximum) => view.Maximum = maximum)
                .Property<double>(HostProp.Minimum, (view, minimum) => view.Minimum = minimum)
                .Property<double>(HostProp.Value, (view, value) => view.Value = value)
                .Moves(Slider.ValueProperty, HostEvent.ValueChanged,
                    (view, moved) => view.ValueChanged += (_, e) => moved(e.NewValue))
                .Raises(HostEvent.DragStarted,
                    (view, began) => view.DragStarted += (_, _) => began())
                .Raises(HostEvent.DragCompleted,
                    (view, ended) => view.DragCompleted += (_, _) => ended()));

        StateUIControls.Add("Stepper",
            create: _ => new Stepper(),
            realize: stepper => stepper
                .Property<double>(HostProp.Maximum, (view, maximum) => view.Maximum = maximum)
                .Property<double>(HostProp.Minimum, (view, minimum) => view.Minimum = minimum)
                .Property<double>(HostProp.Step, (view, step) => view.Increment = step)
                .Property<double>(HostProp.Value, (view, value) => view.Value = value)
                .Moves(Stepper.ValueProperty, HostEvent.ValueChanged,
                    (view, moved) => view.ValueChanged += (_, e) => moved(e.NewValue)));
    }

    /// <summary>
    /// The two-state controls a reader operates: one value each, reported back
    /// as the reader leaves it.
    /// </summary>
    /// <remarks>
    /// A radio button is one of these too, and carries far more with it: a
    /// caption, a group, a border and a font.
    /// </remarks>
    private static void Toggles()
    {
        // THE GROUP BEFORE THE STATE, and the order here is the order the
        // members are applied in: MAUI clears the others in the group as a
        // button becomes checked, and it can only do that once it knows which
        // group this is. The group is a NAME - written by an author and
        // repeated across a tree - so it rides the session's dictionary.
        StateUIControls.Add("RadioButton",
            create: _ => new RadioButton(),
            realize: radio => radio
                .Held(HostProp.GroupName,
                    static (node, member) => node.GetName(member),
                    (view, group) => view.GroupName = group)
                .Property<string>(HostProp.Text, (view, text) => view.Content = text)
                .Property<bool>(HostProp.IsOn, (view, on) => view.IsChecked = on)
                .Held(HostProp.TextColor,
                    static (node, member) => node.GetColor(member),
                    (view, colour) => view.TextColor = colour)
                .Property<double>(HostProp.CharacterSpacing,
                    (view, spacing) => view.CharacterSpacing = spacing)
                .Property(HostProp.TextCase,
                    static (node, member) => node.GetTextTransform(member),
                    (view, transform) => view.TextTransform = transform)
                .Held(HostProp.BorderColor,
                    static (node, member) => node.GetColor(member),
                    (view, colour) => view.BorderColor = colour)
                .Property<double>(HostProp.BorderWidth,
                    (view, width) => view.BorderWidth = width)
                .Property(HostProp.CornerRadius,
                    static (node, member) => node.GetInt(member),
                    (view, radius) => view.CornerRadius = radius)
                .Property(HostProp.Padding,
                    static (node, member) => node.GetThickness(member),
                    (view, padding) => view.Padding = padding)
                .Font(
                    (view, size) => view.FontSize = size,
                    (view, family) => view.FontFamily = family,
                    (view, attributes) => view.FontAttributes = attributes,
                    (view, scaling) => view.FontAutoScalingEnabled = scaling)
                .Reports<bool>(RadioButton.IsCheckedProperty, HostEvent.Toggled,
                    (view, reported) => view.CheckedChanged += (_, e) => reported(e.Value)));

        StateUIControls.Add("Switch",
            create: _ => new Switch(),
            realize: toggle => toggle
                .Property<bool>(HostProp.IsOn, (view, on) => view.IsToggled = on)
                .Reports<bool>(Switch.IsToggledProperty, HostEvent.Toggled,
                    (view, reported) => view.Toggled += (_, e) => reported(e.Value)));

        StateUIControls.Add("CheckBox",
            create: _ => new CheckBox(),
            realize: box => box
                .Property<bool>(HostProp.IsOn, (view, on) => view.IsChecked = on)
                .Reports<bool>(CheckBox.IsCheckedProperty, HostEvent.Toggled,
                    (view, reported) => view.CheckedChanged += (_, e) => reported(e.Value)));
    }

    /// <summary>
    /// What something says while it is happening: how far along, and whether
    /// anything is happening at all.
    /// </summary>
    /// <remarks>
    /// Their colour is the shared tier's <c>tint</c>, which
    /// <c>ComposedProperties</c> puts on whichever property each control keeps
    /// it in - so neither registration mentions it.
    /// </remarks>
    private static void Indicators()
    {
        StateUIControls.Add("ProgressBar",
            create: _ => new ProgressBar(),
            realize: bar => bar
                .Property<double>(HostProp.Progress, (view, progress) => view.Progress = progress));

        StateUIControls.Add("ActivityIndicator",
            create: _ => new ActivityIndicator(),
            realize: indicator => indicator
                .Property<bool>(HostProp.IsRunning, (view, running) => view.IsRunning = running));
    }
}
