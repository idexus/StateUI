// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A view's drag between views, as AppKit's own dragging session: once a press has moved past AppKit's distance, a
/// session carrying the view's words as a string, its picture the view as it shows - its source told as it starts
/// and as it ends, wherever it ended.
/// Design: docs/design/platforms/appkit/input.md#a-drag-between-views
@MainActor
final class AppKitDragSource: NSPanGestureRecognizer, NSDraggingSource {
    /// The words a drag of the view carries.
    var words = ""

    private let hearing: AppKitHearing

    init(hearing: @escaping AppKitHearing) {
        self.hearing = hearing
        super.init(target: nil, action: nil)
        target = self
        action = #selector(recognized)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("AppKitDragSource is created in code")
    }

    @objc private func recognized() {
        guard state == .began, let view, let event = NSApp.currentEvent else { return }
        let item = NSDraggingItem(pasteboardWriter: words as NSString)
        item.setDraggingFrame(view.bounds, contents: Self.picture(of: view))
        view.beginDraggingSession(with: [item], event: event, source: self)
        // The session follows the press from here.
        isEnabled = false
        isEnabled = true
    }

    private static func picture(of view: NSView) -> NSImage? {
        guard let drawn = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return nil }
        view.cacheDisplay(in: view.bounds, to: drawn)
        let picture = NSImage(size: view.bounds.size)
        picture.addRepresentation(drawn)
        return picture
    }

    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext)
        -> NSDragOperation {
        .copy
    }

    func draggingSession(_ session: NSDraggingSession, willBeginAt screenPoint: NSPoint) {
        started()
    }

    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        ended()
    }

    /// The drag of the view started.
    func started() {
        hearing(.dragStarted)
    }

    /// The drag of the view ended, wherever it ended.
    func ended() {
        hearing(.dragEnded)
    }
}
#endif
