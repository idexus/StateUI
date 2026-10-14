// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// Where every view of a layout engine goes: one placement per view, in the
/// order the views stand in, as an engine writes it on the host's frames.
///
/// It lands as written: what travels is the phase the placements are worked
/// out from, never the placements themselves.
///
/// Design: docs/design/types/placement.md#a-run-lands-as-written
@_spi(Host) public struct PlacedRun: LaneValue {
    /// Where each view goes, in the order they stand in the layout.
    public var placements: [Placement]

    /// A run of placements. Each `zIndex` is replaced by its rank in the run,
    /// so a z-index worked out from a moving value costs a write only when two
    /// views swap.
    ///
    /// - Parameter placements: where each view goes, in the order they stand in.
    public init(_ placements: [Placement] = []) {
        let order = Placement.drawingOrder(of: placements)

        self.placements = placements.indices.map { index in
            var placement = placements[index]
            placement.zIndex = order[index]
            return placement
        }
    }

    /// Every placement taken as it is: a run read back holds ranks already.
    init(exactly placements: [Placement]) {
        self.placements = placements
    }

    /// Every view's twelve numbers, so a view's numbers start at `12 × index`.
    ///
    /// Design: docs/design/types/placement.md#twelve-numbers-a-view
    public var carried: StateCarried {
        var lanes: [Double] = []
        lanes.reserveCapacity(placements.count * Placement.lanes)

        for placement in placements {
            guard case .lanes(let each) = placement.carried else { continue }

            lanes += each
        }

        return .lanes(lanes)
    }

    /// A run back, for as many views as the numbers hold.
    public init?(carried: StateCarried) {
        guard case .lanes(let lanes) = carried, lanes.count % Placement.lanes == 0 else { return nil }

        var run: [Placement] = []
        run.reserveCapacity(lanes.count / Placement.lanes)

        for start in stride(from: 0, to: lanes.count, by: Placement.lanes) {
            guard let placement = Placement(carried: .lanes(Array(lanes[start..<(start + Placement.lanes)])))
            else { return nil }

            run.append(placement)
        }

        self.init(exactly: run)
    }

    /// Its own width: twelve lanes a view.
    public static var lanes: Int { StateValueLanes.own }
}
