// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI

/// Why a page became visible or stopped: a navigation carries three phases, an appearance two.
enum AppKitPagePresentationReason {
    case appearance
    case navigation
    case window
}

/// The AppKit half of a mounted element: its native view and everything hung on it.
/// Design: docs/design/host/tree.md#the-native-half
@MainActor
final class AppKitElement: NSObject, NativeElement {
    /// The element of the mounted tree this is the AppKit half of; it owns this half.
    unowned let element: MountedElement
    private(set) var view: NSView?

    /// How StateUI draws the view over the frame AppKit gives it.
    private var drawing: AppKitViewDrawing?

    private weak var host: AppKitRenderer?
    private let core = CoreLink()
    private var widthConstraint: NSLayoutConstraint?
    private var heightConstraint: NSLayoutConstraint?
    private var minimumWidthConstraint: NSLayoutConstraint?
    private var minimumHeightConstraint: NSLayoutConstraint?
    private var maximumWidthConstraint: NSLayoutConstraint?
    private var maximumHeightConstraint: NSLayoutConstraint?
    private var buttonWidthConstraint: NSLayoutConstraint?
    private var buttonHeightConstraint: NSLayoutConstraint?
    private var observesFrame = false
    private var frameObservedViews: [NSView] = []
    private var frameQueued = false
    private var lastFrameReport: [Double]?

    /// The focus this element last reported, where it follows its focus.
    private var reportedFocus = false

    /// Whether this element is fading out: still visible, deaf to input, and
    /// hidden once the fade lands.
    private var leaving = false
    private var tapRecognizer: AppKitTapRecognizer?
    private var swipeRecognizer: AppKitSwipeRecognizer?
    private var panRecognizer: AppKitPanRecognizer?
    private var pinchRecognizer: AppKitPinchRecognizer?
    private var pointerRecognizer: AppKitPointerRecognizer?
    private var accessibilityDefaults: (
        isElement: Bool,
        role: NSAccessibility.Role?
    )?
    private var accessibilityThroughCell: Bool?
    private var accessibilityChildrenSuppressed = false
    private var panFromX: Double = 0
    private var panFromY: Double = 0
    private var pagePresented = false
    private var pendingTabFallback: Int?
    private var platformMenuItem: NSMenuItem?

    /// What the element showed before the patch being applied, held by its owners so a child
    /// the patch removes can still be told it stopped showing.
    private var previouslyShown: [MountedElement] = []

    init(_ element: MountedElement, host: AppKitRenderer) {
        self.element = element
        self.host = host
        super.init()

        view = makeView()
        drawing = view.map { AppKitViewDrawing($0) }
    }

    // MARK: - The element's tree, read through its mounted element

    var id: ElementId { element.id }
    var type: NodeType { element.type }
    var mount: UInt64 { element.mount }
    var parent: AppKitElement? { element.parent?.appKit }
    var children: [AppKitElement] { element.children.map(\.appKit) }
    var recycledChildren: [AppKitElement] { element.recycledChildren.map(\.appKit) }
    var recycles: Bool { element.recycles }
    var events: [Event: Int32] { element.events }
    var driven: [Prop: HostStateBinding] { element.driven }
    var motion: HostLayoutMotion? { element.motion }
    var framesRead: Bool { element.framesRead }
    func value(_ property: Prop) -> HostValue? { element.value(property) }
    func resolvedValue(_ property: Prop) -> HostValue? { element.resolvedValue(property) }
    func string(_ property: Prop) -> String? { element.string(property) }
    func name(_ property: Prop) -> String? { element.name(property) }
    func number(_ property: Prop) -> Double? { element.number(property) }
    func bool(_ property: Prop) -> Bool? { element.bool(property) }
    func handler(_ event: Event) -> Int32? { element.handler(event) }

    // MARK: - The native half's part in a patch

    var presentsView: Bool { view != nil }

    func willApply() {
        previouslyShown = shownChildren.map(\.element)
    }

    func adopted() {
        leaving = false
        lastFrameReport = nil
        reportedFocus = false
        pagePresented = false
        pendingTabFallback = nil
    }

    func standingValue(_ property: Prop) -> HostValue? {
        if type == .window, let value = host?.standingWindowValue(for: self, property: property) {
            return value
        }

        switch (type, property) {
        case (_, .opacity):
            return .number(Double(view?.alphaValue ?? 1))
        case (.slider, .value):
            return (view as? AppKitSliderView).map { .number($0.doubleValue) }
        case (.progressBar, .progress):
            return (view as? AppKitProgressView).map { .number($0.doubleValue) }
        default:
            return nil
        }
    }

    func animates(_ property: Prop) -> Bool {
        AppKitTransitionSurface.presents(property, on: type)
    }

    func applied(changed: Set<Prop>, wasDescribed: Bool) {
        if wasDescribed, changed.contains(.isVisible) { crossVisibility() }
        applyProperties(changed: changed)
        configureContextMenu()
        configureGestures()
        configureLayoutMotion()
        arrangeChildren()
        configureFrameObservation()
        reconcilePresentation(from: previouslyShown.map(\.appKit))
        previouslyShown = []
        reportTabFallback()
    }

    func letGo() {
        leaving = false
    }

    func leave() {
        releaseNativeAttachments()
    }

    /// Crosses a change of visibility on an element already shown: out -
    /// fading to nothing, deaf to input, hidden when the fade lands - or in,
    /// from nothing up to the opacity the tree describes. Under the element's
    /// own motion, or the application's where it says nothing; at once under
    /// `.motion(.none)`, an engine's value, or a reader who asked for less.
    private func crossVisibility() {
        guard let host, let view else { return }
        let visible = value(.isVisible)?.bool != false
        let law = host.layoutMotion.law(of: motion)
        let opacity = resolvedValue(.opacity) ?? .number(1)

        if !visible {
            guard !view.isHidden, !leaving, let law else { return }
            leaving = true
            let started = host.tree.receiveProperty(
                mount: mount,
                property: .opacity,
                standing: .number(Double(view.alphaValue)),
                target: .number(0),
                motion: law,
                landed: { [weak self] in self?.crossed() })
            if !started { leaving = false }
        } else if leaving {
            // BACK BEFORE IT WENT: up again from where the fade has reached,
            // or at once where nothing moves.
            leaving = false
            host.tree.receiveProperty(
                mount: mount,
                property: .opacity,
                standing: .number(Double(view.alphaValue)),
                target: opacity,
                motion: law)
        } else if view.isHidden, let law {
            view.isHidden = false
            host.tree.receiveProperty(
                mount: mount,
                property: .opacity,
                standing: .number(0),
                target: opacity,
                motion: law)
        }
    }

    /// The fade out ended - landed, or cut short - and the element goes,
    /// unless it was shown again on the way.
    ///
    /// THE REST OF THE CHANGE the patch began: the layout that places the
    /// element closes over it the way a patch moves its children, rather than
    /// snapping the rows below into the gap.
    private func crossed() {
        guard leaving, let view else { return }
        leaving = false
        (view.superview as? AppKitTravellingLayout)?.patchArrived()
        applyVisibility()
        view.invalidateMeasurements()
    }

    /// Shows, hides and fades the view as the tree says - kept visible and
    /// deaf to input while it fades out.
    private func applyVisibility() {
        guard let view else { return }
        view.isHidden = !leaving && value(.isVisible)?.bool == false
        view.alphaValue = value(.opacity)?.number ?? 1
        if let hitTestView = view as? AppKitHitTestView {
            // The whole view and its children, or only its own empty area.
            let ignores = value(.ignoresInput)?.bool ?? false
            hitTestView.applyInputTransparency(
                leaving || ignores || value(.letsInputThrough)?.bool == true,
                cascades: leaving || ignores)
        }
    }

    func setRecycled(_ recycled: Bool) {
        for native in presentableViews { native.isHidden = recycled }
    }

    private func releaseNativeAttachments() {
        if observesFrame {
            NotificationCenter.default.removeObserver(
                self, name: NSView.frameDidChangeNotification, object: nil)
            NotificationCenter.default.removeObserver(
                self, name: NSView.boundsDidChangeNotification, object: nil)
            frameObservedViews.removeAll()
            observesFrame = false
        }

        let recognizers: [NSGestureRecognizer?] = [
            tapRecognizer, swipeRecognizer, panRecognizer, pinchRecognizer,
        ]
        for recognizer in recognizers.compactMap({ $0 }) {
            view?.removeGestureRecognizer(recognizer)
        }
        tapRecognizer = nil
        swipeRecognizer = nil
        panRecognizer = nil
        pinchRecognizer = nil
        pointerRecognizer?.detach()
        pointerRecognizer = nil

        if let scroller = view as? AppKitScrollView { host?.stopFrames(for: scroller) }
    }

    /// Tells every element in this subtree that follows its focus where the
    /// focus now is, where that has changed.
    func reportFocus() {
        if let handler = events[.isFocusedChanged], let view {
            let focused = AppKitFocus.holds(view, view.window?.firstResponder)
            if focused != reportedFocus {
                reportedFocus = focused
                host?.dispatch(handler, payload: [.bool(focused)])
            }
        }
        for child in children { child.reportFocus() }
    }

    /// Hands a layout what its children travel under, and tells it a patch
    /// reached it: its next arrangement places what the patch changed.
    ///
    /// Only a patch says so. A frame the display cycle presents arranges the
    /// same children in a room that is moving, and they follow it.
    private func configureLayoutMotion() {
        guard let layout = view as? AppKitTravellingLayout else { return }
        layout.layoutMotion = host?.layoutMotion
        layout.motion = motion
        layout.framesRead = framesRead
        layout.patchArrived()
    }

    /// Whether this element can fade in as it joins a standing layout: its
    /// view presents its opacity, and no state owns that opacity.
    private var fadesIn: Bool {
        view != nil && driven[.opacity] == nil
            && AppKitTransitionSurface.presents(.opacity, on: type)
    }

    /// Fades this element in as it joins a layout that was already standing:
    /// the other half of the children around it sliding to make room.
    ///
    /// Not an opacity already travelling: the patch that set it said how it
    /// moves, and a fade over it would be a second answer for one value.
    private func fadeIn(under motion: Motion) {
        guard fadesIn, let host, let view,
              host.tree.presentedPropertyValue(mount: mount, property: .opacity) == nil
        else { return }

        host.tree.receiveProperty(
            mount: mount,
            property: .opacity,
            standing: .number(0),
            target: resolvedValue(.opacity) ?? .number(1),
            motion: motion)
        view.alphaValue = value(.opacity)?.number ?? 1
    }

    /// Presents one display frame of this element's own changed properties.
    func presentFrame(_ properties: Set<Prop>) -> FrameImpact {
        applyProperties(changed: properties)

        var impact = FrameImpact(content: true)
        // An element without a native view - a span, a formatted string - is
        // drawn by the nearest ancestor that has one, which arranges again. A
        // layout's own placement run moves its children inside the room it
        // already has, so it arranges the layout and not its parent.
        let arranged = properties.subtracting(ownPlacementRun)
        if view == nil || !arranged.isDisjoint(with: Self.arrangedProperties) {
            impact.arrangement = true
        }
        if needsWindowSynchronization(for: properties) {
            impact.windowChrome = true
        }
        return impact
    }

    var pageView: NSView? {
        pageNode?.presentableViews.first
    }

    var presentablePageView: NSView? { presentableViews.first }

    var pageNode: AppKitElement? {
        children.first(where: { Self.pageTypes.contains($0.type) })
    }

    var modalStackNode: AppKitElement? {
        children.first { $0.type == .modalStack }
    }

    var overlayItem: AppKitLayoutItem? {
        slot(.overlay)?.children.first?.layoutItem
    }

    var visiblePage: AppKitElement? {
        switch type {
        case .page:
            return self
        case .navigationStack:
            return children.last?.visiblePage
        case .tabbedView:
            return selectedTab?.visiblePage
        case .splitView:
            return children.dropFirst().first?.visiblePage
        default:
            return pageNode?.visiblePage
        }
    }

    /// The native navigation container currently surrounding the visible
    /// content, if this page arrangement has one.
    var visibleNavigationStack: AppKitElement? {
        switch type {
        case .navigationStack:
            return self
        case .tabbedView:
            return selectedTab?.visibleNavigationStack
        case .splitView:
            return children.dropFirst().first?.visibleNavigationStack
        default:
            return pageNode?.visibleNavigationStack
        }
    }

    /// The colour written for the bars over the visible content: its
    /// navigation stack's, else its tabbed view's.
    var visibleBarBackground: NSColor? {
        visibleNavigationStack?.color(.barBackgroundColor)
            ?? visibleTabbedView?.color(.barBackgroundColor)
    }

    /// The colour written for what stands on those bars.
    var visibleBarForeground: NSColor? {
        visibleNavigationStack?.color(.barForegroundColor)
    }

    /// The tabs the window shows beneath its toolbar - those of the tabbed
    /// view on the visible page path, where its tabs are the window's - and
    /// the split view whose detail it stands in, if any.
    var visibleWindowTabs: AppKitTabsPlacement? {
        guard let tabbed = visibleTabbedView,
              let tabs = tabbed.view as? AppKitTabbedView,
              tabs.tabsShownByWindow
        else { return nil }

        var ancestor = tabbed.parent
        while let node = ancestor, node.type != .splitView {
            ancestor = node.parent
        }

        let segments = tabs.segments
        return AppKitTabsPlacement(
            tabs: AppKitWindowTabs(
                titles: segments.map(\.title),
                images: segments.map(\.image),
                selected: tabs.selectedIndex,
                select: { [weak tabs] index in tabs?.selectByReader(index) }),
            split: ancestor?.view as? AppKitSplitView)
    }

    /// The first tabbed view on the visible page path.
    private var visibleTabbedView: AppKitElement? {
        switch type {
        case .page:
            return nil
        case .tabbedView:
            return self
        case .navigationStack:
            return children.last?.visibleTabbedView
        case .splitView:
            return children.dropFirst().first?.visibleTabbedView
        default:
            return pageNode?.visibleTabbedView
        }
    }

    /// Tells each tabbed view on this page path that its tabs are the
    /// window's, in the row beneath its toolbar: the first tabbed view down
    /// any path of stacks and split view details - the row stands beside a
    /// sidebar, never over it. Asked of the window's page once the whole tree
    /// is arranged, so what stands where is the tree's final word. A tabbed
    /// view in a sidebar, a sheet, a tab of another or inside content is never
    /// told, and keeps its tabs on its own content.
    func markTabsShownByWindow() {
        switch type {
        case .tabbedView:
            (view as? AppKitTabbedView)?.tabsShownByWindow = true
        case .navigationStack:
            children.forEach { $0.markTabsShownByWindow() }
        case .splitView:
            children.dropFirst().forEach { $0.markTabsShownByWindow() }
        default:
            break
        }
    }

    /// The native split view controller of a split page.
    var sidebarController: NSSplitViewController? {
        (view as? AppKitSplitView)?.splitController
    }

    /// The way back the visible navigation stack offers, while its top page
    /// can go back.
    var visibleBackAction: AppKitToolbarAction? {
        guard let navigation = visibleNavigationStack,
              navigation.children.count > 1,
              let top = navigation.children.last,
              top.bool(.hasNavigationBar) ?? true,
              top.bool(.hasBackButton) ?? true
        else { return nil }

        let previous = navigation.children[navigation.children.count - 2]
        let title = previous.string(.backButtonTitle) ?? "Back"
        return AppKitToolbarAction(
            identifier: AppKitWindowToolbar.back,
            title: title,
            image: AppKitWindowToolbar.backImage,
            isEnabled: true,
            perform: { [weak navigation] in navigation?.popNavigation() })
    }

    /// The visible page's actions: the primary ones, then those behind
    /// native overflow, each group by priority and then source order. A page
    /// that hides its navigation furniture puts none of them in the toolbar.
    var visibleToolbarActions: (primary: [AppKitToolbarAction], overflow: [AppKitToolbarAction]) {
        guard let page = visiblePage,
              page.bool(.hasNavigationBar) ?? true,
              let items = page.slot(.toolbarItems)?.children
        else { return ([], []) }

        let ordered = items.enumerated().sorted {
            let left = $0.element.whole(.priority) ?? 0
            let right = $1.element.whole(.priority) ?? 0
            return left == right ? $0.offset < $1.offset : left < right
        }.map(\.element)
        let actions = ordered.map { item in
            (overflows: item.enumeration(.placement) == 2, action: AppKitToolbarAction(
                identifier: NSToolbarItem.Identifier("StateUI.action.\(item.mount)"),
                title: item.string(.text) ?? "",
                image: item.image(.icon),
                isEnabled: item.bool(.isEnabled) ?? true,
                perform: { [weak item] in item?.clicked(nil) }))
        }
        return (
            actions.filter { !$0.overflows }.map(\.action),
            actions.filter(\.overflows).map(\.action))
    }

    /// The view the visible page shows in place of its title.
    var visibleTitleView: NSView? {
        visiblePage?.slot(.titleView)?.presentableViews.first
    }

    var pageMenuItems: [NSMenuItem] {
        visiblePage?.slot(.menuBar)?.children.compactMap { $0.nativeMenuItem } ?? []
    }

    /// Makes this page tree visible or hidden, reporting phases only after the
    /// native tree has reached the same state.
    func setPagePresented(_ presented: Bool, reason: AppKitPagePresentationReason) {
        guard Self.pageTypes.contains(type), pagePresented != presented else { return }
        pagePresented = presented

        switch type {
        case .page:
            if presented {
                announce(.appearing)
                if reason == .navigation { announce(.navigatedTo) }
            } else {
                if reason == .navigation { announce(.navigatingFrom) }
                announce(.disappearing)
                if reason == .navigation { announce(.navigatedFrom) }
            }

        case .navigationStack:
            children.last?.setPagePresented(
                presented,
                reason: reason == .window && presented ? .navigation
                    : (reason == .window ? .appearance : reason))

        case .tabbedView:
            selectedTab?.setPagePresented(presented, reason: .appearance)

        case .splitView:
            children.dropFirst().first?.setPagePresented(presented, reason: .appearance)
            if sidebarIsVisible {
                children.first?.setPagePresented(presented, reason: .appearance)
            }

        default:
            break
        }
    }

    private func announce(_ event: Event) {
        guard let handler = events[event] else { return }
        host?.enqueue(handler, isPhase: true)
    }

    /// What this arrangement shows while it is shown itself: a stack's top
    /// page, a tabbed view's selected tab, a split view's detail and - while
    /// it shows - its sidebar. Nothing, for anything else.
    private var shownChildren: [AppKitElement] {
        switch type {
        case .navigationStack:
            return children.last.map { [$0] } ?? []
        case .tabbedView:
            return selectedTab.map { [$0] } ?? []
        case .splitView:
            let detail = Array(children.dropFirst().prefix(1))
            return sidebarIsVisible ? detail + children.prefix(1) : detail
        default:
            return []
        }
    }

    /// Moves presentation to follow a change of the arrangement - a push or a
    /// pop, another tab, the sidebar showing or hiding, or a shown child
    /// replaced outright: what stopped showing leaves first, then what started
    /// showing arrives. On a stack that is a navigation; anywhere else it is a
    /// change of what is visible.
    private func reconcilePresentation(from previous: [AppKitElement]) {
        guard pagePresented else { return }
        let current = shownChildren
        let reason: AppKitPagePresentationReason =
            type == .navigationStack ? .navigation : .appearance

        for child in previous where !current.contains(where: { $0 === child }) {
            child.setPagePresented(false, reason: reason)
        }
        for child in current where !previous.contains(where: { $0 === child }) {
            child.setPagePresented(true, reason: reason)
        }
    }

    /// Reports the tab a tabbed view fell back to when its selected tab went
    /// away.
    private func reportTabFallback() {
        if let fallback = pendingTabFallback,
           let handler = events[.currentPageChanged] {
            host?.enqueue(handler, payload: [.number(Double(fallback))])
        }
        pendingTabFallback = nil
    }

    private var selectedTab: AppKitElement? {
        guard !children.isEmpty else { return nil }
        let requested = (view as? AppKitTabbedView)?.selectedIndex ?? whole(.currentPage) ?? 0
        return children[min(max(requested, 0), children.count - 1)]
    }

    private var sidebarIsVisible: Bool {
        if let split = view as? AppKitSplitView {
            return split.isEffectivelyPresented
        }
        return value(.isSidebarVisible)?.bool == true
    }

    /// Properties a parent reads into its child's layout item. A frame that
    /// moves one of them makes the parent arrange again; no other frame
    /// arranges an ancestor.
    private static let arrangedProperties: Set<Prop> = [
        .margin, .horizontalAlignment, .verticalAlignment,
        .width, .height,
        .minimumWidth, .minimumHeight,
        .maximumWidth, .maximumHeight,
        .gridRow, .gridColumn, .gridRowSpan, .gridColumnSpan,
        .absoluteLayoutBounds, .absoluteLayoutProportions,
    ]

    /// Properties whose change is drawn without changing any native
    /// measurement. Applying any other property may change a view's size, so
    /// it forgets the measurements from that view up to its window.
    private static let unmeasuredProperties: Set<Prop> = [
        .opacity, .translationX, .translationY,
        .rotation, .rotationX, .rotationY, .scale, .scaleX, .scaleY,
        .pivotX, .pivotY,
        .background, .color, .textColor, .placeholderColor,
        .tint, .borderColor, .stroke, .fill, .strokeWidth,
        .strokeDashPattern, .strokeDashOffset, .strokeLineCap, .strokeLineJoin,
        .strokeMiterLimit, .shape, .cornerRadius, .renderTransform,
        .barBackgroundColor, .barForegroundColor,
        .drawable, .value, .progress, .scrollOffset, .isOn, .isEnabled,
        .ignoresInput, .letsInputThrough,
        .accessibilityIdentifier, .isAccessibilityHidden, .automationExcludedWithChildren,
        .accessibilityLabel, .accessibilityHint, .accessibilityHeadingLevel,
    ]

    /// Only properties whose native presentation lives outside the mounted
    /// content view need the scene/window reconciliation path. Ordinary view
    /// frames are already applied in place and AppKit lays them out before the
    /// display link's frame is drawn.
    private func needsWindowSynchronization(for properties: Set<Prop>) -> Bool {
        guard !properties.isEmpty else { return false }
        return type == .window || type == .titleBar || type == .navigationStack
    }

    @objc private func clicked(_ sender: Any?) {
        guard let handler = events[.clicked] else { return }
        host?.dispatch(handler)
    }



    /// A value the reader of a registered view changed, by member.
    private func report(_ property: Prop, _ event: Event, _ value: HostValue) {
        guard let host else { return }

        // A RADIO BUTTON'S SET LIVES ACROSS THE WINDOW, where AppKit clears only
        // the buttons of one superview: the button reports that it is on, and
        // the host - which holds the tree - takes the check off the others in
        // the same breath.
        guard type == .radioButton, property == .isOn, value.bool == true else {
            return carry(property, event, value)
        }

        host.performReaderTransaction {
            clearRadioPeers()
            carry(property, event, value)
        }
    }

    /// The other buttons of this one's set lose their check, each reporting
    /// what it became.
    private func clearRadioPeers() {
        let group = name(.groupName).flatMap { $0.isEmpty ? nil : $0 }
        let scope = radioScope(named: group)
        let peers = group.map { scope.radioButtons(named: $0) }
            ?? (parent?.children.filter { $0.type == .radioButton } ?? [self])

        for peer in peers where peer !== self && peer.bool(.isOn) == true {
            peer.setRadioChecked(false)
            peer.carry(.isOn, .toggled, .bool(false))
        }
    }

    /// One reported value: onto the state the element carries it in - text
    /// where the value is text, lanes where it is a number, a flag or a choice
    /// - and to the element's handler for the event.
    private func carry(_ property: Prop, _ event: Event, _ value: HostValue) {
        guard let host else { return }

        let carried: HostStateValue? = switch value {
        case .string(let text): .text(text)
        case .name(let name): .text(name)
        case .bool(let flag): .lanes([flag ? 1 : 0])
        case .number(let number): .lanes([number])
        case .numbers(let numbers): .lanes(numbers)
        case .enumeration(let choice): .lanes([Double(choice)])
        default: nil
        }

        var reported = false

        if let carried, let binding = driven[property] {
            // A JOURNEY THE HOST CARRIES is taken at the position the reader has
            // just established - the old destination and velocity stop pulling
            // against the hand. A value the host merely sets is reported as it
            // stands.
            if case .lanes(let lanes) = carried, binding.kind == .property {
                reported = host.take(lanes, through: binding)
            } else {
                reported = host.report(carried, through: binding)
            }
        }

        if let handler = events[event] {
            host.dispatch(handler, payload: [value])
        } else if reported {
            host.settleReaderWrite(true)
        }
    }

    private func tapped() {
        guard let handler = events[.tapped] else { return }
        host?.dispatch(handler)
    }

    private func swiped(_ direction: Int32) {
        guard let handler = events[.swiped] else { return }
        host?.dispatch(handler, payload: [.enumeration(direction)])
    }

    private func panChanged(_ phase: AppKitGesturePhase, total: NSPoint) {
        guard let host else { return }
        let across = whole(.panXChannel).flatMap { $0 == 0 ? nil : Int32($0) }
        let down = whole(.panYChannel).flatMap { $0 == 0 ? nil : Int32($0) }

        if phase == .started {
            panFromX = across.flatMap(host.standingGestureValue(state:)) ?? 0
            panFromY = down.flatMap(host.standingGestureValue(state:)) ?? 0
        }

        var changedState = false
        host.performReaderTransaction {
            if phase == .running {
                if let across {
                    changedState = host.takeGestureValue(
                        panFromX + Double(total.x), state: across) || changedState
                }
                if let down {
                    changedState = host.takeGestureValue(
                        panFromY + Double(total.y), state: down) || changedState
                }
            }

            if let handler = events[.panUpdated] {
                host.dispatch(handler, payload: [
                    .enumeration(phase.rawValue),
                    .number(Double(total.x)),
                    .number(Double(total.y)),
                ])
            }
        }
        host.settleReaderWrite(changedState)
    }

    private func pinchChanged(
        _ phase: AppKitGesturePhase,
        scale: CGFloat,
        origin: NSPoint
    ) {
        guard let handler = events[.pinchUpdated] else { return }
        host?.dispatch(handler, payload: [
            .enumeration(phase.rawValue),
            .number(Double(scale)),
            .numbers([Double(origin.x), Double(origin.y)]),
        ])
    }

    private func pointerChanged(
        _ report: AppKitPointerRecognizer.Report,
        point: NSPoint?
    ) {
        let event: Event = switch report {
        case .entered: .pointerEntered
        case .exited: .pointerExited
        case .moved: .pointerMoved
        case .pressed: .pointerPressed
        case .released: .pointerReleased
        }
        guard let handler = events[event] else { return }
        let payload: [HostValue] = point.map {
            [.numbers([Double($0.x), Double($0.y)])]
        } ?? []
        host?.dispatch(handler, payload: payload)
    }


    private func scrolled(from old: NSPoint, to new: NSPoint) {
        guard let host else { return }
        var tookState = false
        host.performReaderTransaction {
            if old != new, let binding = driven[.scrollOffset] {
                tookState = host.take([Double(new.x), Double(new.y)], through: binding)
            }

            if old.x != new.x, let handler = events[.scrollXChanged] {
                host.dispatch(handler, payload: [.number(Double(new.x))])
            }
            if old.y != new.y, let handler = events[.scrollYChanged] {
                host.dispatch(handler, payload: [.number(Double(new.y))])
            }
        }
        host.settleReaderWrite(tookState)
    }

    private func scrollStopped() {
        guard let handler = events[.scrollStopped] else { return }
        host?.dispatch(handler)
    }

    /// Hands an event a registered view raised to this element's handler for
    /// it - nothing where the tree subscribed none.
    private func send(_ event: Event, _ values: [HostValue]) {
        guard let handler = events[event] else { return }

        host?.dispatch(handler, payload: values)
    }

    private func makeView() -> NSView? {
        if let registered = AppKitRegistrations.registry.makeView(
            for: type,
            sending: { [weak self] event, values in self?.send(event, values) },
            reporting: { [weak self] property, event, value in self?.report(property, event, value) }
        ) {
            // A picture crosses as a file NAME, and the files are the
            // renderer's: it holds the resource directory and the cache over
            // it. A registration is made once for the process and has no
            // renderer to ask, so a view that draws pictures is given the way
            // to resolve one here, where it is made.
            if let drawing = registered as? any AppKitPictureResolving {
                drawing.picture = { [weak self] name in self?.image(named: name) }
            }

            return registered
        }

        switch type {
        case .application, .scene, .window:
            return nil

        case .page:
            let page = AppKitSingleChildView()
            page.translatesAutoresizingMaskIntoConstraints = true
            return page

        case .modalStack, .titleBar, .content, .leadingContent, .trailingContent,
             .titleView, .toolbarItems, .menuBar, .contextMenu,
             .menu, .menuItem,
             .menuSeparator, .spans, .span:
            return nil

        case .navigationStack:
            return AppKitNavigationView()

        case .tabbedView:
            return AppKitTabbedView()

        case .splitView:
            return AppKitSplitView()

        case .absoluteLayout:
            return AppKitAbsoluteLayoutView()

        case .border:
            return AppKitBorderView()

        case .scrollView:
            let scroll = AppKitScrollView()
            scroll.onOffsetChanged = { [weak self] old, new in
                self?.scrolled(from: old, to: new)
            }
            scroll.onScrollStopped = { [weak self] in self?.scrollStopped() }
            scroll.onFramesWanted = { [weak self, weak scroll] in
                guard let scroll else { return }
                self?.host?.requestFrames(for: scroll)
            }
            return scroll

        case .label:
            return AppKitLabelView()

        case .toolbarItem:
            // The window's toolbar makes the native item; see visibleToolbarActions.
            return nil

        default:
            return AppKitUnsupportedView(type)
        }
    }

    /// The layout's own placement run, where a state drives one: the room's
    /// arithmetic over the children, which moves them without changing what
    /// the layout measures - a run is not part of its natural size.
    private var ownPlacementRun: Set<Prop> {
        driven[.absoluteLayoutBounds]?.kind == .placement ? [.absoluteLayoutBounds] : []
    }

    private func applyProperties(changed: Set<Prop>) {
        guard let view else { return }

        if !changed.subtracting(ownPlacementRun).isSubset(of: Self.unmeasuredProperties) {
            view.invalidateMeasurements()
        }

        applyVisibility()
        if !(view is AppKitBorderView) && !(view is AppKitColorBoxView) {
            let background = color(.background)
            view.wantsLayer = true
            view.layer?.backgroundColor = background?.cgColor
        }

        // A family the registry realizes takes its own members there, each read
        // as this element presents it; the arms below are the families still
        // to move.
        AppKitRegistrations.registry.apply(
            changed, to: view, of: type,
            reading: { self.value($0) },
            carriedIn: { self.driven[$0]?.mode == .in })

        if type == .toolbarItem, let button = view as? NSButton {
            button.title = string(.text) ?? ""
            let buttonFont = font(fallback: NSFont.systemFont(ofSize: NSFont.systemFontSize))
            button.font = buttonFont
            button.isEnabled = value(.isEnabled)?.bool ?? true

            let foreground = value(.isDestructive)?.bool == true
                ? NSColor.systemRed
                : (color(.textColor) ?? .controlTextColor)
            button.attributedTitle = NSAttributedString(
                string: button.title,
                attributes: [.font: buttonFont, .foregroundColor: foreground])

            button.image = string(.icon).flatMap { image(named: $0) }
            button.imagePosition = button.image == nil
                ? .noImage
                : (button.title.isEmpty ? .imageOnly : .imageLeading)

            let background = color(.background)
            button.isBordered = background == nil
            button.wantsLayer = background != nil
            button.layer?.backgroundColor = background?.cgColor
            button.layer?.cornerRadius = value(.cornerRadius)?.number ?? 0
        }

        if let split = view as? AppKitSplitView {
            // THE VALUE IS THE REGISTRY'S; THIS REPORT IS THE HOST'S. A change
            // the reader makes walks into the first child's page lifetime,
            // which no contract describes, so the closure stays here.
            split.onPresentationChanged = { [weak self] presented in
                self?.changeSidebarVisibility(to: presented)
            }
        }

        if let absolute = view as? AppKitAbsoluteLayoutView {
            absolute.placement = placement(.absoluteLayoutBounds)
        }

        if let border = view as? AppKitBorderView {
            // ITS OWN PADDING, NOT A PAGE'S. This view descends from
            // `AppKitSingleChildView` and took its padding from the page's arm
            // until the page's value moved to the registry, where a
            // registration answers for one node type rather than one class.
            border.padding = insets(.padding)
            border.apply(
                backgroundColor: color(.background),
                background: value(.background),
                stroke: value(.stroke),
                strokeWidth: value(.strokeWidth)?.number,
                shape: value(.shape))
        }

        let minimumWidth = requested(.minimumWidth)
        let minimumHeight = requested(.minimumHeight)
        let maximumWidth = requested(.maximumWidth).map { max($0, minimumWidth ?? 0) }
        let maximumHeight = requested(.maximumHeight).map { max($0, minimumHeight ?? 0) }
        widthConstraint = reconciledConstraint(
            widthConstraint,
            value: requested(.width).map {
                appKitBoundedExtent($0, minimum: minimumWidth, maximum: maximumWidth)
            },
            make: { view.widthAnchor.constraint(equalToConstant: $0) })
        heightConstraint = reconciledConstraint(
            heightConstraint,
            value: requested(.height).map {
                appKitBoundedExtent($0, minimum: minimumHeight, maximum: maximumHeight)
            },
            make: { view.heightAnchor.constraint(equalToConstant: $0) })
        minimumWidthConstraint = reconciledConstraint(
            minimumWidthConstraint,
            value: minimumWidth,
            make: { view.widthAnchor.constraint(greaterThanOrEqualToConstant: $0) })
        minimumHeightConstraint = reconciledConstraint(
            minimumHeightConstraint,
            value: minimumHeight,
            make: { view.heightAnchor.constraint(greaterThanOrEqualToConstant: $0) })
        maximumWidthConstraint = reconciledConstraint(
            maximumWidthConstraint,
            value: maximumWidth,
            make: { view.widthAnchor.constraint(lessThanOrEqualToConstant: $0) })
        maximumHeightConstraint = reconciledConstraint(
            maximumHeightConstraint,
            value: maximumHeight,
            make: { view.heightAnchor.constraint(lessThanOrEqualToConstant: $0) })

        if let button = view as? NSButton,
           let padding = value(.padding)?.numbers, padding.count >= 4 {
            let intrinsic = button.intrinsicContentSize
            buttonWidthConstraint = reconciledConstraint(
                buttonWidthConstraint,
                value: intrinsic.width + padding[0] + padding[2],
                make: {
                    let constraint = button.widthAnchor.constraint(
                        greaterThanOrEqualToConstant: $0)
                    constraint.priority = .defaultHigh
                    return constraint
                })
            buttonHeightConstraint = reconciledConstraint(
                buttonHeightConstraint,
                value: intrinsic.height + padding[1] + padding[3],
                make: {
                    let constraint = button.heightAnchor.constraint(
                        greaterThanOrEqualToConstant: $0)
                    constraint.priority = .defaultHigh
                    return constraint
                })
        } else {
            buttonWidthConstraint?.isActive = false
            buttonWidthConstraint = nil
            buttonHeightConstraint?.isActive = false
            buttonHeightConstraint = nil
        }

        drawing?.own = drawingTransform()
        // Last, so the words meet the control as configured above - a text
        // field may just have swapped in a password field.
        applyAccessibility(to: view)
    }

    /// The view's own drawing transform. `scale` multiplies both axes on
    /// top of `scaleX` and `scaleY`.
    private func drawingTransform() -> HostDrawingTransform {
        let scale = value(.scale)?.number ?? 1
        return HostDrawingTransform(
            translationX: value(.translationX)?.number ?? 0,
            translationY: value(.translationY)?.number ?? 0,
            rotation: value(.rotation)?.number ?? 0,
            rotationX: value(.rotationX)?.number ?? 0,
            rotationY: value(.rotationY)?.number ?? 0,
            scaleX: scale * (value(.scaleX)?.number ?? 1),
            scaleY: scale * (value(.scaleY)?.number ?? 1),
            pivotX: value(.pivotX)?.number ?? 0.5,
            pivotY: value(.pivotY)?.number ?? 0.5)
    }

    /// Keeps the native constraint identity stable while a host channel moves
    /// its constant. Creating and tearing down the Auto Layout graph on every
    /// display frame is both unnecessary work and visible as uneven motion.
    private func reconciledConstraint(
        _ existing: NSLayoutConstraint?,
        value: CGFloat?,
        make: (CGFloat) -> NSLayoutConstraint
    ) -> NSLayoutConstraint? {
        guard let value else {
            existing?.isActive = false
            return nil
        }

        if let existing {
            existing.constant = value
            return existing
        }

        let constraint = make(value)
        constraint.isActive = true
        return constraint
    }

    func arrangeChildren() {
        guard let view else { return }
        let items = children.compactMap(\.layoutItem)

        if let label = view as? AppKitLabelView {
            label.apply(
                attributedText: attributedLabelText(),
                padding: insets(.padding),
                horizontalAlignment: textAlignment(enumeration(.horizontalTextAlignment)),
                verticalAlignment: AppKitVerticalTextAlignment(
                    rawValue: enumeration(.verticalTextAlignment) ?? 0) ?? .start,
                lineBreakMode: lineBreakMode(enumeration(.lineBreak)),
                maximumNumberOfLines: effectiveMaximumLines())
            return
        }

        if let stack = view as? AppKitStackView {
            stack.setItems(items)
            return
        }

        if let split = view as? AppKitSplitView {
            split.setItems(items)
            return
        }

        if let navigation = view as? AppKitNavigationView {
            navigation.setItems(items)
            return
        }

        if let tabs = view as? AppKitTabbedView {
            let tabItems = children.compactMap { child -> AppKitTabItem? in
                guard let layout = child.layoutItem else { return nil }
                return AppKitTabItem(
                    layout: layout,
                    title: child.string(.title),
                    image: child.string(.icon).flatMap { image(named: $0) })
            }
            tabs.onSelection = { [weak self] previous, selected in
                self?.selectTab(from: previous, to: selected)
            }
            pendingTabFallback = tabs.setItems(
                tabItems,
                requestedIndex: whole(.currentPage))
            return
        }

        if let page = view as? AppKitSingleChildView {
            page.setItem(items.first)
            return
        }

        if let grid = view as? AppKitGridView {
            grid.setItems(items)
            return
        }

        if let absolute = view as? AppKitAbsoluteLayoutView {
            absolute.setItems(
                items,
                retaining: recycledChildren.compactMap(\.layoutItem),
                preservesSubviewOrder: recycles)
            return
        }

        if let scroll = view as? AppKitScrollView {
            scroll.setItems(items)
        }
    }

    private var layoutItem: AppKitLayoutItem? {
        guard let view = presentableViews.first else { return nil }
        var item = AppKitLayoutItem(view: view)
        item.margin = insets(.margin)
        item.horizontal = enumeration(.horizontalAlignment) ?? 3
        item.vertical = enumeration(.verticalAlignment) ?? 3
        item.width = requested(.width)
        item.height = requested(.height)
        item.minimumWidth = requested(.minimumWidth)
        item.minimumHeight = requested(.minimumHeight)
        item.maximumWidth = requested(.maximumWidth)
        item.maximumHeight = requested(.maximumHeight)
        item.row = whole(.gridRow) ?? 0
        item.column = whole(.gridColumn) ?? 0
        item.rowSpan = max(whole(.gridRowSpan) ?? 1, 1)
        item.columnSpan = max(whole(.gridColumnSpan) ?? 1, 1)
        item.absoluteBounds = value(.absoluteLayoutBounds)?.numbers
        item.absoluteProportions = enumeration(.absoluteLayoutProportions) ?? 0
        item.drawing = presentableDrawing
        item.mount = mount
        item.placed = presentableNode
        if fadesIn {
            item.fadeIn = { [weak self] motion in self?.fadeIn(under: motion) }
        }
        return item
    }

    /// The element whose view `presentableViews` puts first.
    private var presentableNode: AppKitElement? {
        if view != nil { return self }
        return children.lazy.compactMap(\.presentableNode).first
    }

    /// The drawing of the view `presentableViews` puts first.
    private var presentableDrawing: AppKitViewDrawing? {
        if view != nil { return drawing }
        return children.lazy.compactMap(\.presentableDrawing).first
    }

    /// Applies StateUI's semantic surface without replacing the native
    /// control's ordinary role or participation when the author says nothing.
    private func applyAccessibility(to view: NSView) {
        let target = accessibilityTarget(of: view)
        if accessibilityDefaults == nil {
            accessibilityDefaults = (
                isElement: target.isAccessibilityElement(),
                role: target.accessibilityRole())
        }
        guard let defaults = accessibilityDefaults else { return }

        target.setAccessibilityIdentifier(string(.accessibilityIdentifier))
        target.setAccessibilityLabel(string(.accessibilityLabel))
        target.setAccessibilityHelp(string(.accessibilityHint))

        let excludesChildren = value(.automationExcludedWithChildren)?.bool == true
        if excludesChildren {
            view.setAccessibilityChildren([])
            accessibilityChildrenSuppressed = true
        } else if accessibilityChildrenSuppressed {
            view.setAccessibilityChildren(nil)
            accessibilityChildrenSuppressed = false
        }

        let headingLevel = max(0, enumeration(.accessibilityHeadingLevel) ?? 0)
        let carriesSemantics = string(.accessibilityLabel) != nil
            || string(.accessibilityHint) != nil
            || headingLevel > 0
        // An element that answers a tap is a button to assistive technology,
        // pressed by the handler a click runs. See `AppKitHitTestView`.
        let pressable = events[.tapped] != nil && view is AppKitHitTestView
        // The author says whether the view is hidden; an element is the opposite.
        let authoredElement = value(.isAccessibilityHidden)?.bool.map { !$0 }
        target.setAccessibilityElement(
            excludesChildren
                ? false
                : (authoredElement ?? (carriesSemantics || pressable ? true : defaults.isElement)))

        if headingLevel > 0 {
            target.setAccessibilityRole(NSAccessibility.Role(rawValue: "AXHeading"))
        } else if pressable {
            target.setAccessibilityRole(.button)
        } else {
            target.setAccessibilityRole(defaults.role)
        }
    }

    /// The object assistive technology meets for `view`: the native control a
    /// wrapping view presents in its place (`AppKitAccessibilityPresenting`),
    /// or the view itself - and for a control AppKit presents through its
    /// cell, a button, a slider or a stepper, that cell. The cell is the
    /// element there and the view is not, so words written on the view would
    /// reach nobody, and making the view the element would hide the control's
    /// own role. Whether it is the cell is decided once, before any authored
    /// word moves it; the control is looked up each time, because a wrapper
    /// may replace it - a text field becoming a password field.
    private func accessibilityTarget(of view: NSView) -> NSAccessibilityProtocol {
        let control = (view as? AppKitAccessibilityPresenting)?.presentedControl ?? view
        let cell = (control as? NSControl)?.cell
        if accessibilityThroughCell == nil {
            accessibilityThroughCell = cell?.isAccessibilityElement() == true
        }
        if accessibilityThroughCell == true, let cell {
            return cell
        }
        return control
    }

    private var presentableViews: [NSView] {
        if let view { return [view] }
        return children.flatMap(\.presentableViews)
    }

    /// The first native view authored into one structural child slot.
    func firstView(in slot: NodeType) -> NSView? {
        self.slot(slot)?.presentableViews.first
    }

    /// Resolves an image-valued property through the host's resource policy.
    func image(_ property: Prop) -> NSImage? {
        string(property).flatMap { image(named: $0) }
    }

    private func slot(_ type: NodeType) -> AppKitElement? {
        children.first { $0.type == type }
    }

    private func radioScope(named group: String?) -> AppKitElement {
        guard group != nil else { return parent ?? self }

        var scope = self
        while let ancestor = scope.parent {
            scope = ancestor
            if scope.type == .window { break }
        }
        return scope
    }

    private func radioButtons(named group: String) -> [AppKitElement] {
        var matches: [AppKitElement] = []
        if type == .radioButton, name(.groupName) == group { matches.append(self) }
        for child in children { matches.append(contentsOf: child.radioButtons(named: group)) }
        return matches
    }

    private func setRadioChecked(_ checked: Bool) {
        (view as? AppKitRadioButtonView)?.setCheckedFromGroup(checked)
    }

    private var nativeMenuItem: NSMenuItem? {
        if type == .menuSeparator {
            if let platformMenuItem { return platformMenuItem }
            let item = NSMenuItem.separator()
            platformMenuItem = item
            return item
        }

        guard type == .menu || type == .menuItem else { return nil }

        let item = platformMenuItem ?? NSMenuItem()
        platformMenuItem = item
        item.title = string(.text) ?? ""
        item.isEnabled = value(.isEnabled)?.bool ?? true
        item.setAccessibilityIdentifier(string(.accessibilityIdentifier))
        item.image = string(.icon).flatMap { image(named: $0) }

        if value(.isDestructive)?.bool == true {
            item.attributedTitle = NSAttributedString(
                string: item.title,
                attributes: [.foregroundColor: NSColor.systemRed])
        } else {
            item.attributedTitle = NSAttributedString(string: item.title)
        }

        if type == .menuItem {
            item.target = self
            item.action = #selector(clicked(_:))
            item.submenu = nil
        } else {
            item.target = nil
            item.action = nil
            let menu = item.submenu ?? NSMenu(title: item.title)
            menu.title = item.title
            menu.autoenablesItems = false
            menu.removeAllItems()
            for child in children {
                if let child = child.nativeMenuItem { menu.addItem(child) }
            }
            item.submenu = menu
        }

        return item
    }

    /// Attaches the view's menu slot directly to AppKit. The slot remains a
    /// StateUI child for identity and sparse updates, but never becomes a
    /// visual child in the native layout.
    private func configureContextMenu() {
        guard let view else { return }
        guard let slot = slot(.contextMenu) else {
            view.menu = nil
            return
        }

        let items = slot.children.compactMap(\.nativeMenuItem)
        guard !items.isEmpty else {
            view.menu = nil
            return
        }

        let menu = view.menu ?? NSMenu()
        menu.autoenablesItems = false
        menu.removeAllItems()
        for item in items { menu.addItem(item) }
        view.menu = menu
    }

    private func popNavigation() {
        guard type == .navigationStack, children.count > 1,
              let handler = events[.popped]
        else { return }

        host?.dispatch(handler, payload: [.number(Double(children.count - 2))])
    }

    private func selectTab(from previous: Int, to selected: Int) {
        guard type == .tabbedView, children.indices.contains(selected) else { return }

        if pagePresented {
            if children.indices.contains(previous) {
                children[previous].setPagePresented(false, reason: .appearance)
            }
            children[selected].setPagePresented(true, reason: .appearance)
        }

        host?.commit(events[.currentPageChanged], payload: [.number(Double(selected))])

        // The window's chrome follows what the reader sees now - its title,
        // its actions, its row of tabs - whether or not the application binds
        // the selection and renders again.
        host?.refreshWindowChrome()
    }

    private func changeSidebarVisibility(to presented: Bool) {
        guard type == .splitView else { return }

        if pagePresented {
            children.first?.setPagePresented(presented, reason: .appearance)
        }

        host?.commit(events[.isSidebarVisibleChanged], payload: [.bool(presented)])
    }

    private func enumeration(_ property: Prop) -> Int32? {
        value(property)?.enumeration
    }

    private func whole(_ property: Prop) -> Int? {
        guard let number = value(property)?.number, number.isFinite else { return nil }
        return Int(number.rounded())
    }

    private func font(fallback: NSFont) -> NSFont {
        appKitFont(
            family: name(.fontFamily),
            size: value(.fontSize)?.number,
            attributes: value(.fontAttributes)?.enumeration,
            fallback: fallback)
    }

    private func attributedLabelText() -> NSAttributedString {
        let baseFont = font(fallback: NSFont.systemFont(ofSize: NSFont.systemFontSize))
        let baseColor = color(.textColor) ?? .labelColor
        let formatted = slot(.spans)
        let runs = formatted?.children ?? [self]
        let result = NSMutableAttributedString()

        for run in runs where run.type == .span || run === self {
            let source = run.string(.text) ?? ""
            let text = run.transformed(source, by: run.enumeration(.textCase))
            let font = run === self ? baseFont : run.font(fallback: baseFont)
            let color = run === self ? baseColor : (run.color(.textColor) ?? baseColor)
            let spacing = run.number(.characterSpacing) ?? number(.characterSpacing) ?? 0
            let decorations = run.enumeration(.textDecorations)
                ?? enumeration(.textDecorations) ?? 0
            let lineHeight = run.number(.lineHeight) ?? number(.lineHeight)
            var attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: color,
                .kern: spacing,
            ]

            if run !== self, let background = run.color(.background) {
                attributes[.backgroundColor] = background
            }
            if decorations & 1 == 1 {
                attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue
            }
            if decorations & 2 == 2 {
                attributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
            }
            if let lineHeight, lineHeight.isFinite, lineHeight > 0 {
                let paragraph = NSMutableParagraphStyle()
                let height = font.boundingRectForFont.height * lineHeight
                paragraph.minimumLineHeight = height
                paragraph.maximumLineHeight = height
                attributes[.paragraphStyle] = paragraph
            }

            result.append(NSAttributedString(string: text, attributes: attributes))
        }

        return result
    }

    private func effectiveMaximumLines() -> Int {
        switch enumeration(.lineBreak) {
        case 0, 3, 4, 5: return 1
        default: return max(0, whole(.maximumLines) ?? 0)
        }
    }

    /// The text a field shows from its state. The value this frame carries
    /// comes first: a reader's report reaches the core's store only when its
    /// jobs run, so reading the store here would write the field back one
    /// keystroke behind the reader.
    private func transformed(_ text: String, by transform: Int32?) -> String {
        appKitTextCased(text, transform)
    }

    func color(_ property: Prop) -> NSColor? {
        value(property).flatMap(nsColor)
    }

    private func image(named name: String) -> NSImage? {
        host?.image(named: name)
    }

    private func transformComponents(_ property: Prop) -> [Double]? {
        guard let components = value(property)?.values, components.count == 6 else {
            return nil
        }

        let numbers = components.compactMap(\.number)
        return numbers.count == components.count ? numbers : nil
    }

    private func insets(_ property: Prop) -> NSEdgeInsets {
        guard let numbers = value(property)?.numbers, numbers.count >= 4 else {
            return NSEdgeInsets()
        }

        return NSEdgeInsets(
            top: numbers[1], left: numbers[0], bottom: numbers[3], right: numbers[2])
    }

    /// A negative request is StateUI's explicit "measure me" sentinel. Keep
    /// it out of both Auto Layout and the frame-based layout algorithms so the
    /// native control's fitting size remains authoritative.
    private func requested(_ property: Prop) -> CGFloat? {
        guard let value = number(property), value.isFinite, value >= 0 else { return nil }
        return CGFloat(value)
    }

    private func placement(_ property: Prop) -> HostPlacementRun? {
        guard driven[property]?.kind == .placement, let carried = element.carriedValue(property) else { return nil }

        return StateUIHost.placements(from: carried)
    }

    private func textAlignment(_ value: Int32?) -> NSTextAlignment {
        appKitTextAlignment(value)
    }




    private func lineBreakMode(_ mode: Int32?) -> NSLineBreakMode {
        switch mode {
        case 0: return .byClipping
        case 1: return .byWordWrapping
        case 2: return .byCharWrapping
        case 3: return .byTruncatingHead
        case 4: return .byTruncatingTail
        case 5: return .byTruncatingMiddle
        default: return .byWordWrapping
        }
    }

    private func configureFrameObservation() {
        guard view != nil else { return }
        let wanted = driven[.frame] != nil || events[.frameChanged] != nil

        if !wanted {
            if observesFrame {
                NotificationCenter.default.removeObserver(
                    self, name: NSView.frameDidChangeNotification, object: nil)
                NotificationCenter.default.removeObserver(
                    self, name: NSView.boundsDidChangeNotification, object: nil)
                frameObservedViews.removeAll(keepingCapacity: true)
                observesFrame = false
            }
            return
        }

        if !observesFrame {
            observesFrame = true
        }

        refreshFrameObservationChain()
        queueFrameReport()
    }

    /// A stationary child's window-space origin changes when an ancestor moves
    /// or a clip view scrolls. Observe the current native chain and rebuild it
    /// after reparenting instead of treating the child's frame as sufficient.
    private func refreshFrameObservationChain() {
        guard observesFrame, let view else { return }
        var chain: [NSView] = []
        var current: NSView? = view

        while let candidate = current {
            chain.append(candidate)
            if candidate === view.window?.contentView { break }
            current = candidate.superview
        }

        let unchanged = chain.count == frameObservedViews.count
            && zip(chain, frameObservedViews).allSatisfy { $0 === $1 }
        guard !unchanged else { return }

        NotificationCenter.default.removeObserver(
            self, name: NSView.frameDidChangeNotification, object: nil)
        NotificationCenter.default.removeObserver(
            self, name: NSView.boundsDidChangeNotification, object: nil)
        frameObservedViews = chain

        for observed in chain {
            observed.postsFrameChangedNotifications = true
            observed.postsBoundsChangedNotifications = true
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(frameDidChange(_:)),
                name: NSView.frameDidChangeNotification,
                object: observed)
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(frameDidChange(_:)),
                name: NSView.boundsDidChangeNotification,
                object: observed)
        }
    }

    private func configureGestures() {
        guard let view else { return }

        if events[.tapped] != nil {
            let recognizer: AppKitTapRecognizer

            if let existing = tapRecognizer {
                recognizer = existing
            } else {
                recognizer = AppKitTapRecognizer { [weak self] in self?.tapped() }
                tapRecognizer = recognizer
                view.addGestureRecognizer(recognizer)
            }

            recognizer.apply(tapCount: whole(.tapCount) ?? 1)
        } else if let recognizer = tapRecognizer {
            view.removeGestureRecognizer(recognizer)
            tapRecognizer = nil
        }

        (view as? AppKitHitTestView)?.pressAction = events[.tapped] == nil
            ? nil
            : { [weak self] in self?.tapped() }

        if events[.swiped] != nil {
            let recognizer: AppKitSwipeRecognizer
            if let existing = swipeRecognizer {
                recognizer = existing
            } else {
                recognizer = AppKitSwipeRecognizer { [weak self] direction in
                    self?.swiped(direction)
                }
                swipeRecognizer = recognizer
                view.addGestureRecognizer(recognizer)
            }
            recognizer.directions = enumeration(.swipeDirection) ?? 15
            recognizer.threshold = max(
                0,
                number(.swipeThreshold).map { CGFloat($0) } ?? 40)
        } else if let recognizer = swipeRecognizer {
            view.removeGestureRecognizer(recognizer)
            swipeRecognizer = nil
        }

        let panX = whole(.panXChannel).flatMap { $0 == 0 ? nil : Int32($0) }
        let panY = whole(.panYChannel).flatMap { $0 == 0 ? nil : Int32($0) }
        let wantsPan = events[.panUpdated] != nil || panX != nil || panY != nil
        if wantsPan {
            let recognizer: AppKitPanRecognizer
            if let existing = panRecognizer {
                recognizer = existing
            } else {
                recognizer = AppKitPanRecognizer { [weak self] phase, total in
                    self?.panChanged(phase, total: total)
                }
                panRecognizer = recognizer
                view.addGestureRecognizer(recognizer)
            }

            // AppKit's stable pan contract is a primary-pointer drag. The
            // multi-touch count API before macOS 26 refers to Touch Bar input,
            // so an authored count other than one cannot truthfully match here.
            recognizer.isEnabled = whole(.panTouchCount).map { $0 == 1 } ?? true
        } else if let recognizer = panRecognizer {
            view.removeGestureRecognizer(recognizer)
            panRecognizer = nil
        }

        if events[.pinchUpdated] != nil {
            if pinchRecognizer == nil {
                let recognizer = AppKitPinchRecognizer { [weak self] phase, scale, origin in
                    self?.pinchChanged(phase, scale: scale, origin: origin)
                }
                pinchRecognizer = recognizer
                view.addGestureRecognizer(recognizer)
            }
        } else if let recognizer = pinchRecognizer {
            view.removeGestureRecognizer(recognizer)
            pinchRecognizer = nil
        }

        let pointerEvents = [
            Event.pointerEntered, .pointerExited, .pointerMoved, .pointerPressed, .pointerReleased,
        ]
        if pointerEvents.contains(where: { events[$0] != nil }) {
            let recognizer: AppKitPointerRecognizer
            if let existing = pointerRecognizer {
                recognizer = existing
            } else {
                recognizer = AppKitPointerRecognizer { [weak self] report, point in
                    self?.pointerChanged(report, point: point)
                }
                pointerRecognizer = recognizer
            }
            recognizer.install(on: view)
        } else if let recognizer = pointerRecognizer {
            recognizer.detach()
            pointerRecognizer = nil
        }
    }

    @objc private func frameDidChange(_ notification: Notification) {
        queueFrameReport()
    }

    private func queueFrameReport() {
        guard !frameQueued else { return }
        frameQueued = true

        DispatchQueue.main.async { [weak self] in
            self?.flushFrameReport()
        }
    }

    private func flushFrameReport() {
        frameQueued = false
        refreshFrameObservationChain()
        guard let view, let content = view.window?.contentView else { return }

        let parentFrame = topLeftFrame(view.frame, in: view.superview)
        let windowFrame = topLeftFrame(view.convert(view.bounds, to: content), in: content)
        let safeArea = topLeftFrame(content.safeAreaRect, in: content)
        let report = [
            parentFrame.minX, parentFrame.minY, parentFrame.width, parentFrame.height,
            windowFrame.minX, windowFrame.minY,
            windowFrame.minX - safeArea.minX, windowFrame.minY - safeArea.minY,
        ].map(Double.init)

        guard report != lastFrameReport else { return }
        lastFrameReport = report

        let reported = driven[.frame].map {
            host?.report(.lanes(Array(report.prefix(4))), through: $0) ?? false
        } ?? false

        if let handler = events[.frameChanged] {
            host?.dispatch(handler, payload: [.numbers(report)])
        } else if reported {
            host?.pump()
        }
    }

    func flushFrameReportForTesting() {
        flushFrameReport()
    }

    var frameReportQueuedForTesting: Bool { frameQueued }

    private func topLeftFrame(_ frame: NSRect, in parent: NSView?) -> NSRect {
        guard let parent, !parent.isFlipped else { return frame }
        return NSRect(
            x: frame.minX,
            y: parent.bounds.height - frame.maxY,
            width: frame.width,
            height: frame.height)
    }

    private static let pageTypes: Set<NodeType> = [
        .page, .navigationStack, .tabbedView, .splitView,
    ]

}

extension MountedElement {
    /// This element's AppKit half.
    var appKit: AppKitElement { native as! AppKitElement }
}
#endif
