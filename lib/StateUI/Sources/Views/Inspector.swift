// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The inspector: what every render costs and builds, shown inside the
// application, one per scene; the record itself is Core/Inspection.swift's.
// Design: docs/design/views/inspector.md#what-it-shows

/// What each render costs and what it builds, shown inside the application.
///
///     @Environment private var scene: SceneSession
///     @Environment private var page: PageSession
///
///     VStack { … }
///         .onCreated { page.toolbarItems = [.inspector(scene)] }
///
/// Each render is listed as it happens - its cause, its road, the time Swift
/// took to describe it and the host to apply it, and how many composed views
/// it built and carried - and a chosen render shows its tree of composed
/// views with each one's time.
///
/// Each scene has its own. It opens along the bottom of the scene's main
/// window folded to one line, the last render; opened out, it docks at the
/// side on a desktop or a tablet, or shows in the scene's own window where the
/// scene declares one:
///
///     WindowGroup(.debugInspector) { DebugInspector() }
///
/// Nothing is recorded while every inspector is closed or paused.
public enum Inspector {
    /// Where an inspector shows.
    public enum Place: Sendable, Equatable {
        /// Along the bottom of its scene's main window, the page going on above
        /// it - where the ⓘ opens it, folded to one line.
        case bottom

        /// Down the trailing side of the main window, under the bar.
        case side

        /// In the scene's `DebugInspector` window - where the scene declares
        /// one and the platform opens windows, and docked everywhere else.
        case window
    }

    /// Whether a scene's inspector shows.
    ///
    /// - Parameter scene: the scene - the session a view in it holds.
    public static func isOpen(in scene: SceneSession) -> Bool {
        scene.record.map(showing(in:)) ?? false
    }

    /// Shows a scene's inspector, and records from now on.
    ///
    ///     @Environment private var scene: SceneSession
    ///
    ///     Button("Inspect").onClicked { Inspector.open(.side, in: scene) }
    ///
    /// - Parameters:
    ///   - place: where it shows, whole - or, left out, along the bottom and
    ///     folded to its last render, which is what the ⓘ does.
    ///   - scene: the scene - the session a view in it holds.
    public static func open(_ place: Place? = nil, in scene: SceneSession) {
        guard let record = scene.record else { return }

        show(in: record, place ?? .bottom, folded: place == nil)
    }

    /// Hides a scene's inspector.
    ///
    /// - Parameter scene: the scene - the session a view in it holds.
    public static func close(in scene: SceneSession) {
        guard let record = scene.record else { return }

        hide(in: record)
    }

    /// Hides a scene's inspector where it shows, and shows it otherwise.
    ///
    /// - Parameter scene: the scene - the session a view in it holds.
    public static func toggle(in scene: SceneSession) {
        isOpen(in: scene) ? close(in: scene) : open(in: scene)
    }

    /// How often, at most, an inspector is built again while renders land, in
    /// milliseconds.
    static var pace: Int { 150 }

    /// Whether it may dock down the side: a third of a desktop's or a tablet's
    /// window, where it would be all of a phone's.
    static var offersSide: Bool {
        let formFactor = StandardEnvironment.device.formFactor
        return formFactor == .desktop || formFactor == .tablet
    }

    /// Whether a scene's inspector may show in a window of its own: the scene
    /// declares one, and the platform opens windows.
    static func windowed(_ record: SceneRecord) -> Bool {
        record.declared[.debugInspector] != nil && Scenes.opensWindows
    }

    /// Whether a scene's inspector shows, docked or in its window.
    static func showing(in record: SceneRecord) -> Bool {
        InspectorModel.shared.places[record.id] != nil
            || record.windows.contains { $0.type == .debugInspector }
    }

    /// Shows a scene's inspector at a place - docked where it cannot show in a
    /// window - and records from now on; `folded` folds a bottom panel to its
    /// last render.
    static func show(in record: SceneRecord, _ place: Place, folded: Bool = false) {
        let model = InspectorModel.shared

        if place == .window, windowed(record) {
            model.places[record.id] = nil
            try? record.open(.debugInspector)
        } else {
            if windowed(record) {
                try? record.close(.debugInspector)
            }

            model.places[record.id] = place == .window ? (offersSide ? .side : .bottom) : place
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
            try? record.close(.debugInspector)
        }

        model.places[record.id] = nil
        model.expand(record.id)
        model.settle()
    }

    /// Forgets the inspector of a scene that has ended: docked, it went with
    /// the scene's main window, and the record stops once no inspector shows.
    static func ended(_ record: SceneRecord) {
        let model = InspectorModel.shared

        guard model.places[record.id] != nil else { return }

        model.places[record.id] = nil
        model.expand(record.id)
        model.settle()
    }

    /// The panel over a scene's main window, if its inspector docks there -
    /// asked inside the window's build, so the window builds again when it moves.
    static func panel(in record: SceneRecord) -> Node? {
        guard let place = InspectorModel.shared.places[record.id] else { return nil }

        return .overlay(InspectorPanel(scene: record.id, place: place))
    }
}
