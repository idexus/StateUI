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
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 480),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false)
        window.isReleasedWhenClosed = false
        // Tab and Shift-Tab go through the views as they stand on screen: AppKit works the loop out.
        window.autorecalculatesKeyViewLoop = true
        super.init(window: window)
        toolbar.window = window
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

        content.visiblePage = element.visiblePage
        content.showBottomBar(of: element.visiblePage)
        content.set(page: node.presentablePageView, overlays: [])
        let chrome = WindowChrome(window: element, arrangement: element)
        window.title = chrome.title ?? node.core.applicationName
        showBar(chrome, in: window)
        showGround()
        standAtItsSize(node, in: window)
    }

    /// Stands the sheet on its window's background laid over the platform's own sheet (`overlaidGround`): a blur in
    /// its tint, else its color over the sheet's own; the sheet's own where the window says none.
    /// Design: docs/design/platforms/appkit/runtime.md#sheets
    func showGround() {
        guard let window else { return }
        let ground = element.overlaidGround
        let written = ground.paint.flatMap(nsColor)
        content.backdrop = ground.blur
        content.materialTint = ground.blur != nil ? written : nil
        let own = NSColor.windowBackgroundColor
        let color: NSColor = if ground.blur != nil {
            .clear
        } else if let written, written.alphaComponent < 1 {
            own.blended(withFraction: written.alphaComponent, of: written.withAlphaComponent(1)) ?? written
        } else {
            written ?? own
        }
        window.isOpaque = ground.blur == nil
        if window.backgroundColor != color { window.backgroundColor = color }
    }

    /// The size the sheet last stood at as its page asked: the user's resize stands until the page asks another.
    private var asked: LayoutSize?

    /// Stands the sheet as large as its page asks, within the room an AppKit sheet has - at least 320 x 180, 560 x 480
    /// for a page asking none, at most the window it hangs from less 24 points a side (`SheetSize`).
    /// Design: docs/design/platforms/appkit/runtime.md#sheets
    private func standAtItsSize(_ node: AppKitElement, in window: NSWindow) {
        guard let parent = window.sheetParent ?? stateUIOwner?.window else { return }
        let around = parent.contentLayoutRect.size
        let room = SheetRoom(
            least: LayoutSize(width: 320, height: 180), standard: LayoutSize(width: 560, height: 480),
            most: LayoutSize(width: Double(around.width) - 48, height: Double(around.height) - 48))
        let size = SheetSize.size(of: element, in: room) { node.layoutItem?.size(offered: $0) ?? room.least }
        // The content runs under the title bar and the toolbar: the page's room is what they leave of it.
        let over = content.frame.height - window.contentLayoutRect.height
        let standing = LayoutSize(width: size.width, height: size.height + Double(over))
        guard standing != asked else { return }
        asked = standing
        window.setContentSize(NSSize(width: standing.width, height: standing.height))
    }

    /// The bar a stack in the sheet brings, as the window's toolbar shows a stack's: the way back, the page's
    /// actions and, where the page offers it, the button closing the sheet, on the band its look paints; none where no
    /// stack brings one.
    /// Design: docs/design/platforms/appkit/runtime.md#sheets
    private func showBar(_ chrome: WindowChrome, in window: NSWindow) {
        let brush = element.bringsABar ? AppKitBrush(chrome.background) : AppKitBrush()
        window.titlebarAppearsTransparent = brush.paints
        content.barBrush = brush
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
        guard window.toolbar !== toolbar.toolbar else { return }
        // Its items first, else AppKit fills an empty bar from its defaults again; then it fits in its window.
        window.toolbar = toolbar.toolbar
        toolbar.fitAgain()
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

    /// The sheet resized: its bar fits itself to its width again.
    func windowDidResize(_ notification: Notification) {
        toolbar.fitAgain()
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        stateUIOwner?.userDismissed(self)
        return false
    }
}

#endif
