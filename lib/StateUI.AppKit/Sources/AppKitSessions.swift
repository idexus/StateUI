// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
import Foundation
@_spi(Host) import StateUI

/// The platform identity and StateUI ownership needed to restore one window.
///
/// A main window has no owner and keeps its scene values. Every other window
/// names the main window it belongs to, plus its StateUI group and value. The
/// platform identity is intentionally separate from `ElementId`: StateUI ids
/// are deterministic inside one process, while AppKit ids survive relaunch.
struct AppKitRestorationRecord: Equatable, Sendable {
    let windowIdentifier: String
    let ownerIdentifier: String?
    let kind: String?
    let value: String?
    var kept: [String: HostValue]

    init(
        windowIdentifier: String,
        ownerIdentifier: String? = nil,
        kind: String? = nil,
        value: String? = nil,
        kept: [String: HostValue] = [:]
    ) {
        self.windowIdentifier = windowIdentifier
        self.ownerIdentifier = ownerIdentifier
        self.kind = kind
        self.value = value
        self.kept = kept
    }

    init(data: Data) throws {
        let payload = try JSONDecoder().decode(Payload.self, from: data)
        guard payload.version == Payload.currentVersion else {
            throw DecodingError.dataCorrupted(.init(
                codingPath: [],
                debugDescription: "unsupported StateUI AppKit restoration version"))
        }

        windowIdentifier = payload.windowIdentifier
        ownerIdentifier = payload.ownerIdentifier
        kind = payload.kind
        value = payload.value
        kept = payload.kept.mapValues(\.hostValue)
    }

    func data() throws -> Data {
        var stored: [String: StoredValue] = [:]

        for (name, value) in kept {
            guard let value = StoredValue(value) else { continue }
            stored[name] = value
        }

        return try JSONEncoder().encode(Payload(
            version: Payload.currentVersion,
            windowIdentifier: windowIdentifier,
            ownerIdentifier: ownerIdentifier,
            kind: kind,
            value: value,
            kept: stored))
    }

    private struct Payload: Codable {
        static let currentVersion = 1

        let version: Int
        let windowIdentifier: String
        let ownerIdentifier: String?
        let kind: String?
        let value: String?
        let kept: [String: StoredValue]
    }

    private enum StoredValue: Codable {
        case bool(Bool)
        case number(Double)
        case string(String)

        init?(_ value: HostValue) {
            switch value {
            case .bool(let value): self = .bool(value)
            case .number(let value): self = .number(value)
            case .string(let value): self = .string(value)
            default: return nil
            }
        }

        var hostValue: HostValue {
            switch self {
            case .bool(let value): .bool(value)
            case .number(let value): .number(value)
            case .string(let value): .string(value)
            }
        }
    }
}

/// Restored windows waiting for the deterministic StateUI tree to claim them.
/// AppKit makes no ordering promise, so an owned window may arrive first.
final class AppKitRestorationQueue {
    private var records: [AppKitRestorationRecord] = []

    var isEmpty: Bool { records.isEmpty }
    var hasMain: Bool { records.contains { $0.ownerIdentifier == nil } }
    var all: [AppKitRestorationRecord] { records }

    func append(_ record: AppKitRestorationRecord) {
        guard !records.contains(where: { $0.windowIdentifier == record.windowIdentifier }) else {
            return
        }

        records.append(record)
    }

    func takeMain() -> AppKitRestorationRecord? {
        take { $0.ownerIdentifier == nil }
    }

    func takeOwned(by owner: String, kind: String?, value: String?) -> AppKitRestorationRecord? {
        take { record in
            record.ownerIdentifier == owner && record.kind == kind && record.value == value
        }
    }

    func owned(by owner: String) -> [AppKitRestorationRecord] {
        records.filter { $0.ownerIdentifier == owner }
    }

    func remove(windowIdentifier: String) -> AppKitRestorationRecord? {
        take { $0.windowIdentifier == windowIdentifier }
    }

    private func take(
        where matches: (AppKitRestorationRecord) -> Bool
    ) -> AppKitRestorationRecord? {
        guard let index = records.firstIndex(where: matches) else { return nil }
        return records.remove(at: index)
    }
}

@MainActor
struct AppKitRestoredWindow {
    let record: AppKitRestorationRecord
    let window: NSWindow
}

@MainActor
final class AppKitRestorationBroker {
    static let shared = AppKitRestorationBroker()
    weak var host: AppKitRenderer?

    private init() {}

    func restore(_ record: AppKitRestorationRecord) -> NSWindow? {
        host?.acceptRestoredWindow(record)
    }
}

@MainActor
final class AppKitSceneController {
    private enum BackgroundCause: Hashable {
        case applicationHidden
        case mainWindowMiniaturized
    }

    let stateUIID: ElementId
    private weak var host: AppKitRenderer?
    private let presentsWindows: Bool
    private var windows: [ElementId: AppKitWindowController] = [:]
    private var windowOrder: [ElementId] = []
    private weak var node: MountedNode?
    private(set) var sessionIdentifier: String?
    private var kept: [String: HostValue] = [:]
    private var lastPhase: Event?
    private var isActive = false
    // Native notifications can overlap; the scene leaves the background only
    // after every cause that put its main lifecycle there has ended.
    private var backgroundCauses: Set<BackgroundCause> = []

    private var restoredMain: AppKitRestoredWindow?

    init(
        id: ElementId,
        host: AppKitRenderer,
        presentsWindows: Bool,
        restoredMain: AppKitRestoredWindow? = nil
    ) {
        stateUIID = id
        self.host = host
        self.presentsWindows = presentsWindows
        self.restoredMain = restoredMain
        sessionIdentifier = restoredMain?.record.windowIdentifier
        kept = restoredMain?.record.kept ?? [:]
    }

    var orderedWindows: [AppKitWindowController] {
        windowOrder.compactMap { windows[$0] }
    }

    func synchronize(_ node: MountedNode, cascadeFrom: Int = 0) {
        self.node = node

        let windowNodes = node.children.filter { $0.type == .window }
        let nextOrder = windowNodes.map(\.id)
        let nextSet = Set(nextOrder)

        for id in windowOrder where !nextSet.contains(id) {
            windows.removeValue(forKey: id)?.closeFromTree()
        }

        for (index, windowNode) in windowNodes.enumerated() {
            let isMain = windowNode.name(.windowType) == nil
            let controller: AppKitWindowController

            if let standing = windows[windowNode.id] {
                controller = standing
            } else {
                let restored: AppKitRestoredWindow?
                if isMain {
                    restored = restoredMain
                    restoredMain = nil
                } else if let owner = sessionIdentifier {
                    restored = host?.takeRestoredWindow(
                        owner: owner,
                        kind: windowNode.name(.windowType),
                        value: windowNode.string(.windowValue))
                } else {
                    restored = nil
                }

                let identifier = restored?.record.windowIdentifier ?? UUID().uuidString
                if isMain { sessionIdentifier = identifier }

                let record = restored?.record ?? AppKitRestorationRecord(
                    windowIdentifier: identifier,
                    ownerIdentifier: isMain ? nil : sessionIdentifier,
                    kind: windowNode.name(.windowType),
                    value: windowNode.string(.windowValue),
                    kept: isMain ? kept : [:])
                controller = AppKitWindowController(
                    stateUIID: windowNode.id,
                    scene: self,
                    host: host,
                    isMain: isMain,
                    record: record,
                    nativeWindow: restored?.window,
                    presentsWindow: presentsWindows)
                windows[windowNode.id] = controller
            }

            controller.setSceneActive(isActive)
            controller.synchronize(windowNode, cascade: cascadeFrom + index)
        }

        windowOrder = nextOrder
    }

    func closeFromTree() {
        for window in orderedWindows.reversed() {
            window.closeFromTree()
        }

        windows.removeAll()
        windowOrder.removeAll()
    }

    func report(_ reportedEvent: Event, payload: [HostValue] = []) {
        let event: Event
        if reportedEvent == .activated, backgroundCauses.contains(.applicationHidden) {
            event = .stopped
        } else if reportedEvent == .deactivated, !backgroundCauses.isEmpty {
            event = .stopped
        } else {
            event = reportedEvent
        }

        guard lastPhase != event || ![.activated, .deactivated, .stopped].contains(event),
              let handler = node?.handler(event)
        else { return }

        if [.activated, .deactivated, .stopped].contains(event) {
            lastPhase = event
        }
        host?.dispatch(handler, payload: payload)
    }

    func keep(name: String, value: HostValue) {
        kept[name] = value
        windows.values.first(where: \.isMain)?.keepSceneValues(kept)
    }

    var restoredWindowHandler: Int32? { node?.handler(.windowRestored) }

    func setActive(_ active: Bool) {
        isActive = active
        for window in orderedWindows where !window.isMain {
            window.setSceneActive(active)
        }
    }

    func applicationWasHidden() {
        setBackgroundCause(.applicationHidden, present: true)
        for window in orderedWindows { window.applicationWasHidden() }
    }

    func applicationWasUnhidden() {
        setBackgroundCause(.applicationHidden, present: false)
        for window in orderedWindows { window.applicationWasUnhidden() }
    }

    func setMainWindowMiniaturized(_ miniaturized: Bool) {
        setBackgroundCause(.mainWindowMiniaturized, present: miniaturized)
    }

    private func setBackgroundCause(_ cause: BackgroundCause, present: Bool) {
        if present {
            backgroundCauses.insert(cause)
        } else {
            backgroundCauses.remove(cause)
        }

        report(backgroundCauses.isEmpty ? .deactivated : .stopped)
    }
}

@MainActor
final class AppKitWindowController: NSWindowController, NSWindowDelegate {
    private enum StopCause: Hashable {
        case applicationHidden
        case miniaturized
        case sceneHidden
    }

    let stateUIID: ElementId
    weak var scene: AppKitSceneController?
    var sceneID: ElementId? { scene?.stateUIID }
    let isMain: Bool
    private weak var host: AppKitRenderer?
    private weak var node: MountedNode?
    private let presentsWindow: Bool
    private var record: AppKitRestorationRecord
    var restorationRecordForTesting: AppKitRestorationRecord { record }
    private var lastWidthRequest: CGFloat?
    private var lastHeightRequest: CGFloat?
    private var lastXRequest: CGFloat?
    private var lastYRequest: CGFloat?
    private var presented = false
    private var sentCreated = false
    // One effective stopped transition spans every simultaneous native cause.
    private var stopCauses: Set<StopCause> = []
    private var lastWindowEvent: Event?
    private(set) var closingFromTree = false
    private var presentedPage: MountedNode?
    private var modals: [AppKitModalWindowController] = []
    private lazy var toolbar = AppKitWindowToolbar(windowIdentifier: record.windowIdentifier)
    private var titleAccessory: NSTitlebarAccessoryViewController?
    private let titleCluster = AppKitTitleBarTitleView()
    private let content = AppKitWindowContentView()
    private let nativeContentMinSize: NSSize
    private let nativeContentMaxSize: NSSize
    private let nativeAllowsZoom: Bool
    private let nativeAllowsMinimizing: Bool
    private var sceneIsActive = false

    var pageMenuItems: [NSMenuItem] {
        modals.last?.node.pageMenuItems ?? node?.pageMenuItems ?? []
    }
    var pageMenuItemsForTesting: [NSMenuItem] { pageMenuItems }
    var modalCountForTesting: Int { modals.count }
    var hiddenBySceneForTesting: Bool { stopCauses.contains(.sceneHidden) }
    var toolbarForTesting: AppKitWindowToolbar { toolbar }
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

    func presents(_ candidate: MountedNode) -> Bool {
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

    func synchronize(_ node: MountedNode, cascade: Int) {
        self.node = node
        guard let window else { return }
        let previousVisible = modals.last?.node ?? presentedPage
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

        let nextVisible = modals.last?.node ?? presentedPage
        if previousVisible !== nextVisible {
            let reason: AppKitPagePresentationReason = previousWasModal || !modals.isEmpty
                ? .navigation
                : .window
            previousVisible?.setPagePresented(false, reason: reason)
            nextVisible?.setPagePresented(true, reason: reason)
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

    private func synchronizeModals(_ target: [MountedNode]) {
        guard let window else { return }

        var common = 0
        while common < modals.count, common < target.count,
              modals[common].node === target[common] {
            modals[common].synchronize(target[common])
            common += 1
        }

        while modals.count > common {
            let index = modals.count - 1
            let parent = index == 0 ? window : (modals[index - 1].window ?? window)
            modals.removeLast().dismiss(from: parent)
        }

        for index in common..<target.count {
            let modal = AppKitModalWindowController(node: target[index], owner: self)
            let parent = modals.last?.window ?? window
            modals.append(modal)
            modal.present(over: parent, actuallyPresent: presentsWindow)
        }
    }

    fileprivate func readerDismissed(_ modal: AppKitModalWindowController) {
        guard let window, modals.last === modal else { return }
        let previous = modal.node
        let parent = modals.count == 1
            ? window
            : (modals[modals.count - 2].window ?? window)
        modals.removeLast().dismiss(from: parent)
        let next = modals.last?.node ?? presentedPage

        previous.setPagePresented(false, reason: .navigation)
        next?.setPagePresented(true, reason: .navigation)
        refreshVisiblePageChrome()
        host?.commit(node?.handler(.modalPopped), payload: [.number(Double(modals.count))])
    }

    /// Composes the window's one native chrome from the visible arrangement:
    /// the top page names the window, the stack's way back and the page's
    /// actions are toolbar items, a split page adds the sidebar toggle, and
    /// an authored title bar adds its slots and its own title.
    private func refreshVisiblePageChrome() {
        guard let node, let window else { return }
        let titleBar = node.children.first { $0.type == .titleBar }
        let page = node.visibleContentPage
        let titleView = node.visibleTitleView
        window.title = page?.string(.title) ?? node.string(.title) ?? "StateUI"
        window.subtitle = ""
        // A page's title view stands in for its title: the window keeps its
        // name for the system and shows the view instead.
        window.titleVisibility = titleView == nil ? .visible : .hidden

        let actions = node.visibleToolbarActions
        toolbar.apply(AppKitWindowChrome(
            sidebar: node.pageNode?.sidebarController,
            back: node.visibleBackAction,
            leading: titleBar?.firstView(in: .leadingContent),
            center: titleBar?.firstView(in: .content) ?? titleView,
            actions: actions.primary,
            overflow: actions.overflow,
            trailing: titleBar?.firstView(in: .trailingContent)))
        synchronizeTitleAccessory(window, titleBar: titleBar)
        host?.pageMenusChanged(in: self)
    }

    /// An authored title bar's own title stands at the trailing edge of the
    /// window's title bar, where it is text rather than a toolbar control.
    private func synchronizeTitleAccessory(_ window: NSWindow, titleBar: MountedNode?) {
        let title = titleBar?.string(.title)
        let subtitle = titleBar?.string(.subtitle)
        let icon = titleBar?.image(.icon)
        guard title != nil || subtitle != nil || icon != nil else {
            if let accessory = titleAccessory,
               let index = window.titlebarAccessoryViewControllers.firstIndex(of: accessory) {
                window.removeTitlebarAccessoryViewController(at: index)
            }
            titleAccessory = nil
            return
        }

        titleCluster.apply(title: title ?? "", subtitle: subtitle ?? "", image: icon)
        // AppKit gives a trailing accessory the toolbar row's height and
        // centres it there; only the width is the cluster's own.
        let fitting = titleCluster.fittingSize
        if titleAccessory != nil {
            if titleCluster.frame.width != fitting.width {
                titleCluster.frame.size.width = fitting.width
            }
        } else {
            titleCluster.frame.size = fitting
            let accessory = NSTitlebarAccessoryViewController()
            accessory.layoutAttribute = .trailing
            accessory.view = titleCluster
            window.addTitlebarAccessoryViewController(accessory)
            titleAccessory = accessory
        }
    }

    func dismissTopModalForTesting() {
        guard let modal = modals.last else { return }
        readerDismissed(modal)
    }

    func closeFromTree() {
        guard !closingFromTree else { return }
        closingFromTree = true
        let visible = modals.last?.node ?? presentedPage
        visible?.setPagePresented(false, reason: .window)

        if let window {
            while !modals.isEmpty {
                let parent = modals.count == 1
                    ? window
                    : (modals[modals.count - 2].window ?? window)
                modals.removeLast().dismiss(from: parent)
            }
        }
        presentedPage = nil
        close()
    }

    func reportWindow(_ event: Event) {
        guard lastWindowEvent != event, let handler = node?.handler(event) else { return }
        lastWindowEvent = event
        host?.dispatch(handler)
    }

    func setSceneActive(_ active: Bool) {
        sceneIsActive = active
        synchronizeSceneVisibility()
    }

    private func synchronizeSceneVisibility() {
        guard let node, let window else { return }
        let shouldHide = node.bool(.autoHide) == true && !sceneIsActive

        guard presented else {
            if shouldHide {
                stopCauses.insert(.sceneHidden)
            } else {
                stopCauses.remove(.sceneHidden)
            }
            return
        }

        setStoppedCause(.sceneHidden, present: shouldHide) {
            if shouldHide {
                if window.isVisible { window.orderOut(nil) }
            } else if presentsWindow {
                window.orderFront(nil)
            }
        }
    }

    func applicationWasHidden() {
        setStoppedCause(.applicationHidden, present: true)
    }

    func applicationWasUnhidden() {
        setStoppedCause(.applicationHidden, present: false)
    }

    private func setStoppedCause(
        _ cause: StopCause,
        present: Bool,
        updateNativeWindow: () -> Void = {}
    ) {
        let wasStopped = !stopCauses.isEmpty
        let changed: Bool
        if present {
            changed = stopCauses.insert(cause).inserted
        } else {
            changed = stopCauses.remove(cause) != nil
        }
        updateNativeWindow()
        guard changed else { return }

        if !wasStopped, !stopCauses.isEmpty {
            reportWindow(.stopped)
        } else if wasStopped, stopCauses.isEmpty {
            reportWindow(.resumed)
        }
    }

    func keepSceneValues(_ values: [String: HostValue]) {
        guard isMain else { return }
        record.kept = values
        window?.invalidateRestorableState()
    }

    func window(_ window: NSWindow, willEncodeRestorableState state: NSCoder) {
        if let data = try? record.data() {
            state.encode(data as NSData, forKey: AppKitWindowRestorer.recordKey)
        }
    }

    func windowDidBecomeKey(_ notification: Notification) {
        host?.windowBecameKey(self)
    }

    func windowDidResignKey(_ notification: Notification) {
        host?.windowResignedKey(self)
    }

    func windowShouldZoom(_ window: NSWindow, toFrame newFrame: NSRect) -> Bool {
        node?.bool(.isMaximizable) ?? nativeAllowsZoom
    }

    func windowWillClose(_ notification: Notification) {
        host?.windowWillClose(self)
    }

    func windowDidMiniaturize(_ notification: Notification) {
        setStoppedCause(.miniaturized, present: true)
        if isMain { scene?.setMainWindowMiniaturized(true) }
    }

    func windowDidDeminiaturize(_ notification: Notification) {
        setStoppedCause(.miniaturized, present: false)
        if isMain { scene?.setMainWindowMiniaturized(false) }
    }
}

/// One native sheet in the modal arrangement owned by a StateUI window.
@MainActor
final class AppKitModalWindowController: NSWindowController, NSWindowDelegate {
    private(set) var node: MountedNode
    private weak var stateUIOwner: AppKitWindowController?

    init(node: MountedNode, owner: AppKitWindowController) {
        self.node = node
        stateUIOwner = owner

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 380),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false)
        window.isReleasedWhenClosed = false
        super.init(window: window)
        window.delegate = self
        synchronize(node)
    }

    required init?(coder: NSCoder) {
        nil
    }

    func synchronize(_ node: MountedNode) {
        self.node = node
        guard let window else { return }

        if let content = node.presentablePageView, window.contentView !== content {
            content.frame = NSRect(origin: .zero, size: window.contentLayoutRect.size)
            content.autoresizingMask = [.width, .height]
            window.contentView = content
        }
        window.title = node.visibleContentPage?.string(.title) ?? "StateUI"
    }

    func present(over parent: NSWindow, actuallyPresent: Bool) {
        guard actuallyPresent, let window, window.sheetParent == nil else { return }
        parent.beginSheet(window)
    }

    func dismiss(from parent: NSWindow) {
        guard let window else { return }
        window.delegate = nil
        if window.sheetParent != nil { parent.endSheet(window) }
        window.orderOut(nil)
        window.close()
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        stateUIOwner?.readerDismissed(self)
        return false
    }
}

@MainActor
final class AppKitWindowRestorer: NSObject, NSWindowRestoration {
    static let recordKey = "StateUI.RestorationRecord"

    static func restoreWindow(
        withIdentifier identifier: NSUserInterfaceItemIdentifier,
        state: NSCoder,
        completionHandler: @escaping (NSWindow?, (any Error)?) -> Void
    ) {
        guard let data = state.decodeObject(of: NSData.self, forKey: recordKey) as Data? else {
            completionHandler(nil, nil)
            return
        }

        do {
            let record = try AppKitRestorationRecord(data: data)
            guard record.windowIdentifier == identifier.rawValue,
                  let window = AppKitRestorationBroker.shared.restore(record)
            else {
                completionHandler(nil, nil)
                return
            }

            completionHandler(window, nil)
        } catch {
            NSLog("StateUI AppKit: ignored an unreadable restoration record: %@", String(describing: error))
            completionHandler(nil, nil)
        }
    }
}

extension ElementId {
    var hostPayload: HostValue {
        switch self {
        case .manual(let value): .string(value)
        case .auto(let value): .number(Double(value))
        }
    }
}

#endif
