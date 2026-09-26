// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
import Foundation
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// What AppKit tells of the window - the keyboard coming and going, minimizing, closing, restoration - handed to the
/// host layer, which settles what each scene and window hears.
/// Design: docs/design/platforms/appkit/runtime.md#the-applications-phase
extension AppKitWindowController: NSWindowDelegate {
    /// The tree no longer holds the window: its page hears it goes, its sheets go, and it closes, telling nothing.
    func closeFromTree() {
        guard !closingFromTree else { return }
        closingFromTree = true
        (presentation.sheets.last ?? presentation.arrangement)?.setPagePresented(false, reason: .window)

        if let window {
            while !modals.isEmpty {
                let parent = modals.count == 1
                    ? window
                    : (modals[modals.count - 2].window ?? window)
                modals.removeLast().dismiss(from: parent)
            }
        }
        close()
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
        isKey = true
        host?.windowBecameKey(self)
    }

    func windowDidResignKey(_ notification: Notification) {
        isKey = false
        host?.windowStateChanged(self)
    }

    func windowShouldZoom(_ window: NSWindow, toFrame newFrame: NSRect) -> Bool {
        traits?.isMaximizable ?? nativeAllowsZoom
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
        isMinimized = true
        host?.windowStateChanged(self)
    }

    func windowDidDeminiaturize(_ notification: Notification) {
        isMinimized = false
        host?.windowStateChanged(self)
    }
}

#endif
