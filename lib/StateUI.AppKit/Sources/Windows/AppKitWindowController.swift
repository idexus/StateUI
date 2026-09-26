// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
import Foundation
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

@MainActor
final class AppKitWindowController: NSWindowController {
    enum StopCause: Hashable {
        case applicationHidden
        case miniaturized
        case sceneHidden
    }

    let stateUIID: ElementId
    weak var scene: AppKitSceneController?
    var sceneID: ElementId? { scene?.stateUIID }
    let isMain: Bool
    weak var host: AppKitRenderer?
    weak var node: AppKitElement?
    let presentsWindow: Bool
    var record: AppKitRestorationRecord
    var restorationRecordForTesting: AppKitRestorationRecord { record }
    private var lastWidthRequest: CGFloat?
    private var lastHeightRequest: CGFloat?
    private var lastXRequest: CGFloat?
    private var lastYRequest: CGFloat?
    var presented = false
    private var sentCreated = false
    // One effective stopped transition spans every simultaneous native cause.
    var stopCauses: Set<StopCause> = []
    var lastWindowEvent: Event?
    var closingFromTree = false
    /// The page the window shows, held by its mounted element, which owns its AppKit half.
    private var presentedPageElement: MountedElement?
    var presentedPage: AppKitElement? {
        get { presentedPageElement?.appKit }
        set { presentedPageElement = newValue?.element }
    }
    var modals: [AppKitModalWindowController] = []

    /// The window's first responder, watched so every element that follows its
    /// focus hears it move.
    var focusWatch: NSKeyValueObservation?
    lazy var toolbar = AppKitWindowToolbar(windowIdentifier: record.windowIdentifier)

    /// The row a window's tabs stand in beneath its toolbar, and where it
    /// stands: the title bar's accessory, or a split view detail's own.
    lazy var tabRow = AppKitTabRow(frame: NSRect(x: 0, y: 0, width: 400, height: 40))
    var tabRowAccessory: NSTitlebarAccessoryViewController?
    weak var tabRowSplit: AppKitSplitView?
    var titleAccessory: NSTitlebarAccessoryViewController?
    let titleCluster = AppKitTitleBarTitleView()

    /// The page's title where a painted band hides the system's own.
    let bandTitle: NSTextField = {
        let label = NSTextField(labelWithString: "")
        label.font = .systemFont(ofSize: 15, weight: .bold)
        label.lineBreakMode = .byTruncatingTail
        return label
    }()
    let content = AppKitWindowContentView()
    private let nativeContentMinSize: NSSize
    private let nativeContentMaxSize: NSSize
    let nativeAllowsZoom: Bool
    private let nativeAllowsMinimizing: Bool
    var sceneIsActive = false

    /// Whether the window lets the desktop show through it - see
    /// `AppKitWindowContentView.isTranslucent`.
    var isTranslucent = false

    var pageMenuItems: [NSMenuItem] {
        modals.last?.node.pageMenuItems ?? node?.pageMenuItems ?? []
    }
    var pageMenuItemsForTesting: [NSMenuItem] { pageMenuItems }
    var modalCountForTesting: Int { modals.count }
    var hiddenBySceneForTesting: Bool { stopCauses.contains(.sceneHidden) }
    var toolbarForTesting: AppKitWindowToolbar { toolbar }
    var tabRowForTesting: AppKitTabRow { tabRow }
    var tabRowStandsInTitleBarForTesting: Bool { tabRowAccessory != nil }
    var tabRowAccessoryForTesting: NSTitlebarAccessoryViewController? { tabRowAccessory }
    var tabRowSplitForTesting: AppKitSplitView? { tabRowSplit }
    var titleAccessoryForTesting: NSTitlebarAccessoryViewController? { titleAccessory }
    var titleClusterForTesting: AppKitTitleBarTitleView { titleCluster }

    init(
        stateUIID: ElementId,
        scene: AppKitSceneController,
        host: AppKitRenderer?,
        isMain: Bool,
        record: AppKitRestorationRecord,
        nativeWindow: NSWindow? = nil,
        presentsWindow: Bool
    ) {
        self.stateUIID = stateUIID
        self.scene = scene
        self.host = host
        self.isMain = isMain
        self.record = record
        self.presentsWindow = presentsWindow
        presented = nativeWindow != nil

        let window = nativeWindow ?? Self.makeWindow()
        nativeContentMinSize = window.contentMinSize
        nativeContentMaxSize = window.contentMaxSize
        nativeAllowsZoom = window.standardWindowButton(.zoomButton)?.isEnabled ?? true
        nativeAllowsMinimizing = window.styleMask.contains(.miniaturizable)
        window.isReleasedWhenClosed = false
        super.init(window: window)

        window.delegate = self
        configureChrome(window)
        focusWatch = window.observe(\.firstResponder) { [weak self] _, _ in
            MainActor.assumeIsolated { self?.focusMoved() }
        }
        if nativeWindow == nil {
            window.identifier = NSUserInterfaceItemIdentifier(record.windowIdentifier)
            window.isRestorable = true
            window.restorationClass = AppKitWindowRestorer.self
            window.setFrameAutosaveName("StateUI.\(record.windowIdentifier)")
        }
    }

    /// Every StateUI window wears the system's chrome from the start: full
    /// size content under a unified toolbar that this controller fills. It
    /// is set before any geometry and keeps the frame the window stands at:
    /// AppKit would otherwise keep an adopted window's content view size and
    /// take the title bar's height off a restored frame.
    private func configureChrome(_ window: NSWindow) {
        let standing = window.frame
        window.styleMask.insert(.fullSizeContentView)
        window.titleVisibility = .visible
        window.titlebarAppearsTransparent = false
        window.toolbarStyle = .unified
        window.toolbar = toolbar.toolbar
        if window.frame != standing { window.setFrame(standing, display: false) }
    }

    /// The height the title bar and toolbar take from the top of the window:
    /// what separates StateUI's content area from AppKit's content view.
    private func chromeHeight(of window: NSWindow) -> CGFloat {
        max(0, window.frame.height - window.contentLayoutRect.height)
    }

    static func makeWindow() -> NSWindow {
        NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 440),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false)
    }

    required init?(coder: NSCoder) {
        nil
    }

    func presents(_ candidate: AppKitElement) -> Bool {
        node === candidate
    }

    func standingValue(_ property: Prop) -> HostValue? {
        guard let window else { return nil }

        switch property {
        case .width:
            return .number(Double(window.contentLayoutRect.width))
        case .height:
            return .number(Double(window.contentLayoutRect.height))
        case .x:
            return .number(Double(window.frame.minX))
        case .y:
            guard let screen = window.screen ?? NSScreen.main else { return nil }
            return .number(Double(screen.visibleFrame.maxY - window.frame.maxY))
        default:
            return nil
        }
    }

    func synchronize(_ node: AppKitElement, cascade: Int) {
        self.node = node
        guard let window else { return }
        // Held by their owners: a page the patch removed is still told it stopped showing.
        let previousVisible = (modals.last?.node ?? presentedPage)?.element
        let previousWasModal = !modals.isEmpty

        record = AppKitRestorationRecord(
            windowIdentifier: record.windowIdentifier,
            ownerIdentifier: isMain ? nil : scene?.sessionIdentifier,
            kind: node.name(.windowType),
            value: node.string(.windowValue),
            kept: isMain ? record.kept : [:])

        let width = extent(node.number(.width))
        let height = extent(node.number(.height))
        let widthChanged = lastWidthRequest != width
        let heightChanged = lastHeightRequest != height
        lastWidthRequest = width
        lastHeightRequest = height

        // A requested size is the content area the title bar and toolbar do
        // not cover; the window keeps its top edge where it stands.
        if (widthChanged && width != nil) || (heightChanged && height != nil) {
            var frame = window.frame
            let top = frame.maxY
            if widthChanged, let width { frame.size.width = width }
            if heightChanged, let height { frame.size.height = height + chromeHeight(of: window) }
            frame.origin.y = top - frame.size.height
            window.setFrame(frame, display: presented)
        }

        let x = coordinate(node.number(.x))
        let y = coordinate(node.number(.y))
        let xChanged = lastXRequest != x
        let yChanged = lastYRequest != y
        lastXRequest = x

        var topLeft = NSPoint(x: window.frame.minX, y: window.frame.maxY)
        var movesPosition = false
        if xChanged, let x {
            topLeft.x = x
            movesPosition = true
        }
        if yChanged, let y, let screen = window.screen ?? NSScreen.main {
            topLeft.y = screen.visibleFrame.maxY - y
            lastYRequest = y
            movesPosition = true
        } else if y == nil {
            lastYRequest = nil
        }

        if movesPosition {
            window.setFrameTopLeftPoint(topLeft)
        } else if !presented, x == nil, y == nil {
            window.center()
            if cascade > 0 {
                window.setFrameOrigin(NSPoint(
                    x: window.frame.origin.x + CGFloat(cascade * 24),
                    y: window.frame.origin.y - CGFloat(cascade * 24)))
            }
        }

        content.set(
            page: node.pageView,
            overlay: node.overlayItem,
            spansTitleBar: node.pageNode?.type == .splitView)
        if window.contentView !== content {
            content.frame = NSRect(origin: .zero, size: window.contentLayoutRect.size)
            content.autoresizingMask = [.width, .height]
            window.contentView = content
        }

        presentedPage = node.pageNode
        synchronizeModals(node.modalStackNode?.children ?? [])

        let nextVisible = (modals.last?.node ?? presentedPage)?.element
        if previousVisible !== nextVisible {
            let reason: AppKitPagePresentationReason = previousWasModal || !modals.isEmpty
                ? .navigation
                : .window
            previousVisible?.appKit.setPagePresented(false, reason: reason)
            nextVisible?.appKit.setPagePresented(true, reason: reason)
        }

        // A requested bound is on the content area too; AppKit bounds the
        // whole content view, which reaches under the title bar and toolbar.
        let chrome = chromeHeight(of: window)
        let minimumWidth = extent(node.number(.minimumWidth)) ?? nativeContentMinSize.width
        let minimumHeight = extent(node.number(.minimumHeight)).map { $0 + chrome }
            ?? nativeContentMinSize.height
        let maximumWidth = max(
            minimumWidth,
            extent(node.number(.maximumWidth)) ?? nativeContentMaxSize.width)
        let maximumHeight = max(
            minimumHeight,
            extent(node.number(.maximumHeight)).map { $0 + chrome }
                ?? nativeContentMaxSize.height)
        window.contentMinSize = NSSize(width: minimumWidth, height: minimumHeight)
        window.contentMaxSize = NSSize(width: maximumWidth, height: maximumHeight)

        let allowsZoom = node.bool(.isMaximizable) ?? nativeAllowsZoom
        window.standardWindowButton(.zoomButton)?.isEnabled = allowsZoom

        let allowsMinimizing = node.bool(.isMinimizable) ?? nativeAllowsMinimizing
        if allowsMinimizing {
            window.styleMask.insert(.miniaturizable)
        } else {
            window.styleMask.remove(.miniaturizable)
        }
        window.standardWindowButton(.miniaturizeButton)?.isEnabled = allowsMinimizing
        isTranslucent = node.bool(.isTranslucent) == true
        window.isOpaque = !isTranslucent
        content.isTranslucent = isTranslucent
        window.isExcludedFromWindowsMenu = !isMain
        window.level = node.bool(.floatsOnTop) == true ? .floating : .normal
        window.hidesOnDeactivate = node.bool(.floatsOnTop) == true
        synchronizeSceneVisibility()

        refreshVisiblePageChrome()

        if !sentCreated {
            sentCreated = true
            reportWindow(.created)
        }

        host?.nativeWindowAvailable(window)

        guard !presented else {
            window.invalidateRestorableState()
            return
        }

        presented = true
        if presentsWindow, !stopCauses.contains(.sceneHidden) {
            window.makeKeyAndOrderFront(nil)
        }
    }

    private func extent(_ value: Double?) -> CGFloat? {
        guard let value, value.isFinite, value >= 0 else { return nil }
        return CGFloat(value)
    }

    private func coordinate(_ value: Double?) -> CGFloat? {
        guard let value, value.isFinite else { return nil }
        return CGFloat(value)
    }
}

#endif
