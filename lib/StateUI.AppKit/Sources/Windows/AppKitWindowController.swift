// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
import Foundation
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// One window element shown in an AppKit window: what the host layer says it shows - its arrangement of pages, its
/// sheets, its overlay, its frame, its bounds and its traits - turned into AppKit's, in step with the element as the
/// tree changes, and what AppKit tells of the window handed to the host layer.
/// Design: docs/design/platforms/appkit/runtime.md#the-window
@MainActor
final class AppKitWindowController: NSWindowController {
    /// The window element shown.
    private(set) weak var element: MountedElement?
    weak var host: AppKitRenderer?
    let isMain: Bool
    let presentsWindow: Bool
    var record: AppKitRestorationRecord
    var restorationRecordForTesting: AppKitRestorationRecord { record }

    /// What the window shows, by the host layer's rule.
    let presentation = WindowPresentation()

    /// The bounds the element asks, applied again on every presentation: they count the chrome, which can grow.
    private var bounds: WindowBounds?

    /// What the element says the window is.
    private(set) var traits: WindowTraits?

    /// Whether the window is on the screen yet.
    var presented = false

    /// Whether its scene hides it: another scene is in front.
    private(set) var hiddenByScene = false

    /// What AppKit last told of the window: whether it is minimized, and whether it holds the keyboard.
    var isMinimized = false
    var isKey = false
    var closingFromTree = false
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

    /// Whether the window lets the desktop show through it - see
    /// `AppKitWindowContentView.isTranslucent`.
    var isTranslucent = false

    var pageMenuItemsForTesting: [NSMenuItem] { AppKitMenus.items(pageMenus) }
    var modalCountForTesting: Int { modals.count }
    var hiddenBySceneForTesting: Bool { hiddenByScene }
    var toolbarForTesting: AppKitWindowToolbar { toolbar }
    var tabRowForTesting: AppKitTabRow { tabRow }
    var tabRowStandsInTitleBarForTesting: Bool { tabRowAccessory != nil }
    var tabRowAccessoryForTesting: NSTitlebarAccessoryViewController? { tabRowAccessory }
    var tabRowSplitForTesting: AppKitSplitView? { tabRowSplit }
    var titleAccessoryForTesting: NSTitlebarAccessoryViewController? { titleAccessory }
    var titleClusterForTesting: AppKitTitleBarTitleView { titleCluster }

    init(
        _ element: MountedElement,
        host: AppKitRenderer?,
        record: AppKitRestorationRecord,
        nativeWindow: NSWindow? = nil,
        presentsWindow: Bool
    ) {
        self.element = element
        self.host = host
        isMain = element.value(.windowType) == nil
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
        window.isExcludedFromWindowsMenu = !isMain
        configureChrome(window)
        focusWatch = window.observe(\.firstResponder) { [weak self] _, _ in
            MainActor.assumeIsolated { self?.focusMoved() }
        }
        if nativeWindow == nil {
            window.identifier = NSUserInterfaceItemIdentifier(record.windowIdentifier)
            window.isRestorable = true
            window.restorationClass = AppKitWindowRestorer.self
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

    /// Shows what `element` asks for now, the `cascade`th window of the tree. The host layer tells the page the user
    /// sees and the window made before the window is first shown, and so before it comes to the front.
    func present(_ element: MountedElement, in runtime: HostRuntime, cascade: Int) {
        self.element = element
        guard let window else { return }

        let changes = presentation.show(element, in: runtime.lifecycle)
        record = AppKitRestorationRecord(
            windowIdentifier: record.windowIdentifier,
            ownerIdentifier: record.ownerIdentifier,
            kind: element.name(.windowType),
            value: element.value(.windowValue)?.string,
            kept: isMain ? record.kept : [:])

        if let frame = changes.frame { request(frame, of: window) }
        let asked = WindowFrame(of: element)
        if !presented, asked.x == nil, asked.y == nil {
            window.center()
            if cascade > 0 {
                window.setFrameOrigin(NSPoint(
                    x: window.frame.origin.x + CGFloat(cascade * 24),
                    y: window.frame.origin.y - CGFloat(cascade * 24)))
            }
        }

        let arrangement = presentation.arrangement
        content.set(
            page: arrangement?.appKit.presentableViews.first,
            overlay: presentation.overlay?.children.first?.appKit.layoutItem,
            spansTitleBar: arrangement?.type == .splitView)
        if window.contentView !== content {
            content.frame = NSRect(origin: .zero, size: window.contentLayoutRect.size)
            content.autoresizingMask = [.width, .height]
            window.contentView = content
        }
        synchronizeModals(presentation.sheets.map(\.appKit))

        if let bounds = changes.bounds { self.bounds = bounds }
        if let bounds { bound(bounds, window) }
        if let traits = changes.traits { apply(traits, window) }
        if let hidden = changes.hidden { setHidden(hidden, window) }
        refreshVisiblePageChrome()
        host?.nativeWindowAvailable(window)

        guard !presented else {
            window.invalidateRestorableState()
            return
        }

        presented = true
        if presentsWindow, !hiddenByScene { window.makeKeyAndOrderFront(nil) }
    }

    /// Stands the window where the tree asks, each request alone: a size is the content area the title bar and
    /// toolbar do not cover, the window keeping its top edge; a place is counted from the top left of the screen's
    /// work area.
    private func request(_ frame: WindowFrame, of window: NSWindow) {
        if frame.width != nil || frame.height != nil {
            var standing = window.frame
            let top = standing.maxY
            if let width = frame.width { standing.size.width = CGFloat(width) }
            if let height = frame.height { standing.size.height = CGFloat(height) + chromeHeight(of: window) }
            standing.origin.y = top - standing.size.height
            window.setFrame(standing, display: presented)
        }
        guard frame.x != nil || frame.y != nil else { return }

        var topLeft = NSPoint(x: window.frame.minX, y: window.frame.maxY)
        if let x = frame.x { topLeft.x = CGFloat(x) }
        if let y = frame.y, let screen = window.screen ?? NSScreen.main { topLeft.y = screen.visibleFrame.maxY - y }
        window.setFrameTopLeftPoint(topLeft)
    }

    /// Bounds the content area as the tree asks; AppKit bounds the whole content view, which reaches under the title
    /// bar and toolbar. What the tree leaves unsaid is the window's own.
    private func bound(_ bounds: WindowBounds, _ window: NSWindow) {
        let chrome = chromeHeight(of: window)
        let minimum = NSSize(
            width: bounds.minimumWidth.map { CGFloat($0) } ?? nativeContentMinSize.width,
            height: bounds.minimumHeight.map { CGFloat($0) + chrome } ?? nativeContentMinSize.height)
        window.contentMinSize = minimum
        window.contentMaxSize = NSSize(
            width: max(minimum.width, bounds.maximumWidth.map { CGFloat($0) } ?? nativeContentMaxSize.width),
            height: max(minimum.height, bounds.maximumHeight.map { CGFloat($0) + chrome } ?? nativeContentMaxSize.height))
    }

    /// Makes the window what the tree says: its zoom and minimize buttons, the desktop through it, and whether it
    /// floats over the application's other windows.
    private func apply(_ traits: WindowTraits, _ window: NSWindow) {
        self.traits = traits
        window.standardWindowButton(.zoomButton)?.isEnabled = traits.isMaximizable ?? nativeAllowsZoom
        let allowsMinimizing = traits.isMinimizable ?? nativeAllowsMinimizing
        if allowsMinimizing {
            window.styleMask.insert(.miniaturizable)
        } else {
            window.styleMask.remove(.miniaturizable)
        }
        window.standardWindowButton(.miniaturizeButton)?.isEnabled = allowsMinimizing
        isTranslucent = traits.isTranslucent
        window.isOpaque = !isTranslucent
        content.isTranslucent = isTranslucent
        window.level = traits.floatsOnTop ? .floating : .normal
    }

    /// Takes the window off the screen while its scene hides it, and back once it does not.
    private func setHidden(_ hidden: Bool, _ window: NSWindow) {
        hiddenByScene = hidden
        guard presented else { return }

        if hidden {
            if window.isVisible { window.orderOut(nil) }
        } else if presentsWindow {
            window.orderFront(nil)
        }
    }
}

#endif
