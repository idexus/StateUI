// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit

/// A view's popover: AppKit's `NSPopover` holding the popover element's view, shown by its anchor and closed as the
/// user or the tree says; `onClosed` hears it gone, whoever closed it. Where its host shows no window - a test's -
/// it is held unshown, in a window of its own no one sees, as the test's windows are.
/// Design: docs/design/platforms/appkit/conformance.md#a-popover
@MainActor
final class AppKitPopover: NSObject, @MainActor NSPopoverDelegate {
    let popover = NSPopover()
    private let content: NSView
    private let onClosed: () -> Void

    /// The window the popover is held in unshown, while it is.
    private var unseen: NSPanel?

    /// The view the popover stands by while it shows.
    private weak var anchored: NSView?

    init(content: NSView, onClosed: @escaping () -> Void) {
        self.content = content
        self.onClosed = onClosed
        super.init()
        popover.behavior = .transient
        popover.delegate = self
    }

    /// Whether it stands shown, or held so.
    var isShown: Bool { popover.isShown || unseen != nil }

    /// Shows the popover by `anchor` at `size`, below it where there is room - held unshown unless `presenting`.
    func show(by anchor: NSView, size: NSSize, presenting: Bool) {
        guard presenting else {
            guard unseen == nil else { return }
            let window = NSPanel(
                contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered,
                defer: true)
            window.contentView = content
            unseen = window
            return
        }
        popover.contentSize = size
        // Shown by a view made anew - its branch flipped: it stands by the new one.
        if popover.isShown, anchored !== anchor {
            anchored = anchor
            return popover.show(relativeTo: anchor.bounds, of: anchor, preferredEdge: .maxY)
        }
        guard !popover.isShown else { return }
        anchored = anchor
        let controller = NSViewController()
        controller.view = content
        popover.contentViewController = controller
        popover.show(relativeTo: anchor.bounds, of: anchor, preferredEdge: .maxY)
    }

    func close() {
        guard let unseen else { return popover.isShown ? popover.close() : () }
        unseen.contentView = nil
        self.unseen = nil
        onClosed()
    }

    /// Closes it as the user does - a click beside it, Escape.
    func closeAsTheUser() {
        unseen == nil ? popover.performClose(nil) : close()
    }

    func popoverDidClose(_ notification: Notification) {
        onClosed()
    }
}
#endif
