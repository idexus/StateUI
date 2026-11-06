// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The inspector of a window's scene, opened, closed and moved from the window.
// Design: docs/design/views/inspector.md#what-it-shows

extension WindowSession {
    /// Whether the inspector of this window's scene shows, in whichever window.
    public var isDebugInspectorOpen: Bool {
        record.map(Inspector.showing(in:)) ?? false
    }

    /// Shows the inspector of this window's scene, docked in this window, or for `.window` in the scene's own
    /// inspector window where it has one, and records from now on.
    ///
    ///     @Environment(\.window) private var window
    ///
    ///     Button("Inspect").onClicked { window.openDebugInspector(.side) }
    ///
    /// - Parameter place: where it shows, whole - or, left out, along the bottom and folded to its last render,
    ///   which is what the ⓘ does.
    public func openDebugInspector(_ place: DebugInspector.Place? = nil) {
        guard let record else { return }

        Inspector.show(in: record, place ?? .bottom, folded: place == nil, window: key)
    }

    /// Hides the inspector of this window's scene, wherever it shows.
    public func closeDebugInspector() {
        guard let record else { return }

        Inspector.hide(in: record)
    }

    /// Shows the inspector of this window's scene docked in this window - moving it there from another window of
    /// the scene - and hides it where it shows here already.
    public func toggleDebugInspector() {
        guard let record else { return }

        if let docking = record.dockedInspector, docking.window != key {
            let folded = InspectorModel.shared.collapsed.contains(record.id)
            Inspector.show(in: record, docking.place, folded: folded, window: key)
        } else {
            Inspector.showing(in: record) ? Inspector.hide(in: record) : openDebugInspector()
        }
    }
}
