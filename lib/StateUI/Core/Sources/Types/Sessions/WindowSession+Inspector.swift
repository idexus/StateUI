// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The inspector of a window's scene, opened, closed and moved from the window.
// Design: docs/design/views/inspector.md#what-it-shows

extension WindowSession {
    /// Where the inspector of this window's scene shows - along the bottom or the side, or in the scene's own
    /// inspector window - nil while it shows nowhere. Writing a place shows it there, docked in this window where
    /// it docks, and records from now on; writing nil hides it, wherever it shows. It is the scene's place, which
    /// every window of the scene reads, so it lends no binding.
    ///
    ///     @Environment(\.window) private var window
    ///
    ///     Button("Inspect").onClicked { window.debugInspector = .side }
    ///
    /// Design: docs/design/views/inspector.md#where-it-docks
    public var debugInspector: DebugInspector.Place? {
        get { record.flatMap { InspectorModel.shared.places[$0.id] } }
        set {
            guard let record else { return }

            if let place = newValue { Inspector.show(in: record, place, window: key) } else { Inspector.hide(in: record) }
        }
    }

    /// What the ⓘ does: shows the inspector of this window's scene docked in this window, folded along the
    /// bottom - moving it here from another window of the scene - and hides it where it shows here already.
    func toggleDebugInspector() {
        guard let record else { return }

        if let docking = record.dockedInspector, docking.window != key {
            let folded = InspectorModel.shared.collapsed.contains(record.id)
            Inspector.show(in: record, docking.place, folded: folded, window: key)
        } else if Inspector.showing(in: record) {
            Inspector.hide(in: record)
        } else {
            Inspector.show(in: record, .bottom, folded: true, window: key)
        }
    }
}
