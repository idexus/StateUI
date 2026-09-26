// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
import Foundation
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

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
    private weak var node: AppKitElement?
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

    func synchronize(_ node: AppKitElement, cascadeFrom: Int = 0) {
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

        let isPhase = [.activated, .deactivated, .stopped, .destroying].contains(event)
        if [.activated, .deactivated, .stopped].contains(event) {
            lastPhase = event
        }
        host?.dispatch(handler, payload: payload, isPhase: isPhase)
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

#endif
