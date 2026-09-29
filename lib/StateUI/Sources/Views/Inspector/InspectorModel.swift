// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// Everything the inspectors hold, in one place, so a render caused only by
/// these states is known as an inspector drawing itself and is not kept.
/// Design: docs/design/views/inspector.md#its-own-cost
final class InspectorModel: @unchecked Sendable {
    /// The one there is.
    static let shared = InspectorModel()

    /// Where each scene's inspector docks, by the scene's number - nothing
    /// for a scene whose inspector is not docked.
    @State var places: [String: Inspector.Place] = [:]

    /// The scenes whose inspector, docked along the bottom, is folded to its
    /// last render.
    @State var collapsed: Set<String> = []

    /// Whether recording is held while they show.
    @State var paused = false

    /// Moves whenever there is something new to show - which is what the views
    /// that show it read.
    @State var revision = 0

    /// The render chosen, by its number.
    @State var selected: Int? = nil

    /// How many inspector windows the platform has up - counted by the
    /// inspector's page, as the tree creates and destroys it.
    var windows = 0

    /// Whether a rebuild is already asked for.
    private var asking = false

    private init() {}

    /// Whether any inspector shows, docked or in a window.
    var showing: Bool { !places.isEmpty || windows > 0 }

    /// Holds recording, or takes it up again.
    func pause() {
        paused.toggle()
        Inspection.recording = !paused && showing
    }

    /// Forgets every render.
    func clear() {
        selected = nil
        Inspection.clear()
    }

    /// Opens a scene's inspector out again where it is folded, and writes
    /// nothing where it is not.
    func expand(_ scene: String) {
        if collapsed.contains(scene) {
            collapsed.remove(scene)
        }
    }

    /// Folds a scene's inspector to its last render, and writes nothing where
    /// it already is.
    func fold(_ scene: String) {
        if !collapsed.contains(scene) {
            collapsed.insert(scene)
        }
    }

    /// Records from now on, telling the record what is the inspectors' own -
    /// and starting it afresh where nothing was recording.
    func record() {
        Inspection.ownViews = [
            String(reflecting: InspectorPanel.self),
            String(reflecting: InspectorPage.self),
        ]
        Inspection.ownStates = Set([
            $places.described.map { ObjectIdentifier($0) },
            $collapsed.described.map { ObjectIdentifier($0) },
            $paused.described.map { ObjectIdentifier($0) },
            $revision.described.map { ObjectIdentifier($0) },
            $selected.described.map { ObjectIdentifier($0) },
        ].compactMap { $0 })
        Inspection.landed = { [unowned self] in self.landed() }

        if !Inspection.recording && !paused {
            Inspection.start()
        }
    }

    /// Stops recording once no inspector shows any more.
    func settle() {
        guard !showing else { return }

        selected = nil
        Inspection.stop()
    }

    /// A pass landed, or the host reported on one: asks for the views to be
    /// built again, once for however many arrive in the pace.
    private func landed() {
        guard !asking else { return }

        asking = true

        Task { @MainActor [self] in
            try? await Task.sleep(for: .milliseconds(Inspector.pace))
            asking = false
            revision &+= 1
        }
    }
}
