// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

namespace StateUI.Runtime.Protocol;

/// <summary>
/// Every element type this runtime knows how to build - what the renderer's
/// dispatch switches on, resolved once when the session announces the name.
/// </summary>
/// <remarks>
/// <para>
/// <see cref="None"/> is a type this runtime has no case for: an application's
/// own registered control, drawn by the registry, or a type from a Swift side
/// newer than this host, drawn as the red marker. Either way the SPELLING is
/// still needed - to find the registration, and to name the type in the
/// marker - so <c>SwiftNode.TypeName</c> keeps it, exactly as
/// <c>SwiftCommand.Name</c> keeps an act's.
/// </para>
/// <para>
/// These numbers never cross the wire. A name travels as the number the
/// SESSION assigned it, and this side resolves that to a member as the
/// announcement is read; what is written here is a local dispatch token and
/// may be renumbered freely. What may NOT change is the pairing of member to
/// spelling, which <c>WireTokenTests</c> holds against Core/Tokens.swift.
/// </para>
/// <para>
/// No <c>&lt;summary&gt;</c> per member, and the type is internal so that none
/// is required: a token IS its name, so a comment could only restate it. The
/// Swift side takes the same exemption for the same reason, written into its
/// DocumentationTests by vocabulary name.
/// </para>
/// </remarks>
internal enum SwiftNodeType : ushort
{
    /// <summary>A name this runtime has no member for.</summary>
    None = 0,

    AbsoluteLayout = 1,
    ActivityIndicator = 2,
    Application = 3,
    Border = 4,
    BoxView = 5,
    Button = 6,
    CheckBox = 8,
    Content = 9,
    ContentPage = 10,
    ContextFlyout = 11,
    DatePicker = 12,
    Editor = 13,
    Ellipse = 14,
    Entry = 16,
    FlexLayout = 17,
    FlyoutPage = 18,
    FormattedString = 19,
    GraphicsView = 20,
    Grid = 21,
    HorizontalStackLayout = 22,
    Image = 23,
    ImageButton = 24,
    IndicatorView = 25,
    Label = 26,
    LeadingContent = 27,
    Line = 28,
    Map = 29,
    MenuBarItem = 30,
    MenuBarItems = 31,
    MenuFlyoutItem = 32,
    MenuFlyoutSeparator = 33,
    MenuFlyoutSubItem = 34,
    ModalStack = 35,
    NavigationPage = 36,
    NavigationPageTitleView = 37,
    Path = 38,
    Picker = 39,
    Pin = 40,
    Polygon = 41,
    Polyline = 42,
    ProgressBar = 43,
    RadioButton = 44,
    Rectangle = 45,
    RefreshView = 46,
    RoundRectangle = 47,
    ScrollView = 48,
    SearchBar = 49,
    Setters = 50,
    Slider = 51,
    Span = 52,
    Stepper = 53,
    SwipeItem = 54,
    SwipeItems = 55,
    SwipeView = 56,
    Switch = 57,
    TabbedPage = 58,
    TimePicker = 59,
    TitleBar = 60,
    ToolbarItem = 61,
    ToolbarItems = 62,
    TrailingContent = 63,
    VerticalStackLayout = 64,
    VisualState = 65,
    WebView = 66,
    Window = 67,
    Composed = 68,
    Memoized = 69,
}
