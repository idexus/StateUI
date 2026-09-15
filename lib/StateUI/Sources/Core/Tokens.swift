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
// Each name is SPELLED ONCE, where a contract declares its member, and a
// token here is made from that member - `static let fontSize =
// FontElementContract.fontSize.token`. The library's sources write the members,
// or these tokens where they read a tree, and `testNoSourceSpellsAName` names
// any file that spells a name out instead.

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
// One token per member the sources and the hosts name, made from the member: a
// new control, property, event or act starts in its CONTRACT, and its token
// follows here - there is no table to keep in step and no number to reserve.
//
// FOR THE HOSTS, behind `@_spi(Host)`: they read a tree by these names until
// their registrations name the members themselves. An application writes a
// member with its contract - `ViewContract.pinchUpdated` - which is where the
// name and its value's type meet, and so do these sources wherever they write
// a value.
//
// A TOKEN IS ITS MEMBER'S NAME, standing under the member's own - `fontSize`,
// `label` - and a node type is its contract's name: `LabelContract` declares
// "Label". LibraryContractTests says both, which is what leaves nothing to
// remember and nothing to look up: the declaration cannot lie about what goes
// on the wire.
//
// A token carries no `///`: its documentation is its member's, where an author
// and a host read what the member holds, carries or does.
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

@_spi(Host) public extension NodeType {
    static let absoluteLayout = AbsoluteLayoutContract.nodeType
    static let activityIndicator = ActivityIndicatorContract.nodeType
    static let application = ApplicationContract.nodeType
    static let border = BorderContract.nodeType
    static let colorBox = ColorBoxContract.nodeType
    static let button = ButtonContract.nodeType
    static let checkBox = CheckBoxContract.nodeType
    static let content = ContentContract.nodeType
    static let page = PageContract.nodeType
    static let contextMenu = ContextMenuContract.nodeType
    static let datePicker = DatePickerContract.nodeType
    static let textEditor = TextEditorContract.nodeType
    static let ellipse = EllipseContract.nodeType
    static let textField = TextFieldContract.nodeType
    static let splitView = SplitViewContract.nodeType
    static let spans = SpansContract.nodeType
    static let canvas = CanvasContract.nodeType
    static let grid = GridContract.nodeType
    static let hStack = HStackContract.nodeType
    static let image = ImageContract.nodeType
    static let positionIndicator = PositionIndicatorContract.nodeType
    static let label = LabelContract.nodeType
    static let leadingContent = LeadingContentContract.nodeType
    static let line = LineContract.nodeType
    static let map = MapContract.nodeType
    static let menu = MenuContract.nodeType
    static let menuBar = MenuBarContract.nodeType
    static let menuItem = MenuItemContract.nodeType
    static let menuSeparator = MenuSeparatorContract.nodeType
    static let modalStack = ModalStackContract.nodeType
    static let navigationStack = NavigationStackContract.nodeType
    static let titleView = TitleViewContract.nodeType
    static let overlay = OverlayContract.nodeType
    static let path = PathContract.nodeType
    static let picker = PickerContract.nodeType
    static let pin = PinContract.nodeType
    static let polygon = PolygonContract.nodeType
    static let polyline = PolylineContract.nodeType
    static let progressBar = ProgressBarContract.nodeType
    static let radioButton = RadioButtonContract.nodeType
    static let rectangle = RectangleContract.nodeType
    static let refreshView = RefreshViewContract.nodeType
    static let scene = SceneContract.nodeType
    static let scrollView = ScrollViewContract.nodeType
    static let searchField = SearchFieldContract.nodeType
    static let setters = SettersContract.nodeType
    static let slider = SliderContract.nodeType
    static let span = SpanContract.nodeType
    static let stepper = StepperContract.nodeType
    static let swipeAction = SwipeActionContract.nodeType
    static let swipeActions = SwipeActionsContract.nodeType
    static let swipeView = SwipeViewContract.nodeType
    static let `switch` = SwitchContract.nodeType
    static let tabbedView = TabbedViewContract.nodeType
    static let timePicker = TimePickerContract.nodeType
    static let titleBar = TitleBarContract.nodeType
    static let toolbarItem = ToolbarItemContract.nodeType
    static let toolbarItems = ToolbarItemsContract.nodeType
    static let trailingContent = TrailingContentContract.nodeType
    static let vStack = VStackContract.nodeType
    static let visualState = VisualStateContract.nodeType
    static let webView = WebViewContract.nodeType
    static let window = WindowContract.nodeType
}

@_spi(Host) public extension Prop {
    static let absoluteLayoutBounds = ViewContract.absoluteLayoutBounds.token
    static let absoluteLayoutProportions = ViewContract.absoluteLayoutProportions.token
    static let accessibilityHeadingLevel = VisualElementContract.accessibilityHeadingLevel.token
    static let accessibilityHint = VisualElementContract.accessibilityHint.token
    static let accessibilityIdentifier = PropertyContainerContract.accessibilityIdentifier.token
    static let accessibilityLabel = VisualElementContract.accessibilityLabel.token
    static let address = PinContract.address.token
    static let allowDrop = ViewContract.allowDrop.token
    static let avoidsSafeArea = LayoutContract.avoidsSafeArea.token
    static let barForegroundColor = NavigationStackContract.barForegroundColor.token
    static let hidesWhenInactive = WindowContract.hidesWhenInactive.token
    static let isAccessibilityHidden = VisualElementContract.isAccessibilityHidden.token
    static let pivotX = VisualElementContract.pivotX.token
    static let pivotY = VisualElementContract.pivotY.token
    static let aspect = ShapeContract.aspect.token
    static let automationExcludedWithChildren = VisualElementContract.automationExcludedWithChildren.token
    static let growsWithText = TextEditorContract.growsWithText.token
    static let background = VisualElementContract.background.token
    static let barBackgroundColor = BarElementContract.barBackgroundColor.token
    static let borderColor = BorderElementContract.borderColor.token
    static let borderWidth = BorderElementContract.borderWidth.token
    static let canDrag = ViewContract.canDrag.token
    static let characterSpacing = TextStyleElementContract.characterSpacing.token
    static let shape = BorderContract.shape.token
    static let showsClearButton = TextFieldContract.showsClearButton.token
    static let color = ColorBoxContract.color.token
    static let columns = GridContract.columns.token
    static let columnSpacing = GridContract.columnSpacing.token
    static let iconPosition = ButtonContract.iconPosition.token
    static let iconSpacing = ButtonContract.iconSpacing.token
    static let cornerRadius = BorderElementContract.cornerRadius.token
    static let count = PositionIndicatorContract.count.token
    static let currentPage = TabbedViewContract.currentPage.token
    static let cursorPosition = InputViewContract.cursorPosition.token
    static let data = PathContract.data.token
    static let date = DatePickerContract.date.token
    static let dragText = ViewContract.dragText.token
    static let drawable = CanvasContract.drawable.token
    static let fill = ShapeContract.fill.token
    static let fillRule = PolygonContract.fillRule.token
    static let floatsOnTop = WindowContract.floatsOnTop.token
    static let layoutDirection = VisualElementContract.layoutDirection.token
    static let letsInputThrough = LayoutContract.letsInputThrough.token
    static let fontAttributes = FontElementContract.fontAttributes.token
    static let fontAutoScalingEnabled = FontElementContract.fontAutoScalingEnabled.token
    static let fontFamily = FontElementContract.fontFamily.token
    static let fontSize = FontElementContract.fontSize.token
    static let format = DatePickerContract.format.token
    static let frame = VisualElementContract.frame.token
    static let gridColumn = ViewContract.gridColumn.token
    static let gridColumnSpan = ViewContract.gridColumnSpan.token
    static let gridRow = ViewContract.gridRow.token
    static let gridRowSpan = ViewContract.gridRowSpan.token
    static let group = VisualStateContract.group.token
    static let groupName = RadioButtonContract.groupName.token
    static let height = VisualElementContract.height.token
    static let hideSingle = PositionIndicatorContract.hideSingle.token
    static let horizontalAlignment = ViewContract.horizontalAlignment.token
    static let horizontalScrollBarVisibility = ScrollViewContract.horizontalScrollBarVisibility.token
    static let horizontalTextAlignment = TextAlignmentElementContract.horizontalTextAlignment.token
    static let icon = MenuItemElementContract.icon.token
    static let step = StepperContract.step.token
    static let indicatorColor = PositionIndicatorContract.indicatorColor.token
    static let indicatorSize = PositionIndicatorContract.indicatorSize.token
    static let indicatorsShape = PositionIndicatorContract.indicatorsShape.token
    static let ignoresInput = VisualElementContract.ignoresInput.token
    static let isAnimating = ImageContract.isAnimating.token
    static let isOn = CheckBoxContract.isOn.token
    static let clipsContent = LayoutContract.clipsContent.token
    static let isDestructive = MenuItemElementContract.isDestructive.token
    static let isEnabled = VisualElementContract.isEnabled.token
    static let isMaximizable = WindowContract.isMaximizable.token
    static let isMinimizable = WindowContract.isMinimizable.token
    static let isTranslucent = WindowContract.isTranslucent.token
    static let isOpen = DatePickerContract.isOpen.token
    static let isPassword = TextFieldContract.isPassword.token
    static let isSidebarVisible = SplitViewContract.isSidebarVisible.token
    static let isReadOnly = InputViewContract.isReadOnly.token
    static let isRefreshEnabled = RefreshViewContract.isRefreshEnabled.token
    static let isRefreshing = RefreshViewContract.isRefreshing.token
    static let isRunning = ActivityIndicatorContract.isRunning.token
    static let isScrollEnabled = MapContract.isScrollEnabled.token
    static let showsUserLocation = MapContract.showsUserLocation.token
    static let isSpellCheckEnabled = InputViewContract.isSpellCheckEnabled.token
    static let isTextPredictionEnabled = InputViewContract.isTextPredictionEnabled.token
    static let isTrafficEnabled = MapContract.isTrafficEnabled.token
    static let isVisible = VisualElementContract.isVisible.token
    static let isZoomEnabled = MapContract.isZoomEnabled.token
    static let options = PickerContract.options.token
    static let inputPurpose = InputViewContract.inputPurpose.token
    static let label = PinContract.label.token
    static let lineBreak = ButtonContract.lineBreak.token
    static let lineHeight = LineHeightElementContract.lineHeight.token
    static let location = PinContract.location.token
    static let mapType = MapContract.mapType.token
    static let margin = ViewContract.margin.token
    static let maximum = SliderContract.maximum.token
    static let maximumDate = DatePickerContract.maximumDate.token
    static let maximumHeight = VisualElementContract.maximumHeight.token
    static let maximumVisible = PositionIndicatorContract.maximumVisible.token
    static let maximumWidth = VisualElementContract.maximumWidth.token
    static let maximumLength = InputViewContract.maximumLength.token
    static let maximumLines = LabelContract.maximumLines.token
    static let minimum = SliderContract.minimum.token
    static let minimumDate = DatePickerContract.minimumDate.token
    static let minimumHeight = VisualElementContract.minimumHeight.token
    static let minimumWidth = VisualElementContract.minimumWidth.token
    static let mode = SwipeActionsContract.mode.token
    static let name = VisualStateContract.name.token
    static let backButtonTitle = PageContract.backButtonTitle.token
    static let hasBackButton = PageContract.hasBackButton.token
    static let hasNavigationBar = PageContract.hasNavigationBar.token
    static let opacity = VisualElementContract.opacity.token
    static let placement = ToolbarItemContract.placement.token
    static let orientation = ScrollViewContract.orientation.token
    static let padding = PaddingElementContract.padding.token
    static let panTouchCount = ViewContract.panTouchCount.token
    static let panXChannel = ViewContract.panXChannel.token
    static let panYChannel = ViewContract.panYChannel.token
    static let placeholder = InputViewContract.placeholder.token
    static let placeholderColor = InputViewContract.placeholderColor.token
    static let points = PolygonContract.points.token
    static let position = PositionIndicatorContract.position.token
    static let priority = ToolbarItemContract.priority.token
    static let progress = ProgressBarContract.progress.token
    static let region = MapContract.region.token
    static let renderTransform = ShapeContract.renderTransform.token
    static let returnKey = SearchFieldContract.returnKey.token
    static let rotation = VisualElementContract.rotation.token
    static let rotationX = VisualElementContract.rotationX.token
    static let rotationY = VisualElementContract.rotationY.token
    static let rows = GridContract.rows.token
    static let rowSpacing = GridContract.rowSpacing.token
    static let scale = VisualElementContract.scale.token
    static let scaleX = VisualElementContract.scaleX.token
    static let scaleY = VisualElementContract.scaleY.token
    static let scrollOffset = ScrollViewContract.scrollOffset.token
    static let selectedIndex = PickerContract.selectedIndex.token
    static let selectedIndicatorColor = PositionIndicatorContract.selectedIndicatorColor.token
    static let selectionLength = InputViewContract.selectionLength.token
    static let side = SwipeActionsContract.side.token
    static let source = ImageContract.source.token
    static let spacing = StackBaseContract.spacing.token
    static let stroke = ShapeContract.stroke.token
    static let strokeDashOffset = ShapeContract.strokeDashOffset.token
    static let strokeDashPattern = ShapeContract.strokeDashPattern.token
    static let strokeLineCap = ShapeContract.strokeLineCap.token
    static let strokeLineJoin = ShapeContract.strokeLineJoin.token
    static let strokeMiterLimit = ShapeContract.strokeMiterLimit.token
    static let strokeWidth = ShapeContract.strokeWidth.token
    static let style = VisualElementContract.style.token
    static let subtitle = TitleBarContract.subtitle.token
    static let swipeBehaviorOnInvoked = SwipeActionsContract.swipeBehaviorOnInvoked.token
    static let swipeDirection = ViewContract.swipeDirection.token
    static let swipeThreshold = ViewContract.swipeThreshold.token
    static let tapCount = ViewContract.tapCount.token
    static let text = TextElementContract.text.token
    static let textColor = TextStyleElementContract.textColor.token
    static let textDecorations = DecorableTextElementContract.textDecorations.token
    static let textCase = TextElementContract.textCase.token
    static let threshold = SwipeViewContract.threshold.token
    static let time = TimePickerContract.time.token
    static let tint = TintElementContract.tint.token
    static let title = PageElementContract.title.token
    static let translationX = VisualElementContract.translationX.token
    static let translationY = VisualElementContract.translationY.token
    static let type = PinContract.type.token
    static let userAgent = WebViewContract.userAgent.token

    static let value = SliderContract.value.token
    static let verticalAlignment = ViewContract.verticalAlignment.token
    static let verticalScrollBarVisibility = ScrollViewContract.verticalScrollBarVisibility.token
    static let verticalTextAlignment = TextAlignmentElementContract.verticalTextAlignment.token
    static let width = VisualElementContract.width.token
    static let windowType = WindowContract.windowType.token
    static let windowValue = WindowContract.windowValue.token
    static let x = WindowContract.x.token
    static let x1 = LineContract.x1.token
    static let x2 = LineContract.x2.token
    static let y = WindowContract.y.token
    static let y1 = LineContract.y1.token
    static let y2 = LineContract.y2.token
    static let zIndex = VisualElementContract.zIndex.token
}

@_spi(Host) public extension Event {
    static let activated = SceneContract.activated.token
    static let appearing = PageContract.appearing.token
    static let canGoBackChanged = WebViewContract.canGoBackChanged.token
    static let canGoForwardChanged = WebViewContract.canGoForwardChanged.token
    static let clicked = MenuItemElementContract.clicked.token
    static let closed = DatePickerContract.closed.token
    static let dateChanged = DatePickerContract.dateChanged.token
    static let pinClicked = PinContract.pinClicked.token
    static let pinDetailsClicked = PinContract.pinDetailsClicked.token
    static let refreshRequested = RefreshViewContract.refreshRequested.token
    static let submitted = SearchFieldContract.submitted.token
    static let created = WindowContract.created.token
    static let currentPageChanged = TabbedViewContract.currentPageChanged.token
    static let deactivated = SceneContract.deactivated.token
    static let destroying = SceneContract.destroying.token
    static let disappearing = PageContract.disappearing.token
    static let dragCompleted = SliderContract.dragCompleted.token
    static let dragged = CanvasContract.dragged.token
    static let dragLeave = ViewContract.dragLeave.token
    static let dragOver = ViewContract.dragOver.token
    static let dragStarted = SliderContract.dragStarted.token
    static let dragStarting = ViewContract.dragStarting.token
    static let drop = ViewContract.drop.token
    static let dropCompleted = ViewContract.dropCompleted.token
    static let frameChanged = ViewContract.frameChanged.token
    static let isFocusedChanged = VisualElementContract.isFocusedChanged.token
    static let isSidebarVisibleChanged = SplitViewContract.isSidebarVisibleChanged.token
    static let isRefreshingChanged = RefreshViewContract.isRefreshingChanged.token
    static let mapClicked = MapContract.mapClicked.token
    static let modalPopped = WindowContract.modalPopped.token
    static let navigated = WebViewContract.navigated.token
    static let navigatedFrom = PageContract.navigatedFrom.token
    static let navigatedTo = PageContract.navigatedTo.token
    static let navigating = WebViewContract.navigating.token
    static let navigatingFrom = PageContract.navigatingFrom.token
    static let opened = DatePickerContract.opened.token
    static let panUpdated = ViewContract.panUpdated.token
    static let pinchUpdated = ViewContract.pinchUpdated.token
    static let pointerEntered = ViewContract.pointerEntered.token
    static let pointerExited = ViewContract.pointerExited.token
    static let pointerMoved = ViewContract.pointerMoved.token
    static let pointerPressed = ViewContract.pointerPressed.token
    static let pointerReleased = ViewContract.pointerReleased.token
    static let popped = NavigationStackContract.popped.token
    static let pressed = ButtonContract.pressed.token
    static let processTerminated = WebViewContract.processTerminated.token
    static let released = ButtonContract.released.token
    static let resumed = WindowContract.resumed.token
    static let scrollStopped = ScrollViewContract.scrollStopped.token
    static let scrollXChanged = ScrollViewContract.scrollXChanged.token
    static let scrollYChanged = ScrollViewContract.scrollYChanged.token
    static let selectedIndexChanged = PickerContract.selectedIndexChanged.token
    static let stopped = SceneContract.stopped.token
    static let swipeChanging = SwipeViewContract.swipeChanging.token
    static let swiped = ViewContract.swiped.token
    static let swipeEnded = SwipeViewContract.swipeEnded.token
    static let swipeStarted = SwipeViewContract.swipeStarted.token
    static let tapped = ViewContract.tapped.token
    static let textChanged = InputViewContract.textChanged.token
    static let timeChanged = TimePickerContract.timeChanged.token
    static let toggled = CheckBoxContract.toggled.token
    static let valueChanged = SliderContract.valueChanged.token
    static let visualStateChanged = VisualElementContract.visualStateChanged.token
    static let windowClosed = SceneContract.windowClosed.token
    static let windowRestored = SceneContract.windowRestored.token
}

@_spi(Host) public extension Act {
    static let focus = VisualElementContract.focus.token
    static let unfocus = VisualElementContract.unfocus.token
    static let goBack = WebViewContract.goBack.token
    static let goForward = WebViewContract.goForward.token
    static let reload = WebViewContract.reload.token
    static let evaluateJavaScript = WebViewContract.evaluateJavaScript.token
    static let moveToRegion = MapContract.moveToRegion.token
    static let hideOnScreenKeyboard = ApplicationContract.hideOnScreenKeyboard.token
    static let alert = ApplicationContract.alert.token
    static let confirm = ApplicationContract.confirm.token
    static let chooseAction = ApplicationContract.chooseAction.token
    static let prompt = ApplicationContract.prompt.token
    static let announce = ApplicationContract.announce.token
    static let currentTime = ApplicationContract.currentTime.token
    static let currentTimeZone = ApplicationContract.currentTimeZone.token
    static let utcOffset = ApplicationContract.utcOffset.token
    static let persistValue = ApplicationContract.persistValue.token
    static let persistSceneValue = ApplicationContract.persistSceneValue.token
    static let handlerFailed = ApplicationContract.handlerFailed.token
}
