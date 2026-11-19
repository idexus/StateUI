// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// Where every view of a motion layout goes: one placement a view, in the views' order. It lands as written.
/// Design: docs/design/types/placement.md#a-run-lands-as-written
struct PlacedRun: Equatable, Sendable {
    var placements: [Placement]

    /// A run of `placements`, each `zIndex` replaced by its rank in the run.
    /// Design: docs/design/types/placement.md#drawing-order-as-ranks
    init(_ placements: [Placement] = []) {
        let order = Placement.drawingOrder(of: placements)

        self.placements = placements.indices.map { index in
            var placement = placements[index]
            placement.zIndex = order[index]
            return placement
        }
    }
}
