// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The names this library speaks, as TOKENS.
//
// Everything the wire names - a node's type, a property key, an event, an act
// - is a closed vocabulary with one open edge: an application can add its own
// entries. So each vocabulary is a STRUCT holding the name, with the library's
// own entries as static members, and nothing else inside. A token is a NAME
// and only a name: which NUMBER it rides under is the transport's business,
// settled per session in Core/Wire.swift - the first message that uses a name
// announces it, and both sides speak the number from then on. That is what
// makes the library's tokens and an application's the same thing: there is no
// reserved pool to collide with and no table to be missing from.
//
// An application extends a vocabulary exactly the way the library declares it:
//
//     extension Act {
//         static let batteryLevel = Act("Gallery.BatteryLevel")
//     }
//
// and every token type is `ExpressibleByStringLiteral`, so the one-off spelling
// still reads naturally where a declaration would be ceremony:
//
//     Node(type: "ColorWheel")
//
// The SOURCES of this library write only the static members - `.label`,
// `.fontSize`, `.textChanged`, `.displayAlertAsync` - and the guard test in
// WireFormatTests names any file that spells a name out instead. This file is
// deliberately the one place the spellings exist.

/// The kind of element a `Node` describes - MAUI's class name ("Label",
/// "VerticalStackLayout"), or a slot or structure name this library defines,
/// or an application's own control.
///
/// A token, not an enum, so an application can name a control the library has
/// never heard of and drop it into any builder - the renderer draws an unknown
/// type as a red marker rather than failing, which is what keeps a lagging
/// host visible without hiding the rest of the interface.
public struct NodeType: Hashable, Comparable, Sendable,
    ExpressibleByStringLiteral, CustomStringConvertible {
    /// The type's name - the MAUI class name, or the application's own.
    public let name: String

    /// A node type from its name, which is how an application declares one:
    ///
    ///     extension NodeType {
    ///         static let colorWheel = NodeType("ColorWheel")
    ///     }
    public init(_ name: String) {
        self.name = name
    }

    /// The literal form, so `Node(type: "ColorWheel")` reads naturally.
    public init(stringLiteral value: String) {
        self.init(value)
    }

    /// The name, so an interpolated diagnostic prints it plainly.
    public var description: String { name }

    /// Name order, so a list of types reads sorted in a test or a dump.
    public static func < (lhs: NodeType, rhs: NodeType) -> Bool {
        lhs.name < rhs.name
    }
}

/// One property of a control - the MAUI property name camelCased ("fontSize",
/// "horizontalOptions"), the same spelling the matching modifier writes.
///
/// Comparable by name because a message writes a node's properties in name
/// order - that is what makes two renders of the same tree byte-identical.
public struct Prop: Hashable, Comparable, Sendable, ExpressibleByStringLiteral,
    CustomStringConvertible {
    /// The property's name - the MAUI property name camelCased.
    public let name: String

    /// A property key from its name, which is how an application reaches a
    /// property of its own control:
    ///
    ///     extension Prop {
    ///         static let hue = Prop("hue")
    ///     }
    public init(_ name: String) {
        self.name = name
    }

    /// The literal form, so `setValue("fontSize", .number(20))` still reads.
    public init(stringLiteral value: String) {
        self.init(value)
    }

    /// The name, so an interpolated diagnostic prints it plainly.
    public var description: String { name }

    /// Name order - the order a message writes properties in.
    public static func < (lhs: Prop, rhs: Prop) -> Bool {
        lhs.name < rhs.name
    }
}

extension Prop {
    /// The properties whose loss the host cannot UNDO, so an element that
    /// stops describing one is built again instead.
    ///
    /// Everything else this library writes lands on a MAUI BindableProperty,
    /// which the host clears by name: a modifier that stops being written puts
    /// its property back to MAUI's own default, and the control - with its
    /// handlers, and the `@State` of every view under it - stays where it is.
    /// These few have no such property to clear:
    ///
    /// - a gesture's settings belong to the recognizer carrying them rather
    ///   than to the view;
    /// - a list's items are data, which no default answers for;
    /// - a toolbar item's `order` and `priority`, and a swipe's `side`, are
    ///   not bindable properties at all - two are plain properties on MAUI's
    ///   own class, and the third says which of a SwipeView's four collections
    ///   the items are, which the renderer decides rather than writes;
    /// - a CHOICE must not move the reader when it stops being described, and
    ///   clearing one would: back to the first tab, the first item, the top of
    ///   the list.
    ///
    /// `EveryPropertyThatCannotBeClearedIsNamedOnBothSides` READS this
    /// declaration and walks every fixture against the host's table, so a
    /// property added on either side without the other is named by a test
    /// rather than found on a screen.
    static let notCleared: Set<Prop> = [
        .numberOfTapsRequired, .swipeDirection, .swipeThreshold, .panTouchCount,
        .dragText, .canDrag, .allowDrop,
        .itemsSource,
        .selectedIndex, .currentPage,
        .order, .priority, .side,
        .region,
        // A layout that stops FOLLOWING its channels: what the host holds is
        // a registration rather than a property, so there is nothing to put
        // back - the element is described again instead, and the registration
        // goes with the control it hung off.
        .channels, .channelRule,
    ]

    /// Which KIND of value this property is, for a motion that names some
    /// rather than all of them.
    ///
    /// The groups are `MotionValues`, and each one's `///` says exactly what it
    /// covers. A property in NONE of them - a progress, a slider's value, a
    /// dash offset - is answered by the plain `.motion(_:)` and by `.all`,
    /// which is what almost every motion there is says; naming every property
    /// in a group would be a second list of the whole vocabulary, kept in step
    /// by hand, for an answer nobody asked a different question about.
    ///
    /// A COLOUR is not in here at all: it is recognized by its VALUE, so a
    /// colour added to this library later is in the group the day it arrives.
    var moving: MotionValues {
        Prop.kinds[self] ?? []
    }

    /// The table `moving` reads. One property is in one group.
    private static let kinds: [Prop: MotionValues] = {
        var kinds: [Prop: MotionValues] = [.opacity: .opacity]

        for property in [Prop.widthRequest, .minimumWidthRequest, .maximumWidthRequest, .width] {
            kinds[property] = .width
        }

        for property in [Prop.heightRequest, .minimumHeightRequest, .maximumHeightRequest, .height] {
            kinds[property] = .height
        }

        // The lengths a view's own shape is drawn with go with its size: they
        // are how big it is, said about its corners and its outline.
        for property in [Prop.cornerRadius, .strokeThickness, .borderWidth, .radiusX, .radiusY] {
            kinds[property] = .size
        }

        for property in [Prop.translationX, .translationY] {
            kinds[property] = .place
        }

        for property in [Prop.scale, .scaleX, .scaleY, .rotation, .rotationX, .rotationY,
                         .anchorX, .anchorY] {
            kinds[property] = .transform
        }

        for property in [Prop.padding, .margin, .spacing, .rowSpacing, .columnSpacing] {
            kinds[property] = .spacing
        }

        for property in [Prop.fontSize, .lineHeight, .characterSpacing] {
            kinds[property] = .text
        }

        return kinds
    }()

    /// The properties that NEVER travel, however much their value looks like a
    /// number a control could be carried through.
    ///
    /// A value moves when it changes - that is the default - and these are the
    /// ones where there is no such thing as half way. Four kinds:
    ///
    /// - a PLACE or a COUNT: which tab, which item, which row of a grid, how
    ///   many dots, where the caret is. Nothing walks a whole number, and a
    ///   list that spent a fifth of a second passing through item 3.5 would be
    ///   describing something that does not exist;
    /// - a LAW a scroller obeys: how far apart its stops are, how much of a
    ///   throw it keeps, how many stops one release may cross. These are read
    ///   as a release is decided, and a law that was still arriving would
    ///   decide it differently every frame;
    /// - a RANGE or a REGION: what a slider's ends are, where a map is
    ///   looking. Both are answered by a method or a redraw rather than by a
    ///   value the screen shows on the way;
    /// - a PLACEMENT: where a child sits inside an AbsoluteLayout. It looks
    ///   like four travelling numbers and is one of the few things that must
    ///   not be: the host places children itself, from what it measured, and a
    ///   placement still arriving would be re-answered every frame. What
    ///   carries a child from one place to the next is the layout's own
    ///   motion - see Core/Wire.swift, Field.motion.
    ///
    /// The host asks the same question again on its own side - a property with
    /// no MAUI property behind it, or a value with no half-way, is assigned -
    /// so this list is what keeps the bytes off the wire rather than what
    /// keeps the picture right. `testAPlaceOrACountNeverTravels` holds it.
    static let unmoved: Set<Prop> = [
        .count, .currentPage, .cursorPosition, .selectionLength, .maxLength, .maxLines,
        .gridColumn, .gridColumnSpan, .gridRow, .gridRowSpan, .zIndex,
        .order, .priority, .flexLayoutOrder, .position, .selectedIndex,
        .numberOfTapsRequired, .panTouchCount, .maximumVisible,
        .snapsAtMost, .snapInterval, .snapFrom, .scrollMomentum, .scrollStep,
        .increment, .minimum, .maximum, .swipeThreshold,
        .points, .strokeDashArray, .region, .location,
        .absoluteLayoutBounds, .absoluteLayoutFlags,
        .channels, .channelRule, .scrollXChannel, .scrollYChannel,
        .panXChannel, .panYChannel,
    ]
}

/// One event a control can raise - the MAUI event name camelCased
/// ("textChanged", "clicked").
///
/// Comparable by name because a message writes a node's handlers in name
/// order, exactly as it writes the properties.
public struct Event: Hashable, Comparable, Sendable, ExpressibleByStringLiteral,
    CustomStringConvertible {
    /// The event's name - the MAUI event name camelCased.
    public let name: String

    /// An event from its name, which is how an application hears an event of
    /// its own control:
    ///
    ///     extension Event {
    ///         static let hueChanged = Event("hueChanged")
    ///     }
    public init(_ name: String) {
        self.name = name
    }

    /// The literal form, so `onEvent("hueChanged") { _ in }` still reads.
    public init(stringLiteral value: String) {
        self.init(value)
    }

    /// The name, so an interpolated diagnostic prints it plainly.
    public var description: String { name }

    /// Name order - the order a message writes handlers in.
    public static func < (lhs: Event, rhs: Event) -> Bool {
        lhs.name < rhs.name
    }
}

/// One act the host can perform - the MAUI method camelCased
/// ("displayAlertAsync"), or an application's own registered function.
///
/// The host performs what it has a case - or a registration - for; asking for
/// anything else throws with the host's "unknown command" reason, which is
/// what makes a misspelled name a reported failure rather than a silence.
///
/// An application's own act shares this one flat vocabulary, and the library's
/// case is consulted first, so a registration can never shadow one of these.
/// Prefixing an application's names with its own (`"Gallery.BatteryLevel"`) is
/// what keeps the two sets from meeting at all.
public struct Act: Hashable, Sendable, ExpressibleByStringLiteral,
    CustomStringConvertible {
    /// The act's name - the MAUI method camelCased, or the application's
    /// registered one.
    public let name: String

    /// An act from its name, which is how an application names a C# function
    /// it registered with the host - see `stateUICall`:
    ///
    ///     extension Act {
    ///         static let batteryLevel = Act("Gallery.BatteryLevel")
    ///     }
    public init(_ name: String) {
        self.name = name
    }

    /// The literal form, so `stateUICall("Gallery.BatteryLevel", …)` still reads.
    public init(stringLiteral value: String) {
        self.init(value)
    }

    /// The name, so an interpolated diagnostic prints it plainly.
    public var description: String { name }
}

// MARK: - The library's own vocabulary
//
// One member per name the sources write, nothing else. A new control, property
// or event starts here - the member IS the registration, there is no table to
// keep in step and no number to reserve.
//
// PUBLIC, so an application writes what the library writes:
// `.onEvent(.pinchUpdated)` rather than `.onEvent("pinchUpdated")`, which
// spells a name out by hand - the very thing `testTheSourcesSpellNoNames`
// forbids these sources from doing. One vocabulary, or the rule is a privilege
// rather than a rule.
//
// THE STRING IS THE MEMBER'S OWN NAME, always: `Prop("fontSize")` under
// `fontSize`, `NodeType("Label")` under `label` - capitalized for a node type,
// because a node type is a CLASS name and every other vocabulary is a member
// name. `testEveryTokenIsSpelledLikeItsMember` says so and names any that
// drifts, which is what leaves nothing to remember and nothing to look up: the
// declaration cannot lie about what goes on the wire.
//
// A node type, property or event carries no `///` - the one exemption in the
// library, taken deliberately and written into DocumentationTests: the token
// IS the name, so a comment could only restate it, while what the name MEANS
// belongs on the modifier an author actually types. Hundreds of restatements
// would be the kind of documentation that rots without anyone noticing.
//
// An ACT is the exception to the exemption and says which MAUI method it
// stands for, because that is the one thing its name does not carry.
extension NodeType {
    /// The elements that PLACE their children - the ones where a child's
    /// position is worked out on the host, from what it measured, rather than
    /// written as a property.
    ///
    /// It is the one list that decides which elements say how their children
    /// TRAVEL to a new place, since there is no property for such a motion to
    /// ride beside. Everything else puts its one child where it goes and has
    /// nothing to arrange.
    static let places: Set<NodeType> = [
        .verticalStackLayout, .horizontalStackLayout, .grid, .absoluteLayout, .flexLayout,
    ]

    /// The elements that always say how they move things - the ones that PLACE
    /// children, and the APPLICATION, which says what everything else
    /// inherits.
    ///
    /// A control also says it when its VISUAL STATES move a value, which is
    /// decided per node rather than per type: a state is a child, and any
    /// control may have one. See `Differ.element`.
    ///
    /// One number for a whole application rather than one per control: a
    /// control that travels the way everything else does says nothing at all,
    /// on any message, ever.
    static let saysMotion: Set<NodeType> = places.union([.application])
}

public extension NodeType {
    static let absoluteLayout = NodeType("AbsoluteLayout")
    static let activityIndicator = NodeType("ActivityIndicator")
    static let application = NodeType("Application")
    static let border = NodeType("Border")
    static let boxView = NodeType("BoxView")
    static let button = NodeType("Button")
    static let checkBox = NodeType("CheckBox")
    static let content = NodeType("Content")
    static let contentPage = NodeType("ContentPage")
    static let contextFlyout = NodeType("ContextFlyout")
    static let datePicker = NodeType("DatePicker")
    static let editor = NodeType("Editor")
    static let ellipse = NodeType("Ellipse")
    static let entry = NodeType("Entry")
    static let flexLayout = NodeType("FlexLayout")
    static let flyoutPage = NodeType("FlyoutPage")
    static let formattedString = NodeType("FormattedString")
    static let graphicsView = NodeType("GraphicsView")
    static let grid = NodeType("Grid")
    static let horizontalStackLayout = NodeType("HorizontalStackLayout")
    static let image = NodeType("Image")
    static let imageButton = NodeType("ImageButton")
    static let indicatorView = NodeType("IndicatorView")
    static let label = NodeType("Label")
    static let leadingContent = NodeType("LeadingContent")
    static let line = NodeType("Line")
    static let map = NodeType("Map")
    static let menuBarItem = NodeType("MenuBarItem")
    static let menuBarItems = NodeType("MenuBarItems")
    static let menuFlyoutItem = NodeType("MenuFlyoutItem")
    static let menuFlyoutSeparator = NodeType("MenuFlyoutSeparator")
    static let menuFlyoutSubItem = NodeType("MenuFlyoutSubItem")
    static let modalStack = NodeType("ModalStack")
    static let navigationPage = NodeType("NavigationPage")
    static let navigationPageTitleView = NodeType("NavigationPageTitleView")
    static let path = NodeType("Path")
    static let picker = NodeType("Picker")
    static let pin = NodeType("Pin")
    static let polygon = NodeType("Polygon")
    static let polyline = NodeType("Polyline")
    static let progressBar = NodeType("ProgressBar")
    static let radioButton = NodeType("RadioButton")
    static let rectangle = NodeType("Rectangle")
    static let refreshView = NodeType("RefreshView")
    static let roundRectangle = NodeType("RoundRectangle")
    static let scrollView = NodeType("ScrollView")
    static let searchBar = NodeType("SearchBar")
    static let setters = NodeType("Setters")
    static let slider = NodeType("Slider")
    static let span = NodeType("Span")
    static let stepper = NodeType("Stepper")
    static let swipeItem = NodeType("SwipeItem")
    static let swipeItems = NodeType("SwipeItems")
    static let swipeView = NodeType("SwipeView")
    static let `switch` = NodeType("Switch")
    static let tabbedPage = NodeType("TabbedPage")
    static let timePicker = NodeType("TimePicker")
    static let titleBar = NodeType("TitleBar")
    static let toolbarItem = NodeType("ToolbarItem")
    static let toolbarItems = NodeType("ToolbarItems")
    static let trailingContent = NodeType("TrailingContent")
    static let verticalStackLayout = NodeType("VerticalStackLayout")
    static let visualState = NodeType("VisualState")
    static let webView = NodeType("WebView")
    static let window = NodeType("Window")

    // The differ's two placeholders - expanded before anything is sent,
    // so neither ever crosses the boundary. See Core/Stateful.swift and
    // Core/Memo.swift.
    static let composed = NodeType("Composed")
    static let memoized = NodeType("Memoized")
}

public extension Prop {
    static let absoluteLayoutBounds = Prop("absoluteLayoutBounds")
    static let absoluteLayoutFlags = Prop("absoluteLayoutFlags")
    static let address = Prop("address")
    static let alignContent = Prop("alignContent")
    static let alignItems = Prop("alignItems")
    static let allowDrop = Prop("allowDrop")
    static let anchorX = Prop("anchorX")
    static let anchorY = Prop("anchorY")
    static let aspect = Prop("aspect")
    static let autoSize = Prop("autoSize")
    static let background = Prop("background")
    static let backgroundColor = Prop("backgroundColor")
    static let backgroundImageSource = Prop("backgroundImageSource")
    static let barBackground = Prop("barBackground")
    static let barBackgroundColor = Prop("barBackgroundColor")
    static let barTextColor = Prop("barTextColor")
    static let borderColor = Prop("borderColor")
    static let borderWidth = Prop("borderWidth")
    static let cancelButtonColor = Prop("cancelButtonColor")
    static let canDrag = Prop("canDrag")
    static let cascadeInputTransparent = Prop("cascadeInputTransparent")
    static let characterSpacing = Prop("characterSpacing")
    static let clearButtonVisibility = Prop("clearButtonVisibility")
    static let color = Prop("color")
    static let columnDefinitions = Prop("columnDefinitions")
    static let columnSpacing = Prop("columnSpacing")
    static let content = Prop("content")
    static let contentLayout = Prop("contentLayout")
    static let cornerRadius = Prop("cornerRadius")
    static let count = Prop("count")
    static let currentPage = Prop("currentPage")
    /// This library's own: the id the arithmetic a layout follows its
    /// channels with was registered under.
    static let channelRule = Prop("channelRule")

    /// This library's own: the channels this layout follows, by the numbers
    /// they ride on.
    static let channels = Prop("channels")

    static let cursorPosition = Prop("cursorPosition")
    static let data = Prop("data")
    static let date = Prop("date")
    static let direction = Prop("direction")
    static let dragText = Prop("dragText")
    static let drawable = Prop("drawable")
    static let fill = Prop("fill")
    static let fillRule = Prop("fillRule")
    static let flexLayoutAlignSelf = Prop("flexLayoutAlignSelf")
    static let flexLayoutBasis = Prop("flexLayoutBasis")
    static let flexLayoutGrow = Prop("flexLayoutGrow")
    static let flexLayoutOrder = Prop("flexLayoutOrder")
    static let flexLayoutShrink = Prop("flexLayoutShrink")
    static let flowDirection = Prop("flowDirection")
    static let flyoutLayoutBehavior = Prop("flyoutLayoutBehavior")
    static let fontAttributes = Prop("fontAttributes")
    static let fontAutoScalingEnabled = Prop("fontAutoScalingEnabled")
    static let fontFamily = Prop("fontFamily")
    static let fontSize = Prop("fontSize")
    static let foregroundColor = Prop("foregroundColor")
    static let format = Prop("format")
    static let gridColumn = Prop("gridColumn")
    static let gridColumnSpan = Prop("gridColumnSpan")
    static let gridRow = Prop("gridRow")
    static let gridRowSpan = Prop("gridRowSpan")
    static let group = Prop("group")
    static let groupName = Prop("groupName")
    static let height = Prop("height")
    static let heightRequest = Prop("heightRequest")
    static let hideSingle = Prop("hideSingle")
    static let hideSoftInputOnTapped = Prop("hideSoftInputOnTapped")
    static let horizontalOptions = Prop("horizontalOptions")
    static let horizontalScrollBarVisibility = Prop("horizontalScrollBarVisibility")
    static let horizontalTextAlignment = Prop("horizontalTextAlignment")
    static let icon = Prop("icon")
    static let iconImageSource = Prop("iconImageSource")
    static let imageSource = Prop("imageSource")
    static let increment = Prop("increment")
    static let indicatorColor = Prop("indicatorColor")
    static let indicatorSize = Prop("indicatorSize")
    static let indicatorsShape = Prop("indicatorsShape")
    static let inputTransparent = Prop("inputTransparent")
    static let isAnimationPlaying = Prop("isAnimationPlaying")
    static let isBusy = Prop("isBusy")
    static let isChecked = Prop("isChecked")
    static let isClippedToBounds = Prop("isClippedToBounds")
    static let isDestructive = Prop("isDestructive")
    static let isEnabled = Prop("isEnabled")
    static let isGestureEnabled = Prop("isGestureEnabled")
    static let isMaximizable = Prop("isMaximizable")
    static let isMinimizable = Prop("isMinimizable")
    static let isOpaque = Prop("isOpaque")
    static let isOpen = Prop("isOpen")
    static let isPassword = Prop("isPassword")
    static let isPresented = Prop("isPresented")
    static let isReadOnly = Prop("isReadOnly")
    static let isRefreshEnabled = Prop("isRefreshEnabled")
    static let isRefreshing = Prop("isRefreshing")
    static let isRunning = Prop("isRunning")
    static let isScrollEnabled = Prop("isScrollEnabled")
    static let isShowingUser = Prop("isShowingUser")
    static let isSpellCheckEnabled = Prop("isSpellCheckEnabled")
    static let isTextPredictionEnabled = Prop("isTextPredictionEnabled")
    static let isToggled = Prop("isToggled")
    static let isTrafficEnabled = Prop("isTrafficEnabled")
    static let isVisible = Prop("isVisible")
    static let isZoomEnabled = Prop("isZoomEnabled")
    static let itemsSource = Prop("itemsSource")
    static let justifyContent = Prop("justifyContent")
    static let keyboard = Prop("keyboard")
    static let label = Prop("label")
    static let lineBreakMode = Prop("lineBreakMode")
    static let lineHeight = Prop("lineHeight")
    static let location = Prop("location")
    static let mapType = Prop("mapType")
    static let margin = Prop("margin")
    static let maximum = Prop("maximum")
    static let maximumDate = Prop("maximumDate")
    static let maximumHeight = Prop("maximumHeight")
    static let maximumHeightRequest = Prop("maximumHeightRequest")
    static let maximumTrackColor = Prop("maximumTrackColor")
    static let maximumVisible = Prop("maximumVisible")
    static let maximumWidth = Prop("maximumWidth")
    static let maximumWidthRequest = Prop("maximumWidthRequest")
    static let maxLength = Prop("maxLength")
    static let maxLines = Prop("maxLines")
    static let minimum = Prop("minimum")
    static let minimumDate = Prop("minimumDate")
    static let minimumHeight = Prop("minimumHeight")
    static let minimumHeightRequest = Prop("minimumHeightRequest")
    static let minimumTrackColor = Prop("minimumTrackColor")
    static let minimumWidth = Prop("minimumWidth")
    static let minimumWidthRequest = Prop("minimumWidthRequest")
    static let modalPresentationStyle = Prop("modalPresentationStyle")
    static let mode = Prop("mode")
    static let name = Prop("name")
    static let navigationPageBackButtonTitle = Prop("navigationPageBackButtonTitle")
    static let navigationPageHasBackButton = Prop("navigationPageHasBackButton")
    static let navigationPageHasNavigationBar = Prop("navigationPageHasNavigationBar")
    static let navigationPageIconColor = Prop("navigationPageIconColor")
    static let navigationPageTitleIconImageSource = Prop("navigationPageTitleIconImageSource")
    static let numberOfTapsRequired = Prop("numberOfTapsRequired")
    static let offColor = Prop("offColor")
    static let onColor = Prop("onColor")
    static let opacity = Prop("opacity")
    static let order = Prop("order")
    static let orientation = Prop("orientation")
    static let padding = Prop("padding")
    static let panTouchCount = Prop("panTouchCount")

    /// This library's own: the channel a drag's distance ACROSS is written
    /// into, by the number it rides on.
    static let panXChannel = Prop("panXChannel")

    /// This library's own: the channel a drag's distance DOWN is written
    /// into, by the number it rides on.
    static let panYChannel = Prop("panYChannel")
    static let placeholder = Prop("placeholder")
    static let placeholderColor = Prop("placeholderColor")
    static let points = Prop("points")
    static let position = Prop("position")
    static let priority = Prop("priority")
    static let progress = Prop("progress")
    static let progressColor = Prop("progressColor")
    static let radiusX = Prop("radiusX")
    static let radiusY = Prop("radiusY")
    static let refreshColor = Prop("refreshColor")
    static let region = Prop("region")
    static let renderTransform = Prop("renderTransform")
    static let returnType = Prop("returnType")
    static let rotation = Prop("rotation")
    static let rotationX = Prop("rotationX")
    static let rotationY = Prop("rotationY")
    static let rowDefinitions = Prop("rowDefinitions")
    static let rowSpacing = Prop("rowSpacing")
    static let safeAreaEdges = Prop("safeAreaEdges")
    static let scale = Prop("scale")
    static let scaleX = Prop("scaleX")
    static let scaleY = Prop("scaleY")
    static let scrollMomentum = Prop("scrollMomentum")

    /// This library's own: the channel the offset ACROSS reports into, by
    /// the number it rides on.
    static let scrollXChannel = Prop("scrollXChannel")

    /// This library's own: the channel the offset DOWN reports into, by the
    /// number it rides on.
    static let scrollYChannel = Prop("scrollYChannel")
    static let scrollStep = Prop("scrollStep")
    static let searchIconColor = Prop("searchIconColor")
    static let selectedIndex = Prop("selectedIndex")
    static let selectedIndicatorColor = Prop("selectedIndicatorColor")
    static let selectedTabColor = Prop("selectedTabColor")
    static let selectionLength = Prop("selectionLength")
    static let side = Prop("side")
    static let snapFrom = Prop("snapFrom")
    static let snapInterval = Prop("snapInterval")
    static let snapsAtMost = Prop("snapsAtMost")
    static let source = Prop("source")
    static let spacing = Prop("spacing")
    static let stroke = Prop("stroke")
    static let strokeDashArray = Prop("strokeDashArray")
    static let strokeDashOffset = Prop("strokeDashOffset")
    static let strokeLineCap = Prop("strokeLineCap")
    static let strokeLineJoin = Prop("strokeLineJoin")
    static let strokeMiterLimit = Prop("strokeMiterLimit")
    static let strokeShape = Prop("strokeShape")
    static let strokeThickness = Prop("strokeThickness")
    static let style = Prop("style")
    static let subtitle = Prop("subtitle")
    static let swipeBehaviorOnInvoked = Prop("swipeBehaviorOnInvoked")
    static let swipeDirection = Prop("swipeDirection")
    static let swipeThreshold = Prop("swipeThreshold")
    static let text = Prop("text")
    static let textColor = Prop("textColor")
    static let textDecorations = Prop("textDecorations")
    static let textTransform = Prop("textTransform")
    static let textType = Prop("textType")
    static let threshold = Prop("threshold")
    static let thumbColor = Prop("thumbColor")
    static let thumbImageSource = Prop("thumbImageSource")
    static let time = Prop("time")
    static let title = Prop("title")
    static let titleColor = Prop("titleColor")
    static let translationX = Prop("translationX")
    static let translationY = Prop("translationY")
    static let type = Prop("type")
    static let unselectedTabColor = Prop("unselectedTabColor")
    static let userAgent = Prop("userAgent")

    /// Whether a page keeps its content out of the bars. C#: the
    /// `Page.UseSafeArea` iOS platform-specific.
    static let useSafeArea = Prop("useSafeArea")
    static let value = Prop("value")
    static let verticalOptions = Prop("verticalOptions")
    static let verticalScrollBarVisibility = Prop("verticalScrollBarVisibility")
    static let verticalTextAlignment = Prop("verticalTextAlignment")
    static let width = Prop("width")
    static let widthRequest = Prop("widthRequest")
    static let wrap = Prop("wrap")
    static let x = Prop("x")
    static let x1 = Prop("x1")
    static let x2 = Prop("x2")
    static let y = Prop("y")
    static let y1 = Prop("y1")
    static let y2 = Prop("y2")
    static let zIndex = Prop("zIndex")
}

public extension Event {
    static let activated = Event("activated")
    static let appearing = Event("appearing")
    static let canGoBackChanged = Event("canGoBackChanged")
    static let canGoForwardChanged = Event("canGoForwardChanged")
    static let checkedChanged = Event("checkedChanged")
    static let clicked = Event("clicked")
    static let closed = Event("closed")
    static let completed = Event("completed")
    static let created = Event("created")
    static let creatingWindow = Event("creatingWindow")
    static let currentPageChanged = Event("currentPageChanged")
    static let dateSelected = Event("dateSelected")
    static let deactivated = Event("deactivated")
    static let destroying = Event("destroying")
    static let disappearing = Event("disappearing")
    static let dragCompleted = Event("dragCompleted")
    static let dragInteraction = Event("dragInteraction")
    static let dragLeave = Event("dragLeave")
    static let dragOver = Event("dragOver")
    static let dragStarted = Event("dragStarted")
    static let dragStarting = Event("dragStarting")
    static let drop = Event("drop")
    static let dropCompleted = Event("dropCompleted")
    static let endInteraction = Event("endInteraction")
    static let frameChanged = Event("frameChanged")
    static let heightChanged = Event("heightChanged")
    static let infoWindowClicked = Event("infoWindowClicked")
    static let invoked = Event("invoked")
    static let isFocusedChanged = Event("isFocusedChanged")
    static let isPresentedChanged = Event("isPresentedChanged")
    static let isRefreshingChanged = Event("isRefreshingChanged")
    static let loaded = Event("loaded")
    static let mapClicked = Event("mapClicked")
    static let markerClicked = Event("markerClicked")
    static let modalPopped = Event("modalPopped")
    static let navigated = Event("navigated")
    static let navigatedFrom = Event("navigatedFrom")
    static let navigatedTo = Event("navigatedTo")
    static let navigating = Event("navigating")
    static let navigatingFrom = Event("navigatingFrom")
    static let opened = Event("opened")
    static let panUpdated = Event("panUpdated")
    static let pinchUpdated = Event("pinchUpdated")
    static let pointerEntered = Event("pointerEntered")
    static let pointerExited = Event("pointerExited")
    static let pointerMoved = Event("pointerMoved")
    static let pointerPressed = Event("pointerPressed")
    static let pointerReleased = Event("pointerReleased")
    static let popped = Event("popped")
    static let pressed = Event("pressed")
    static let processTerminated = Event("processTerminated")
    static let refreshing = Event("refreshing")
    static let released = Event("released")
    static let resumed = Event("resumed")
    static let scrollStopped = Event("scrollStopped")
    static let scrollXChanged = Event("scrollXChanged")
    static let scrollYChanged = Event("scrollYChanged")
    static let searchButtonPressed = Event("searchButtonPressed")
    static let selectedIndexChanged = Event("selectedIndexChanged")
    static let snapItemChanged = Event("snapItemChanged")
    static let startInteraction = Event("startInteraction")
    static let stopped = Event("stopped")
    static let swipeChanging = Event("swipeChanging")
    static let swiped = Event("swiped")
    static let swipeEnded = Event("swipeEnded")
    static let swipeStarted = Event("swipeStarted")
    static let tapped = Event("tapped")
    static let textChanged = Event("textChanged")
    static let timeSelected = Event("timeSelected")
    static let toggled = Event("toggled")
    static let unloaded = Event("unloaded")
    static let valueChanged = Event("valueChanged")
    static let visualStateChanged = Event("visualStateChanged")
    static let widthChanged = Event("widthChanged")
}

public extension Act {
    /// VisualElement.Focus.
    static let focus = Act("focus")

    /// VisualElement.Unfocus.
    static let unfocus = Act("unfocus")

    /// WebView.GoBack.
    static let goBack = Act("goBack")

    /// WebView.GoForward.
    static let goForward = Act("goForward")

    /// WebView.Reload.
    static let reload = Act("reload")

    /// WebView.EvaluateJavaScriptAsync.
    static let evaluateJavaScriptAsync = Act("evaluateJavaScriptAsync")

    /// Map.MoveToRegion.
    static let moveToRegion = Act("moveToRegion")

    /// ScrollView.ScrollToAsync.
    static let scrollToAsync = Act("scrollToAsync")

    /// SoftInput.Hide - this library's own, MAUI having no method.
    static let hideSoftInput = Act("hideSoftInput")

    /// This library's own: ends a flight where it stands. Animation is state
    /// rather than a call, so there is no MAUI method behind this one.
    static let stopFlight = Act("stopFlight")

    /// Page.DisplayAlertAsync.
    static let displayAlertAsync = Act("displayAlertAsync")

    /// Page.DisplayActionSheetAsync.
    static let displayActionSheetAsync = Act("displayActionSheetAsync")

    /// Page.DisplayPromptAsync.
    static let displayPromptAsync = Act("displayPromptAsync")

    /// DateTime.Now - the host's clock, asked. The class stays in the name:
    /// bare "now" would not say whose.
    static let dateTimeNow = Act("dateTimeNow")

    /// TimeZoneInfo.Local. The class stays in the name: bare "local" would
    /// not say whose.
    static let localTimeZone = Act("localTimeZone")

    /// TimeZoneInfo.GetUtcOffset.
    static let getUtcOffset = Act("getUtcOffset")

    /// This library's own: a persistent key's new value, on its way to the
    /// store. Which store that is belongs to the host - see
    /// Core/Persistence.swift.
    static let persistValue = Act("persistValue")

    /// This library's own: a handler's escaped error, reported to the host.
    static let handlerFailed = Act("handlerFailed")
}
