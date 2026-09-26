// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
import Foundation
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

extension AppKitWindowController: NSWindowDelegate {
    func closeFromTree() {
        guard !closingFromTree else { return }
        closingFromTree = true
        let visible = (modals.last?.node ?? presentedPage)?.element
        visible?.appKit.setPagePresented(false, reason: .window)

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
        host?.dispatch(handler, isPhase: true)
    }

    func setSceneActive(_ active: Bool) {
        sceneIsActive = active
        synchronizeSceneVisibility()
    }

    func synchronizeSceneVisibility() {
        guard let node, let window else { return }
        let shouldHide = node.bool(.hidesWhenInactive) == true && !sceneIsActive

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
        focusWatch?.invalidate()
        focusWatch = nil
        host?.windowWillClose(self)
    }

    /// The first responder of this window, or of a sheet over it, moved.
    func focusMoved() {
        host?.focusMoved()
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

#endif
