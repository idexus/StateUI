// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
import Foundation
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// One native sheet in the modal arrangement owned by a StateUI window.
@MainActor
final class AppKitModalWindowController: NSWindowController, NSWindowDelegate {
    /// The sheet's page, held by its mounted element, which owns its AppKit half.
    private var element: MountedElement
    var node: AppKitElement { element.appKit }
    private weak var stateUIOwner: AppKitWindowController?

    /// The sheet's first responder, watched for its owner.
    private var focusWatch: NSKeyValueObservation?

    /// The sheet's root, a window's: the page laid in it, its drags, and the frames its layout reports.
    private let content = AppKitWindowContentView()

    /// The bar a stack in the sheet brings; a sheet has none of its own.
    private let toolbar: AppKitWindowToolbar
    var toolbarForTesting: AppKitWindowToolbar { toolbar }

    init(node: AppKitElement, owner: AppKitWindowController) {
        element = node.element
        stateUIOwner = owner
        toolbar = AppKitWindowToolbar(windowIdentifier: "Sheet.\(node.element.mount)")

        let window = AppKitWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 380),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false)
        window.isReleasedWhenClosed = false
        // Tab and Shift-Tab go through the views as they stand on screen: AppKit works the loop out.
        window.autorecalculatesKeyViewLoop = true
        super.init(window: window)
        window.contentView = content
        content.drops = AppKitDrops { [weak host = node.host] in host?.dropTakers() ?? [:] }
        content.reportsLaidOut = { [weak host = node.host] in host?.runtime.frames.reportLaidOut() ?? false }
        window.delegate = self
        window.takesKey = { [weak owner, weak window] key, modifiers in
            owner?.takesKey(key, modifiers, in: window) ?? false
        }
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

        content.set(page: node.presentablePageView, overlays: [])
        let chrome = WindowChrome(window: element, arrangement: element)
        window.title = chrome.title ?? node.core.applicationName
        showBar(chrome, in: window)
    }

    /// The bar a stack in the sheet brings, as the window's toolbar shows a stack's: the way back, the page's
    /// actions and, where the page offers it, the button closing the sheet; none where no stack brings one.
    /// Design: docs/design/platforms/appkit/runtime.md#sheets
    private func showBar(_ chrome: WindowChrome, in window: NSWindow) {
        guard element.bringsABar else { return window.toolbar = nil }
        let words = element.appKit.core.chromeWords
        toolbar.apply(AppKitWindowChrome(
            back: chrome.back.map { back in
                AppKitToolbarAction(
                    identifier: AppKitWindowToolbar.back, title: back.title,
                    image: AppKitWindowToolbar.backImage(saying: words.back), isEnabled: true,
                    perform: { [weak stateUIOwner, weak stack = back.stack] in
                        if let stack { stateUIOwner?.goBack(.pop(stack)) }
                    })
            },
            leadingActions: chrome.actions.start.map { $0.map(AppKitWindowController.action) },
            actions: chrome.actions.end.map { $0.map(AppKitWindowController.action) },
            overflow: chrome.actions.overflow.map(AppKitWindowController.action),
            close: element.offersClose
                ? AppKitToolbarAction(
                    identifier: AppKitWindowToolbar.close, title: words.close,
                    image: NSImage(systemSymbolName: "xmark", accessibilityDescription: words.close), isEnabled: true,
                    perform: { [weak self] in if let self { self.stateUIOwner?.userDismissed(self) } })
                : nil,
            words: words))
        if window.toolbar !== toolbar.toolbar { window.toolbar = toolbar.toolbar }
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
