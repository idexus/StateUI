// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What a host tells the inspector of its own work, and what it reads of it.
/// Design: docs/design/host/patches.md#what-a-message-costs
@_spi(Host) extension HostBoundary {
    /// Whether an inspector records.
    public static var inspecting: Bool { Inspection.recording }

    /// Every pass reported on since the last take, as text; the first take starts the recording for good.
    public static func takeInspectionLog() -> String { Inspection.takeLog() }

    /// Tells the inspector what applying the message of `generation` cost: each scene's part by its key, in
    /// microseconds, then the whole - its time, the nodes it walked and the controls it had to build.
    @MainActor
    public static func inspected(generation: Int32, scenes: [String: Double], apply: Double, nodes: Int, made: Int) {
        for (name, micros) in scenes.sorted(by: { $0.key < $1.key }) {
            guard let index = Scenes.shared.index(of: name) else { continue }
            Inspection.applied(generation: generation, scene: index, micros: micros)
        }
        Inspection.applied(
            generation: generation, InspectedHost(apply: apply, nodes: nodes, made: made, kept: nodes - made))
    }
}
