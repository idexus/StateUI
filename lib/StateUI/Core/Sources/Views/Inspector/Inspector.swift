// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The inspector: what every render costs and builds, shown inside the
// application, one per scene; the record itself is Inspection.swift's.
// Design: docs/design/views/inspector.md#what-it-shows

/// The rules the inspector keeps: how often it is built again, where it may dock, where it stands.
@MainActor
enum Inspector {
    typealias Place = DebugInspector.Place

    /// How often, at most, an inspector is built again while renders land, in
    /// milliseconds.
    static var pace: Int { 150 }

    /// Whether it may dock down the side: a third of a desktop's or a tablet's
    /// window, where it would be all of a phone's.
    static var offersSide: Bool {
        let formFactor = StandardEnvironment.device.info.formFactor
        return formFactor == .desktop || formFactor == .tablet
    }

    /// Whether a scene's inspector may show in a window of its own: the scene
    /// declares one, and the platform opens windows.
    static func windowed(_ record: SceneRecord) -> Bool {
        OpenScenes.shared.declares(WindowKind.debugInspector.key, in: record) && OpenScenes.opensWindows
    }

    /// Where a scene's inspector is docked: its place, in the window keyed `window`.
    struct Docking: Equatable {
        let place: Place
        let window: String
    }

    /// Where `record`'s inspector stands in its window keyed `key`: docked there - or in the scene's first window,
    /// where the one it docked in has closed; nil where it does not stand in that window.
    /// Design: docs/design/views/inspector.md#where-it-docks
    static func docked(in record: SceneRecord, window key: String) -> Place? {
        guard let docking = record.dockedInspector else { return nil }

        let open = record.windows.map(\.key)
        let standing = open.contains(docking.window) ? docking.window : open.first
        return standing == key ? docking.place : nil
    }

    /// Whether a scene's inspector shows, docked or in its window.
    static func showing(in record: SceneRecord) -> Bool {
        InspectorModel.shared.places[record.id] != nil
            || record.windows.contains { $0.type == WindowKind.debugInspector.key }
    }

    /// Shows a scene's inspector at a place - docked where it cannot show in a
    /// window, in the window keyed `window`, else where it docks now - and
    /// records from now on; `folded` folds a bottom panel to its last render.
    static func show(in record: SceneRecord, _ place: Place, folded: Bool = false, window: String? = nil) {
        let model = InspectorModel.shared

        if place == .window, windowed(record) {
            dock(nil, in: record)
            try? OpenScenes.shared.open(WindowKind.debugInspector.key)
        } else {
            if windowed(record) {
                try? record.close(WindowKind.debugInspector.key, value: nil)
            }

            dock(place == .window ? (offersSide ? .side : .bottom) : place, in: record, window: window)
        }

        if folded, model.places[record.id] == .bottom {
            model.fold(record.id)
        } else {
            model.expand(record.id)
        }

        model.record()
    }

    /// Hides a scene's inspector, wherever it shows.
    static func hide(in record: SceneRecord) {
        let model = InspectorModel.shared

        if windowed(record) {
            try? record.close(WindowKind.debugInspector.key, value: nil)
        }

        dock(nil, in: record)
        model.expand(record.id)
        model.settle()
    }

    /// Forgets the inspector of a scene that has ended: docked, it went with
    /// the scene's windows, and the record stops once no inspector shows.
    static func ended(_ record: SceneRecord) {
        let model = InspectorModel.shared

        guard model.places[record.id] != nil else { return }

        dock(nil, in: record)
        model.expand(record.id)
        model.settle()
    }

    /// Docks a scene's inspector at `place` in the window keyed `window` - else where it docks now, else the scene's
    /// first window - or nowhere: a value of the scene, whose panel the library lays over every overlay that
    /// window's page declares.
    /// Design: docs/design/views/inspector.md#where-it-docks
    private static func dock(_ place: Place?, in record: SceneRecord, window: String? = nil) {
        let key = window ?? record.dockedInspector?.window ?? record.windows.first?.key
        InspectorModel.shared.places[record.id] = place
        record.dockedInspector = place.flatMap { place in key.map { Docking(place: place, window: $0) } }
    }
}
