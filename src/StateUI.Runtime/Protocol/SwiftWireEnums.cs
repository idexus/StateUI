// The far half of every closed vocabulary the wire carries: one enum per Swift
// enum, member for member, number for number.
//
// THE NUMBERS ARE THIS REPOSITORY'S, NEVER MAUI'S. A closed vocabulary crosses
// as a number rather than a spelling - wire version 8 - and it is tempting to
// let that number be MAUI's own, since most of these end up as a MAUI enum
// member. That would be wrong. MAUI's member numbers are MAUI's internal
// business: `FlexJustify` starts at 2, `PenLineCap.Round` is 2 while `.Square`
// is 1, `AbsoluteLayoutFlags.All` is -1 and `SafeAreaRegions.All` is 32768.
// None of that is promised to anybody, and a MAUI release that renumbered an
// enum would silently reinterpret every property on this wire carrying it - no
// error, no crash, just a different alignment. So the wire's numbers are ours,
// they are stable for ever, and SwiftValues TRANSLATES them onto MAUI's members
// BY NAME, one switch arm each. A jump table over a dense small integer is
// still far cheaper than the string hashing this replaced.
//
// The numbering is DECLARATION ORDER FROM 0, matching the Swift enum case for
// case; a bit set carries our bits from 1<<0 in declaration order, with every
// composite the OR of its parts - which is why nothing here is -1 or 32768.
// Nothing may be inserted among them, only appended: the number is the whole of
// what crosses.
//
// One file, one naming rule: `Swift` + the Swift type's name, its members the
// Swift cases PascalCased. The prefix is load-bearing rather than decoration -
// without it this file would declare a `LineBreakMode` beside
// `Microsoft.Maui.LineBreakMode` and every use of either would need qualifying
// - and it is the house prefix already, as `SwiftAct` and `SwiftNode` are. The
// rule is what lets `WireEnumTests` find each mirror by reflection and check it
// against the Swift declaration member for member, so a vocabulary added over
// there with no mirror over here FAILS rather than going unnoticed.
//
// The mirrors carry ONLY the numbers, which is why the members take the
// exemption the Swift tokens take: a member IS its name, and there is nothing
// to say about it here. Which MAUI member each one means is said in the
// converter that translates it, where the MAUI name appears literally and the
// compiler checks it.
//
// A file-level comment rather than a `<summary>` on a type, because there is no
// type here to put one on: the enums are top-level so that a use reads
// `SwiftLineBreakMode` rather than a carrier class and a dot, and an empty class
// existing only to hold documentation would be worse than this.

namespace StateUI.Runtime.Protocol;

/// <summary>Where a view sits in the space its layout gives it.</summary>
internal enum SwiftLayoutOptions
{
    Start = 0,
    Center = 1,
    End = 2,
    Fill = 3,
}

/// <summary>Where text sits within a control's own bounds.</summary>
internal enum SwiftTextAlignment
{
    Start = 0,
    Center = 1,
    End = 2,
}

/// <summary>What happens to text too long for its space.</summary>
internal enum SwiftLineBreakMode
{
    NoWrap = 0,
    WordWrap = 1,
    CharacterWrap = 2,
    HeadTruncation = 3,
    TailTruncation = 4,
    MiddleTruncation = 5,
}

/// <summary>Whether text is drawn as written or in one case throughout.</summary>
internal enum SwiftTextTransform
{
    None = 0,
    Default = 1,
    Lowercase = 2,
    Uppercase = 3,
}

/// <summary>Which keyboard a text input asks for.</summary>
internal enum SwiftKeyboard
{
    Default = 0,
    Plain = 1,
    Chat = 2,
    Email = 3,
    Numeric = 4,
    Telephone = 5,
    Text = 6,
    Url = 7,
}

/// <summary>What the keyboard's return key says.</summary>
internal enum SwiftReturnType
{
    Default = 0,
    Done = 1,
    Go = 2,
    Next = 3,
    Search = 4,
    Send = 5,
}

/// <summary>When an Entry shows the platform's clear button.</summary>
internal enum SwiftClearButtonVisibility
{
    Never = 0,
    WhileEditing = 1,
}

/// <summary>Which way a ScrollView scrolls.</summary>
internal enum SwiftScrollOrientation
{
    Vertical = 0,
    Horizontal = 1,
    Both = 2,
    Neither = 3,
}

/// <summary>How a FlyoutPage shows its two halves.</summary>
internal enum SwiftFlyoutLayoutBehavior
{
    Default = 0,
    Popover = 1,
    Split = 2,
    SplitOnLandscape = 3,
    SplitOnPortrait = 4,
}

/// <summary>How a page presented over the window covers the screen.</summary>
internal enum SwiftUIModalPresentationStyle
{
    FullScreen = 0,
    FormSheet = 1,
    Automatic = 2,
    PageSheet = 3,
    OverFullScreen = 4,
    Popover = 5,
}

/// <summary>How an Image fills the space it is given.</summary>
internal enum SwiftAspect
{
    AspectFit = 0,
    AspectFill = 1,
    Fill = 2,
    Center = 3,
}

/// <summary>Whether a scroll bar is shown, hidden, or left to the platform.</summary>
internal enum SwiftScrollBarVisibility
{
    Default = 0,
    Always = 1,
    Never = 2,
}

/// <summary>Whether an Editor grows with its text.</summary>
internal enum SwiftEditorAutoSizeOption
{
    Disabled = 0,
    TextChanges = 1,
}

/// <summary>Which way a FlexLayout's children run.</summary>
internal enum SwiftFlexDirection
{
    Row = 0,
    RowReverse = 1,
    Column = 2,
    ColumnReverse = 3,
}

/// <summary>Whether a line that runs out of room starts another.</summary>
internal enum SwiftFlexWrap
{
    NoWrap = 0,
    Wrap = 1,
    Reverse = 2,
}

/// <summary>How the spare room along a FlexLayout's direction is shared out.</summary>
internal enum SwiftFlexJustify
{
    Center = 0,
    Start = 1,
    End = 2,
    SpaceBetween = 3,
    SpaceAround = 4,
    SpaceEvenly = 5,
}

/// <summary>Where each child sits across the direction.</summary>
internal enum SwiftFlexAlignItems
{
    Stretch = 0,
    Center = 1,
    Start = 2,
    End = 3,
}

/// <summary>The same for whole lines, once the layout wraps.</summary>
internal enum SwiftFlexAlignContent
{
    Stretch = 0,
    Center = 1,
    Start = 2,
    End = 3,
    SpaceBetween = 4,
    SpaceAround = 5,
    SpaceEvenly = 6,
}

/// <summary>One child's answer to the layout's AlignItems.</summary>
internal enum SwiftFlexAlignSelf
{
    Auto = 0,
    Stretch = 1,
    Center = 2,
    Start = 3,
    End = 4,
}

/// <summary>Whether a FlexLayout places its children at all.</summary>
internal enum SwiftFlexPosition
{
    Relative = 0,
    Absolute = 1,
}

/// <summary>Whether a swipe reveals its items or runs the first of them.</summary>
internal enum SwiftSwipeMode
{
    Reveal = 0,
    Execute = 1,
}

/// <summary>What the open swipe items do once one of them has run.</summary>
internal enum SwiftSwipeBehaviorOnInvoked
{
    Auto = 0,
    Close = 1,
    RemainOpen = 2,
}

/// <summary>How the end of an open line is drawn.</summary>
internal enum SwiftPenLineCap
{
    Flat = 0,
    Round = 1,
    Square = 2,
}

/// <summary>How two segments of a line meet at a corner.</summary>
internal enum SwiftPenLineJoin
{
    Miter = 0,
    Bevel = 1,
    Round = 2,
}

/// <summary>What a shape does with the room it is given.</summary>
internal enum SwiftStretch
{
    None = 0,
    Fill = 1,
    Uniform = 2,
    UniformToFill = 3,
}

/// <summary>Which parts of a self-crossing outline count as inside it.</summary>
internal enum SwiftFillRule
{
    EvenOdd = 0,
    Nonzero = 1,
}

/// <summary>What one dot of an IndicatorView is drawn as.</summary>
internal enum SwiftIndicatorShape
{
    Circle = 0,
    Square = 1,
}

/// <summary>Where a toolbar item goes - on the bar, or behind the overflow.</summary>
internal enum SwiftToolbarItemOrder
{
    Default = 0,
    Primary = 1,
    Secondary = 2,
}

/// <summary>What one edge of a layout stays clear of on the unsafe strip.</summary>
internal enum SwiftSafeAreaRegions
{
    None = 0,
    SoftInput = 1,
    Container = 2,
    All = 3,
}

/// <summary>The curve an animation follows.</summary>
internal enum SwiftEasing
{
    Linear = 0,
    SinOut = 1,
    SinIn = 2,
    SinInOut = 3,
    CubicIn = 4,
    CubicOut = 5,
    CubicInOut = 6,
    BounceOut = 7,
    BounceIn = 8,
    SpringIn = 9,
    SpringOut = 10,
}

/// <summary>How the world is drawn - streets, photography, or both.</summary>
internal enum SwiftMapType
{
    Street = 0,
    Satellite = 1,
    Hybrid = 2,
}

/// <summary>Which side of a button's caption its picture is on.</summary>
internal enum SwiftButtonContentPosition
{
    Left = 0,
    Top = 1,
    Right = 2,
    Bottom = 3,
}

/// <summary>Bold, italic, both or neither.</summary>
[Flags]
internal enum SwiftFontAttributes
{
    None = 0,
    Bold = 1,
    Italic = 2,
}

/// <summary>Underlined, struck through, both or neither.</summary>
[Flags]
internal enum SwiftTextDecorations
{
    None = 0,
    Underline = 1,
    Strikethrough = 2,
}

/// <summary>Which ways a swipe went, or is listened for.</summary>
[Flags]
internal enum SwiftSwipeDirection
{
    Right = 1,
    Left = 2,
    Up = 4,
    Down = 8,
    All = 15,
}

/// <summary>
/// Which parts of a child's bounds an AbsoluteLayout reads as fractions.
/// </summary>
[Flags]
internal enum SwiftAbsoluteLayoutFlags
{
    None = 0,
    XProportional = 1,
    YProportional = 2,
    PositionProportional = 3,
    WidthProportional = 4,
    HeightProportional = 8,
    SizeProportional = 12,
    All = 15,
}

/// <summary>
/// Which of MAUI's three brushes a value list describes. The one vocabulary
/// numbered from 1: it crossed as a number two versions before the rule existed,
/// and both sides of a shipped format already say 1, 2, 3.
/// </summary>
internal enum SwiftBrushKind
{
    SolidColor = 1,
    LinearGradient = 2,
    RadialGradient = 3,
}

/// <summary>Which outline a Border draws.</summary>
internal enum SwiftStrokeShapeKind
{
    Rectangle = 0,
    RoundRectangle = 1,
    Ellipse = 2,
}

/// <summary>How an items view arranges its items.</summary>
internal enum SwiftItemsLayoutKind
{
    VerticalList = 0,
    HorizontalList = 1,
    VerticalGrid = 2,
    HorizontalGrid = 3,
}

/// <summary>Which sort of room a FlexLayout's child asks for.</summary>
internal enum SwiftFlexBasisKind
{
    Auto = 0,
    Relative = 1,
    Absolute = 2,
}

/// <summary>How much room a grid row or column takes.</summary>
internal enum SwiftGridLengthKind
{
    Absolute = 0,
    Star = 1,
    Auto = 2,
}

/// <summary>Which of the two things a WebView's source is.</summary>
internal enum SwiftWebViewSourceKind
{
    Url = 0,
    Html = 1,
}

/// <summary>Which of a SwipeView's four collections a set of items is.</summary>
internal enum SwiftSwipeSide
{
    Left = 0,
    Right = 1,
    Top = 2,
    Bottom = 3,
}

/// <summary>Where a drawn string sits across the width it is given.</summary>
internal enum SwiftHorizontalAlignment
{
    Left = 0,
    Center = 1,
    Right = 2,
    Justified = 3,
}

/// <summary>Where a drawn string sits down the height it is given.</summary>
internal enum SwiftVerticalAlignment
{
    Top = 0,
    Center = 1,
    Bottom = 2,
}

// The vocabularies below travel the OTHER WAY - the host reports one, Swift
// reads it - and they are the same rule read backwards: the host translates
// MAUI's member onto the mirror before writing it, so the number on the wire
// is ours in both directions and a MAUI renumbering cannot reach the payload
// a handler is given.

/// <summary>How far along a continuous gesture is.</summary>
internal enum SwiftGestureStatus
{
    Started = 0,
    Running = 1,
    Completed = 2,
    Canceled = 3,
}

/// <summary>How the battery is doing.</summary>
internal enum SwiftBatteryState
{
    Unknown = 0,
    Charging = 1,
    Discharging = 2,
    Full = 3,
    NotCharging = 4,
    NotPresent = 5,
}

/// <summary>Where the power is coming from.</summary>
internal enum SwiftBatteryPowerSource
{
    Unknown = 0,
    Battery = 1,
    Ac = 2,
    Usb = 3,
    Wireless = 4,
}

/// <summary>Whether the platform's battery saver is on.</summary>
internal enum SwiftEnergySaverStatus
{
    Unknown = 0,
    On = 1,
    Off = 2,
}

/// <summary>What the network can reach.</summary>
internal enum SwiftNetworkAccess
{
    Unknown = 0,
    None = 1,
    Local = 2,
    ConstrainedInternet = 3,
    Internet = 4,
}

/// <summary>One way the device is connected.</summary>
internal enum SwiftConnectionProfile
{
    Unknown = 0,
    Bluetooth = 1,
    Cellular = 2,
    Ethernet = 3,
    WiFi = 4,
}

/// <summary>Which way the screen is turned, coarsely.</summary>
internal enum SwiftDisplayOrientation
{
    Unknown = 0,
    Portrait = 1,
    Landscape = 2,
}

/// <summary>How far the screen is rotated from its natural position.</summary>
internal enum SwiftDisplayRotation
{
    Unknown = 0,
    Rotation0 = 1,
    Rotation90 = 2,
    Rotation180 = 3,
    Rotation270 = 4,
}

/// <summary>Which look the system asked for.</summary>
internal enum SwiftAppTheme
{
    Unspecified = 0,
    Light = 1,
    Dark = 2,
}

/// <summary>Whether this is real hardware.</summary>
internal enum SwiftDeviceType
{
    Unknown = 0,
    Physical = 1,
    Virtual = 2,
}

/// <summary>
/// The first day of a calendar week. The one mirror whose far member is .NET's
/// rather than MAUI's - <see cref="DayOfWeek"/> - and numbered here for the
/// same reason: that the two lists agree today is a coincidence, not a
/// contract.
/// </summary>
internal enum SwiftWeekday
{
    Sunday = 0,
    Monday = 1,
    Tuesday = 2,
    Wednesday = 3,
    Thursday = 4,
    Friday = 5,
    Saturday = 6,
}

/// <summary>Why a navigation happened.</summary>
internal enum SwiftWebNavigationEvent
{
    Unknown = 0,
    Back = 1,
    Forward = 2,
    NewPage = 3,
    Refresh = 4,
}

/// <summary>How a navigation ended.</summary>
internal enum SwiftWebNavigationResult
{
    Unknown = 0,
    Success = 1,
    Cancel = 2,
    Timeout = 3,
    Failure = 4,
}

/// <summary>What kind of machine the interface is on. Swift: DeviceIdiom.</summary>
internal enum SwiftDeviceIdiom
{
    Unknown = 0,
    Phone = 1,
    Tablet = 2,
    Desktop = 3,
    Tv = 4,
    Watch = 5,
}

/// <summary>Where a window stands in its lifecycle. Swift: WindowPhase.</summary>
internal enum SwiftWindowPhase
{
    Activated = 0,
    Deactivated = 1,
    Stopped = 2,
}
