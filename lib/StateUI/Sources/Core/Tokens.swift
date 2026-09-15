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
// Nobody writes a token by hand: an element and its members are declared in a
// CONTRACT (Core/Contract.swift), and a member's token is made from its name -
// the library's and an application's alike. A node type is the one token a
// contract spells, as a literal: `static let nodeType: NodeType =
// "Gallery.TrafficLight"`.
//
// The SOURCES of this library write only the static members - `.label`,
// `.fontSize`, `.textChanged`, `.alert` - and the guard test in
// WireFormatTests names any file that spells a name out instead. This file is
// deliberately the one place the spellings exist.

/// The kind of element a `Node` describes: a native-host capability, a
/// structural node StateUI defines, or an application's own control.
///
/// A token, not an enum, so an application's contract can name a control the
/// library has never heard of - the host draws an unknown type as a red marker
/// rather than failing, which is what keeps a lagging host visible without
/// hiding the rest of the interface.
public struct NodeType: Hashable, Comparable, Sendable,
    ExpressibleByStringLiteral, CustomStringConvertible {
    /// The type's stable StateUI name, or the application's own.
    public let name: String

    /// A node type from its name.
    public init(_ name: String) {
        self.name = name
    }

    /// The literal form, which is how a contract names its node type:
    ///
    ///     static let nodeType: NodeType = "Gallery.ColorWheel"
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

/// One semantic property of a control, with the same spelling the matching
/// modifier writes.
///
/// Comparable by name because a message writes a node's properties in name
/// order - that is what makes two renders of the same tree byte-identical.
public struct Prop: Hashable, Comparable, Sendable, ExpressibleByStringLiteral,
    CustomStringConvertible {
    /// The property's stable StateUI name.
    public let name: String

    /// A property key from its name - what a member's token is made from.
    public init(_ name: String) {
        self.name = name
    }

    /// The literal form, so a name reads plainly where a key is compared:
    /// `property == "fontSize"`.
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
    /// Everything else this library writes lands on a property the host clears
    /// by name: a modifier that stops being written puts its property back to
    /// the control's own default, and the control - with its handlers, and the
    /// `@State` of every view under it - stays where it is. These few have no
    /// such property to clear:
    ///
    /// - a gesture's settings belong to the recognizer carrying them rather
    ///   than to the view;
    /// - a list's items are data, which no default answers for;
    /// - a toolbar item's `order` and `priority`, and a swipe's `side`, say
    ///   where the host PUTS an item rather than a value on it - which part of
    ///   the toolbar, which of a `SwipeView`'s four sides - so there is no
    ///   default to put back;
    /// - a CHOICE must not move the reader when it stops being described, and
    ///   clearing one would: back to the first tab, the first item, the top of
    ///   the list;
    /// - a window's kind, its value, whether it hides and whether it floats
    ///   on top are read by the host to keep the platform's windows, and land
    ///   on no property at all - nor are they ever taken off a window they
    ///   were on.
    ///
    /// Every host has to agree with this list: a property added on one side
    /// without the other is otherwise found only on a screen.
    static let notCleared: Set<Prop> = [
        .tapCount, .swipeDirection, .swipeThreshold, .panTouchCount,
        .dragText, .canDrag, .allowDrop,
        .options,
        .selectedIndex, .currentPage,
        .placement, .priority, .side,
        .region,
        .windowType, .windowValue, .hidesWhenInactive, .floatsOnTop,
    ]

    /// The `MotionValues` group contributed by this property's semantics.
    ///
    /// An empty set uses the plan's base rule and matches `.all`. Colours add
    /// their group through `PropValue.kind`, independent of the property token.
    var moving: MotionValues {
        Prop.kinds[self] ?? []
    }

    /// Property-defined motion groups. Value-defined groups do not appear here.
    private static let kinds: [Prop: MotionValues] = {
        var kinds: [Prop: MotionValues] = [.opacity: .opacity]

        for property in [Prop.width, .minimumWidth, .maximumWidth] {
            kinds[property] = .width
        }

        for property in [Prop.height, .minimumHeight, .maximumHeight] {
            kinds[property] = .height
        }

        // The lengths a view's own shape is drawn with go with its size: they
        // are how big it is, said about its corners and its outline.
        for property in [Prop.cornerRadius, .strokeWidth, .borderWidth] {
            kinds[property] = .size
        }

        for property in [Prop.translationX, .translationY] {
            kinds[property] = .place
        }

        for property in [Prop.scale, .scaleX, .scaleY, .rotation, .rotationX, .rotationY,
                         .pivotX, .pivotY] {
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
    /// A native host still validates each transition against the semantic
    /// property and the source and target shapes, snapping unsupported pairs.
    /// This list prevents transitions StateUI already knows are invalid from
    /// entering `HostPatch` or its Wire encoding.
    ///
    /// `testAPlaceOrACountNeverTravels` holds that the DIFFER honours every
    /// member. It cannot hold the MEMBERSHIP - it walks this list to find out
    /// what to check - so a property taken off here starts travelling with
    /// nothing failing anywhere. Take one off only for a property that should.
    static let unmoved: Set<Prop> = [
        .count, .currentPage, .cursorPosition, .selectionLength, .maximumLength, .maximumLines,
        .gridColumn, .gridColumnSpan, .gridRow, .gridRowSpan, .zIndex,
        .placement, .priority, .position, .selectedIndex,
        .tapCount, .panTouchCount, .maximumVisible,
        .step, .minimum, .maximum, .swipeThreshold,
        .points, .strokeDashPattern, .region, .location,
        .absoluteLayoutBounds, .absoluteLayoutProportions,
        .scrollOffset,
        .panXChannel, .panYChannel,
    ]
}

/// One semantic event a control can report, with the same stable StateUI name
/// its matching modifier uses, such as `textChanged` or `clicked`.
///
/// Comparable by name because a message writes a node's handlers in name
/// order, exactly as it writes the properties.
public struct Event: Hashable, Comparable, Sendable, ExpressibleByStringLiteral,
    CustomStringConvertible {
    /// The event's stable StateUI name.
    public let name: String

    /// An event from its name - what a member's token is made from.
    public init(_ name: String) {
        self.name = name
    }

    /// The literal form, so a name reads plainly where an event is compared:
    /// `event == "clicked"`.
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

/// One act the host can perform - one the library ships
/// (`.alert`), or an application's own registered function.
///
/// The host performs what it has a case - or a registration - for; asking for
/// anything else throws with the host's "unknown act" reason, which is
/// what makes a misspelled name a reported failure rather than a silence.
///
/// An application's own act shares this one flat vocabulary, and the library's
/// case is consulted first, so a registration can never shadow one of these.
/// Prefixing an application's names with its own (`"Gallery.BatteryLevel"`) is
/// what keeps the two sets from meeting at all.
public struct Act: Hashable, Sendable, ExpressibleByStringLiteral,
    CustomStringConvertible {
    /// The act's name - the library's own, or the application's registered
    /// one.
    public let name: String

    /// An act from its name - what a member's token is made from.
    public init(_ name: String) {
        self.name = name
    }

    /// The literal form, so a name reads plainly where an act is compared:
    /// `call.act == "alert"`.
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
// PUBLIC for the hosts, which read a tree by these names. An application writes
// a member with its contract - `ViewContract.pinchUpdated` - which is where the
// name and its value's type meet, and so do these sources wherever they write
// a value.
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
// An ACT is the exception to the exemption and says what the host does for
// it, because that is the one thing its name does not carry.
extension NodeType {
    /// Elements whose host arranges children from native measurement rather
    /// than from an ordinary property.
    ///
    /// This set decides which elements may emit `HostLayoutMotion` for their
    /// children. Everything else has no child arrangement to transition.
    static let places: Set<NodeType> = [
        .vStack, .hStack, .grid, .absoluteLayout,
    ]

    /// Elements that always resolve a layout-motion field: child-placing
    /// layouts and the application that supplies the shared fallback.
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
    static let colorBox = NodeType("ColorBox")
    static let button = NodeType("Button")
    static let checkBox = NodeType("CheckBox")
    static let content = NodeType("Content")
    static let page = NodeType("Page")
    static let contextMenu = NodeType("ContextMenu")
    static let datePicker = NodeType("DatePicker")
    static let textEditor = NodeType("TextEditor")
    static let ellipse = NodeType("Ellipse")
    static let textField = NodeType("TextField")
    static let splitView = NodeType("SplitView")
    static let spans = NodeType("Spans")
    static let canvas = NodeType("Canvas")
    static let grid = NodeType("Grid")
    static let hStack = NodeType("HStack")
    static let image = NodeType("Image")
    static let positionIndicator = NodeType("PositionIndicator")
    static let label = NodeType("Label")
    static let leadingContent = NodeType("LeadingContent")
    static let line = NodeType("Line")
    static let map = NodeType("Map")
    static let menu = NodeType("Menu")
    static let menuBar = NodeType("MenuBar")
    static let menuItem = NodeType("MenuItem")
    static let menuSeparator = NodeType("MenuSeparator")
    static let modalStack = NodeType("ModalStack")
    static let navigationStack = NodeType("NavigationStack")
    static let titleView = NodeType("TitleView")
    static let overlay = NodeType("Overlay")
    static let path = NodeType("Path")
    static let picker = NodeType("Picker")
    static let pin = NodeType("Pin")
    static let polygon = NodeType("Polygon")
    static let polyline = NodeType("Polyline")
    static let progressBar = NodeType("ProgressBar")
    static let radioButton = NodeType("RadioButton")
    static let rectangle = NodeType("Rectangle")
    static let refreshView = NodeType("RefreshView")
    static let scene = NodeType("Scene")
    static let scrollView = NodeType("ScrollView")
    static let searchField = NodeType("SearchField")
    static let setters = NodeType("Setters")
    static let slider = NodeType("Slider")
    static let span = NodeType("Span")
    static let stepper = NodeType("Stepper")
    static let swipeAction = NodeType("SwipeAction")
    static let swipeActions = NodeType("SwipeActions")
    static let swipeView = NodeType("SwipeView")
    static let `switch` = NodeType("Switch")
    static let tabbedView = NodeType("TabbedView")
    static let timePicker = NodeType("TimePicker")
    static let titleBar = NodeType("TitleBar")
    static let toolbarItem = NodeType("ToolbarItem")
    static let toolbarItems = NodeType("ToolbarItems")
    static let trailingContent = NodeType("TrailingContent")
    static let vStack = NodeType("VStack")
    static let visualState = NodeType("VisualState")
    static let webView = NodeType("WebView")
    static let window = NodeType("Window")
}

public extension Prop {
    static let absoluteLayoutBounds = Prop("absoluteLayoutBounds")
    static let absoluteLayoutProportions = Prop("absoluteLayoutProportions")
    static let accessibilityHeadingLevel = Prop("accessibilityHeadingLevel")
    static let accessibilityHint = Prop("accessibilityHint")
    static let accessibilityIdentifier = Prop("accessibilityIdentifier")
    static let accessibilityLabel = Prop("accessibilityLabel")
    static let address = Prop("address")
    static let allowDrop = Prop("allowDrop")
    static let avoidsSafeArea = Prop("avoidsSafeArea")
    static let barForegroundColor = Prop("barForegroundColor")
    static let hidesWhenInactive = Prop("hidesWhenInactive")
    static let isAccessibilityHidden = Prop("isAccessibilityHidden")
    static let pivotX = Prop("pivotX")
    static let pivotY = Prop("pivotY")
    static let aspect = Prop("aspect")
    static let automationExcludedWithChildren = Prop("automationExcludedWithChildren")
    static let growsWithText = Prop("growsWithText")
    static let background = Prop("background")
    static let barBackgroundColor = Prop("barBackgroundColor")
    static let borderColor = Prop("borderColor")
    static let borderWidth = Prop("borderWidth")
    static let canDrag = Prop("canDrag")
    static let characterSpacing = Prop("characterSpacing")
    static let shape = Prop("shape")
    static let showsClearButton = Prop("showsClearButton")
    static let color = Prop("color")
    static let columns = Prop("columns")
    static let columnSpacing = Prop("columnSpacing")
    static let iconPosition = Prop("iconPosition")
    static let iconSpacing = Prop("iconSpacing")
    static let cornerRadius = Prop("cornerRadius")
    static let count = Prop("count")
    static let currentPage = Prop("currentPage")
    static let cursorPosition = Prop("cursorPosition")
    static let data = Prop("data")
    static let date = Prop("date")
    static let dragText = Prop("dragText")
    static let drawable = Prop("drawable")
    static let fill = Prop("fill")
    static let fillRule = Prop("fillRule")
    static let floatsOnTop = Prop("floatsOnTop")
    static let layoutDirection = Prop("layoutDirection")
    static let letsInputThrough = Prop("letsInputThrough")
    static let fontAttributes = Prop("fontAttributes")
    static let fontAutoScalingEnabled = Prop("fontAutoScalingEnabled")
    static let fontFamily = Prop("fontFamily")
    static let fontSize = Prop("fontSize")
    static let format = Prop("format")
    static let frame = Prop("frame")
    static let gridColumn = Prop("gridColumn")
    static let gridColumnSpan = Prop("gridColumnSpan")
    static let gridRow = Prop("gridRow")
    static let gridRowSpan = Prop("gridRowSpan")
    static let group = Prop("group")
    static let groupName = Prop("groupName")
    static let height = Prop("height")
    static let hideSingle = Prop("hideSingle")
    static let horizontalAlignment = Prop("horizontalAlignment")
    static let horizontalScrollBarVisibility = Prop("horizontalScrollBarVisibility")
    static let horizontalTextAlignment = Prop("horizontalTextAlignment")
    static let icon = Prop("icon")
    static let step = Prop("step")
    static let indicatorColor = Prop("indicatorColor")
    static let indicatorSize = Prop("indicatorSize")
    static let indicatorsShape = Prop("indicatorsShape")
    static let ignoresInput = Prop("ignoresInput")
    static let isAnimating = Prop("isAnimating")
    static let isOn = Prop("isOn")
    static let clipsContent = Prop("clipsContent")
    static let isDestructive = Prop("isDestructive")
    static let isEnabled = Prop("isEnabled")
    static let isMaximizable = Prop("isMaximizable")
    static let isMinimizable = Prop("isMinimizable")
    static let isTranslucent = Prop("isTranslucent")
    static let isOpen = Prop("isOpen")
    static let isPassword = Prop("isPassword")
    static let isSidebarVisible = Prop("isSidebarVisible")
    static let isReadOnly = Prop("isReadOnly")
    static let isRefreshEnabled = Prop("isRefreshEnabled")
    static let isRefreshing = Prop("isRefreshing")
    static let isRunning = Prop("isRunning")
    static let isScrollEnabled = Prop("isScrollEnabled")
    static let showsUserLocation = Prop("showsUserLocation")
    static let isSpellCheckEnabled = Prop("isSpellCheckEnabled")
    static let isTextPredictionEnabled = Prop("isTextPredictionEnabled")
    static let isTrafficEnabled = Prop("isTrafficEnabled")
    static let isVisible = Prop("isVisible")
    static let isZoomEnabled = Prop("isZoomEnabled")
    static let options = Prop("options")
    static let inputPurpose = Prop("inputPurpose")
    static let label = Prop("label")
    static let lineBreak = Prop("lineBreak")
    static let lineHeight = Prop("lineHeight")
    static let location = Prop("location")
    static let mapType = Prop("mapType")
    static let margin = Prop("margin")
    static let maximum = Prop("maximum")
    static let maximumDate = Prop("maximumDate")
    static let maximumHeight = Prop("maximumHeight")
    static let maximumVisible = Prop("maximumVisible")
    static let maximumWidth = Prop("maximumWidth")
    static let maximumLength = Prop("maximumLength")
    static let maximumLines = Prop("maximumLines")
    static let minimum = Prop("minimum")
    static let minimumDate = Prop("minimumDate")
    static let minimumHeight = Prop("minimumHeight")
    static let minimumWidth = Prop("minimumWidth")
    static let mode = Prop("mode")
    static let name = Prop("name")
    static let backButtonTitle = Prop("backButtonTitle")
    static let hasBackButton = Prop("hasBackButton")
    static let hasNavigationBar = Prop("hasNavigationBar")
    static let opacity = Prop("opacity")
    static let placement = Prop("placement")
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
    static let region = Prop("region")
    static let renderTransform = Prop("renderTransform")
    static let returnKey = Prop("returnKey")
    static let rotation = Prop("rotation")
    static let rotationX = Prop("rotationX")
    static let rotationY = Prop("rotationY")
    static let rows = Prop("rows")
    static let rowSpacing = Prop("rowSpacing")
    static let scale = Prop("scale")
    static let scaleX = Prop("scaleX")
    static let scaleY = Prop("scaleY")

    /// This library's own: where the scroller stands, as one point of two
    /// lanes - the platform's offset being one point, and one journey being
    /// what makes a diagonal move arrive on both axes together.
    static let scrollOffset = Prop("scrollOffset")
    static let selectedIndex = Prop("selectedIndex")
    static let selectedIndicatorColor = Prop("selectedIndicatorColor")
    static let selectionLength = Prop("selectionLength")
    static let side = Prop("side")
    static let source = Prop("source")
    static let spacing = Prop("spacing")
    static let stroke = Prop("stroke")
    static let strokeDashOffset = Prop("strokeDashOffset")
    static let strokeDashPattern = Prop("strokeDashPattern")
    static let strokeLineCap = Prop("strokeLineCap")
    static let strokeLineJoin = Prop("strokeLineJoin")
    static let strokeMiterLimit = Prop("strokeMiterLimit")
    static let strokeWidth = Prop("strokeWidth")
    static let style = Prop("style")
    static let subtitle = Prop("subtitle")
    static let swipeBehaviorOnInvoked = Prop("swipeBehaviorOnInvoked")
    static let swipeDirection = Prop("swipeDirection")
    static let swipeThreshold = Prop("swipeThreshold")
    static let tapCount = Prop("tapCount")
    static let text = Prop("text")
    static let textColor = Prop("textColor")
    static let textDecorations = Prop("textDecorations")
    static let textCase = Prop("textCase")
    static let threshold = Prop("threshold")
    static let time = Prop("time")
    static let tint = Prop("tint")
    static let title = Prop("title")
    static let translationX = Prop("translationX")
    static let translationY = Prop("translationY")
    static let type = Prop("type")
    static let userAgent = Prop("userAgent")

    static let value = Prop("value")
    static let verticalAlignment = Prop("verticalAlignment")
    static let verticalScrollBarVisibility = Prop("verticalScrollBarVisibility")
    static let verticalTextAlignment = Prop("verticalTextAlignment")
    static let width = Prop("width")
    static let windowType = Prop("windowType")
    static let windowValue = Prop("windowValue")
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
    static let clicked = Event("clicked")
    static let closed = Event("closed")
    static let dateChanged = Event("dateChanged")
    static let pinClicked = Event("pinClicked")
    static let pinDetailsClicked = Event("pinDetailsClicked")
    static let refreshRequested = Event("refreshRequested")
    static let submitted = Event("submitted")
    static let created = Event("created")
    static let currentPageChanged = Event("currentPageChanged")
    static let deactivated = Event("deactivated")
    static let destroying = Event("destroying")
    static let disappearing = Event("disappearing")
    static let dragCompleted = Event("dragCompleted")
    static let dragged = Event("dragged")
    static let dragLeave = Event("dragLeave")
    static let dragOver = Event("dragOver")
    static let dragStarted = Event("dragStarted")
    static let dragStarting = Event("dragStarting")
    static let drop = Event("drop")
    static let dropCompleted = Event("dropCompleted")
    static let frameChanged = Event("frameChanged")
    static let isFocusedChanged = Event("isFocusedChanged")
    static let isSidebarVisibleChanged = Event("isSidebarVisibleChanged")
    static let isRefreshingChanged = Event("isRefreshingChanged")
    static let mapClicked = Event("mapClicked")
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
    static let released = Event("released")
    static let resumed = Event("resumed")
    static let scrollStopped = Event("scrollStopped")
    static let scrollXChanged = Event("scrollXChanged")
    static let scrollYChanged = Event("scrollYChanged")
    static let selectedIndexChanged = Event("selectedIndexChanged")
    static let stopped = Event("stopped")
    static let swipeChanging = Event("swipeChanging")
    static let swiped = Event("swiped")
    static let swipeEnded = Event("swipeEnded")
    static let swipeStarted = Event("swipeStarted")
    static let tapped = Event("tapped")
    static let textChanged = Event("textChanged")
    static let timeChanged = Event("timeChanged")
    static let toggled = Event("toggled")
    static let valueChanged = Event("valueChanged")
    static let visualStateChanged = Event("visualStateChanged")
    static let windowClosed = Event("windowClosed")
    static let windowRestored = Event("windowRestored")
}

public extension Act {
    /// Gives the aimed view the keyboard focus, answering whether it took it.
    static let focus = Act("focus")

    /// Takes the keyboard focus off the aimed view.
    static let unfocus = Act("unfocus")

    /// Steps the aimed web view back through its history.
    static let goBack = Act("goBack")

    /// Steps the aimed web view forward through its history.
    static let goForward = Act("goForward")

    /// Loads the aimed web view's page again.
    static let reload = Act("reload")

    /// Runs JavaScript in the aimed web view's page, answering what it
    /// evaluated to, as text.
    static let evaluateJavaScript = Act("evaluateJavaScript")

    /// Moves the aimed map to show a region.
    static let moveToRegion = Act("moveToRegion")

    /// Takes the keyboard down from whichever view on the showing page holds
    /// the focus - the host finds that view, which this side cannot. See
    /// `OnScreenKeyboard.hide()`.
    static let hideOnScreenKeyboard = Act("hideOnScreenKeyboard")

    /// Tells the reader something on the showing page, with one button that
    /// dismisses it; nothing comes back but the dismissal. See `Dialogs.alert`.
    static let alert = Act("alert")

    /// Asks the reader a yes-or-no question on the showing page, answering
    /// whether the accept button was pressed. See `Dialogs.confirm`.
    static let confirm = Act("confirm")

    /// Offers the reader a list of choices on the showing page, answering the
    /// pressed caption. See `Dialogs.chooseAction`.
    static let chooseAction = Act("chooseAction")

    /// Asks the reader to type something on the showing page, answering the
    /// text. See `Dialogs.prompt`.
    static let prompt = Act("prompt")

    /// Has the platform's screen reader say a text. See
    /// `ScreenReader.announce`.
    static let announce = Act("announce")

    /// The host's local time of day, asked of its clock. See `ClockTime.now()`.
    static let currentTime = Act("currentTime")

    /// The IANA identifier of the host's local time zone. See
    /// `TimeZoneInfo.local()`.
    static let currentTimeZone = Act("currentTimeZone")

    /// How far a zone is from UTC on a given day, asked of the host. See
    /// `TimeZoneInfo.utcOffset`.
    static let utcOffset = Act("utcOffset")

    /// A persistent key's new value, on its way to the store. Which store
    /// that is belongs to the host - see Core/Persistence.swift.
    static let persistValue = Act("persistValue")

    /// A scene key's new value, on its way to the platform's record of that
    /// scene. See Core/Scenes.swift.
    static let persistSceneValue = Act("persistSceneValue")

    /// A handler's escaped error, reported to the host.
    static let handlerFailed = Act("handlerFailed")
}
