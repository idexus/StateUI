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
    let stateUIID: ElementId
    private weak var host: AppKitRenderer?
    private let presentsWindows: Bool
    private var windows: [ElementId: AppKitWindowController] = [:]
    private var windowOrder: [ElementId] = []
    private weak var node: MountedNode?
    private(set) var sessionIdentifier: String?
    private var kept: [String: HostValue] = [:]
    private var lastPhase: Event?

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

    func report(_ event: Event, payload: [HostValue] = []) {
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
        for window in orderedWindows where !window.isMain {
            window.setSceneActive(active)
        }
    }

    func applicationWasHidden() {
        report(.stopped)
        for window in orderedWindows { window.applicationWasHidden() }
    }

    func applicationWasUnhidden() {
        report(.deactivated)
        for window in orderedWindows { window.applicationWasUnhidden() }
    }
}

@MainActor
final class AppKitWindowController: NSWindowController, NSWindowDelegate {
    let stateUIID: ElementId
    weak var scene: AppKitSceneController?
    var sceneID: ElementId? { scene?.stateUIID }
    let isMain: Bool
    private weak var host: AppKitRenderer?
    private weak var node: MountedNode?
    private let presentsWindow: Bool
    private var record: AppKitRestorationRecord
    var restorationRecordForTesting: AppKitRestorationRecord { record }
    private var requestedSize: NSSize?
    private var requestedPosition: NSPoint?
    private var presented = false
    private var sentCreated = false
    private var hiddenByScene = false
    private var stoppedByApplication = false
    private var lastWindowEvent: Event?
    private(set) var closingFromTree = false
    private var presentedPage: MountedNode?
    private var modals: [AppKitModalWindowController] = []
    private let content = AppKitWindowContentView()

    var pageMenuItems: [NSMenuItem] {
        modals.last?.node.pageMenuItems ?? node?.pageMenuItems ?? []
    }
    var pageMenuItemsForTesting: [NSMenuItem] { pageMenuItems }
    var modalCountForTesting: Int { modals.count }

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
        window.isReleasedWhenClosed = false
        super.init(window: window)

        window.delegate = self
        window.identifier = NSUserInterfaceItemIdentifier(record.windowIdentifier)
        window.isRestorable = true
        window.restorationClass = AppKitWindowRestorer.self
        window.setFrameAutosaveName("StateUI.\(record.windowIdentifier)")
    }

    static func makeWindow() -> NSWindow {
        NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 440),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false)
    }

    required init?(coder: NSCoder) {
        nil
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

        let size = NSSize(
            width: node.number(.width) ?? requestedSize?.width ?? 560,
            height: node.number(.height) ?? requestedSize?.height ?? 440)
        if requestedSize != size {
            window.setContentSize(size)
            requestedSize = size
        }

        if let x = node.number(.x), let y = node.number(.y), let screen = window.screen ?? NSScreen.main {
            let origin = NSPoint(x: x, y: screen.visibleFrame.maxY - y - window.frame.height)
            if requestedPosition != origin {
                window.setFrameOrigin(origin)
                requestedPosition = origin
            }
        } else if !presented {
            window.center()
            if cascade > 0 {
                window.setFrameOrigin(NSPoint(
                    x: window.frame.origin.x + CGFloat(cascade * 24),
                    y: window.frame.origin.y - CGFloat(cascade * 24)))
            }
        }

        content.set(page: node.pageView, overlay: node.overlayItem)
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

        window.contentMinSize = NSSize(
            width: node.number(.minimumWidth) ?? 0,
            height: node.number(.minimumHeight) ?? 0)
        window.contentMaxSize = NSSize(
            width: node.number(.maximumWidth) ?? .greatestFiniteMagnitude,
            height: node.number(.maximumHeight) ?? .greatestFiniteMagnitude)
        window.standardWindowButton(.zoomButton)?.isEnabled = node.bool(.isMaximizable) ?? true
        window.standardWindowButton(.miniaturizeButton)?.isEnabled = node.bool(.isMinimizable) ?? true
        window.isExcludedFromWindowsMenu = !isMain
        window.level = node.bool(.floatsOnTop) == true ? .floating : .normal
        window.hidesOnDeactivate = node.bool(.floatsOnTop) == true

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
        if presentsWindow { window.makeKeyAndOrderFront(nil) }
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

    private func refreshVisiblePageChrome() {
        guard let node, let window else { return }
        let visible = modals.last?.node.visibleContentPage ?? node.visibleContentPage
        window.title = node.string(.title) ?? visible?.string(.title) ?? "StateUI"
        let navigation = modals.last?.node.visibleNavigationPage ?? node.visibleNavigationPage
        let barColor = navigation?.showsVisibleNavigationBar == true
            ? navigation?.color(.barBackgroundColor)
            : nil
        synchronizeTitleBar(window, color: barColor)
        host?.pageMenusChanged(in: self)
    }

    /// Continues an authored navigation bar through AppKit's title-bar area.
    /// The content view then extends under the transparent native chrome and
    /// the navigation view reserves the window's safe-area inset before laying
    /// out its own controls.
    private func synchronizeTitleBar(_ window: NSWindow, color: NSColor?) {
        if let color {
            window.styleMask.insert(.fullSizeContentView)
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.titlebarSeparatorStyle = .none
            window.backgroundColor = color
        } else {
            window.styleMask.remove(.fullSizeContentView)
            window.titlebarAppearsTransparent = false
            window.titleVisibility = .visible
            window.titlebarSeparatorStyle = .automatic
            window.backgroundColor = .windowBackgroundColor
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
        guard node?.bool(.autoHide) == true, let window else { return }

        if active, hiddenByScene {
            hiddenByScene = false
            if presentsWindow { window.orderFront(nil) }
            reportWindow(.resumed)
        } else if !active, !hiddenByScene, window.isVisible {
            hiddenByScene = true
            window.orderOut(nil)
            reportWindow(.stopped)
        }
    }

    func applicationWasHidden() {
        guard !stoppedByApplication else { return }
        stoppedByApplication = true
        reportWindow(.stopped)
    }

    func applicationWasUnhidden() {
        guard stoppedByApplication else { return }
        stoppedByApplication = false
        reportWindow(.resumed)
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

    func windowWillClose(_ notification: Notification) {
        host?.windowWillClose(self)
    }

    func windowDidMiniaturize(_ notification: Notification) {
        reportWindow(.stopped)
        if isMain { scene?.report(.stopped) }
    }

    func windowDidDeminiaturize(_ notification: Notification) {
        reportWindow(.resumed)
        if isMain { scene?.report(.deactivated) }
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
