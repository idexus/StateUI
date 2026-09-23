// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
import Foundation
@_spi(Host) import StateUI

/// One native sheet in the modal arrangement owned by a StateUI window.
@MainActor
final class AppKitModalWindowController: NSWindowController, NSWindowDelegate {
    /// The sheet's page, held by its mounted element, which owns its AppKit half.
    private var element: MountedElement
    var node: AppKitElement { element.appKit }
    private weak var stateUIOwner: AppKitWindowController?

    /// The sheet's first responder, watched for its owner.
    private var focusWatch: NSKeyValueObservation?

    init(node: AppKitElement, owner: AppKitWindowController) {
        element = node.element
        stateUIOwner = owner

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 380),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false)
        window.isReleasedWhenClosed = false
        super.init(window: window)
        window.delegate = self
        focusWatch = window.observe(\.firstResponder) { [weak self] _, _ in
            MainActor.assumeIsolated { self?.stateUIOwner?.focusMoved() }
        }
        synchronize(node)
    }

    required init?(coder: NSCoder) {
        nil
    }

    func synchronize(_ node: AppKitElement) {
        element = node.element
        guard let window else { return }

        if let content = node.presentablePageView, window.contentView !== content {
            content.frame = NSRect(origin: .zero, size: window.contentLayoutRect.size)
            content.autoresizingMask = [.width, .height]
            window.contentView = content
        }
        window.title = node.visiblePage?.string(.title) ?? "StateUI"
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
        stateUIOwner?.userDismissed(self)
        return false
    }
}

#endif
