// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The inspector: what every render costs and builds, shown inside the
// application, one per scene; the record itself is Inspection.swift's.
// Design: docs/design/views/inspector.md#what-it-shows

/// What each render costs and what it builds, shown inside the application.
///
///     @Environment(\.window) private var window
///
///     VStack { … }
///         .toolbar { ToolbarItem.inspector(window) }
///
/// Each render is listed as it happens - its cause, its road, the time Swift
/// took to describe it and the host to apply it, and how many composed views
/// it built and carried - and a chosen render shows its tree of composed
/// views with each one's time.
///
/// Each scene has its own. It opens along the bottom of the window its ⓘ is
/// in, folded to one line, the last render - the ⓘ of another window of the
/// scene moves it there; opened out, it can dock at the side on a desktop or a
/// tablet, or show in the scene's own window where the scene declares one:
///
///     Window(.debugInspector) { DebugInspector() }
///
/// Nothing is recorded while every inspector is closed or paused.
public enum Inspector {
    /// Where an inspector shows.
    public enum Place: Sendable, Equatable {
        /// Along the bottom of the window it docks in, the page going on above
        /// it - where the ⓘ opens it, folded to one line.
        case bottom

        /// Down the trailing side of the window it docks in, under the bar.
        case side

        /// In the scene's `DebugInspector` window - where the scene declares
        /// one and the platform opens windows, and docked everywhere else.
        case window
    }

    /// Whether the inspector of a window's scene shows, in whichever window.
    ///
    /// - Parameter window: the window - the session a view in it holds.
    public static func isOpen(in window: WindowSession) -> Bool {
        window.record.map(showing(in:)) ?? false
    }

    /// Shows the inspector of a window's scene, docked in that window, and
    /// records from now on.
    ///
    ///     @Environment(\.window) private var window
    ///
    ///     Button("Inspect").onClicked { Inspector.open(.side, in: window) }
    ///
    /// - Parameters:
    ///   - place: where it shows, whole - or, left out, along the bottom and
    ///     folded to its last render, which is what the ⓘ does.
    ///   - window: the window it docks in - the session a view in it holds.
    public static func open(_ place: Place? = nil, in window: WindowSession) {
        guard let record = window.record else { return }

        show(in: record, place ?? .bottom, folded: place == nil, window: window.key)
    }

    /// Hides the inspector of a window's scene, wherever it shows.
    ///
    /// - Parameter window: the window - the session a view in it holds.
    public static func close(in window: WindowSession) {
        guard let record = window.record else { return }

        hide(in: record)
    }

    /// Shows the inspector of a window's scene docked in that window - moving it
    /// there from another window of the scene - and hides it where it shows
    /// there already.
    ///
    /// - Parameter window: the window - the session a view in it holds.
    public static func toggle(in window: WindowSession) {
        guard let record = window.record else { return }

        if let docking = record.dockedInspector, docking.window != window.key {
            let folded = InspectorModel.shared.collapsed.contains(record.id)
            show(in: record, docking.place, folded: folded, window: window.key)
        } else {
            showing(in: record) ? hide(in: record) : open(in: window)
        }
    }

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
        OpenScenes.shared.declares(.debugInspector, in: record) && OpenScenes.opensWindows
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
            || record.windows.contains { $0.type == .debugInspector }
    }

    /// Shows a scene's inspector at a place - docked where it cannot show in a
    /// window, in the window keyed `window`, else where it docks now - and
    /// records from now on; `folded` folds a bottom panel to its last render.
    static func show(in record: SceneRecord, _ place: Place, folded: Bool = false, window: String? = nil) {
        let model = InspectorModel.shared

        if place == .window, windowed(record) {
            dock(nil, in: record)
            try? OpenScenes.shared.open(.debugInspector)
        } else {
            if windowed(record) {
                try? record.close(.debugInspector, value: nil)
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
            try? record.close(.debugInspector, value: nil)
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
