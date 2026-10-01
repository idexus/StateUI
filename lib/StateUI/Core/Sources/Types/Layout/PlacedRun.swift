// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// Where every view of a run goes, and how this answer animates there.
///
///     @State private var run = PlacedRun()
///
///     PlacedLayout(cards, id: \.name) { face($0) }.placement($run)
///
/// What an engine writes once it has worked out a layout: one placement per
/// view, in the order the views stand in, and the motion of this write. Write
/// at once (`.none`, the default) while a finger moves the run, and animate
/// when the layout changes shape; a write during an animation bends it rather
/// than restarting it.
///
/// Design: docs/design/types/placement.md#a-motion-per-write
public struct PlacedRun: StateValue {
    /// Where each view goes, in the order they stand in the layout.
    public var placements: [Placement]

    /// How this answer animates: `.none` places the views at once,
    /// `.inherited` uses the layout's own `.motion`, and any other motion is
    /// used as written.
    public var motion: Motion

    /// A run of placements. Each `zIndex` is replaced by its rank in the run,
    /// so a z-index worked out from a moving value costs a write only when two
    /// views swap.
    ///
    /// - Parameters:
    ///   - placements: where each view goes, in the order they stand in.
    ///   - motion: how this answer animates there. At once, unless said.
    public init(_ placements: [Placement] = [], motion: Motion = .none) {
        let order = Placement.drawingOrder(of: placements)

        self.placements = placements.indices.map { index in
            var placement = placements[index]
            placement.zIndex = order[index]
            return placement
        }

        self.motion = motion
    }

    /// Every placement taken as it is: a run read back holds ranks already.
    init(exactly placements: [Placement], motion: Motion) {
        self.placements = placements
        self.motion = motion
    }

    /// Every view's twelve numbers, then the motion's three, so a view's
    /// numbers start at `12 × index`.
    ///
    /// Design: docs/design/types/placement.md#twelve-numbers-a-view
    public var carried: StateCarried {
        var lanes: [Double] = []
        lanes.reserveCapacity(placements.count * Placement.lanes + StateLaw.lanes)

        for placement in placements {
            guard case .lanes(let each) = placement.carried else { continue }

            lanes += each
        }

        return .lanes(lanes + StateLaw.lanes(of: motion))
    }

    /// A run back, for as many views as the numbers hold.
    public init?(carried: StateCarried) {
        guard case .lanes(let lanes) = carried else { return nil }

        // No lanes at all is an empty run: a state never written.
        guard !lanes.isEmpty else {
            self.init()
            return
        }

        let width = Placement.lanes

        guard lanes.count >= StateLaw.lanes,
              (lanes.count - StateLaw.lanes) % width == 0
        else { return nil }

        var run: [Placement] = []
        run.reserveCapacity((lanes.count - StateLaw.lanes) / width)

        for start in stride(from: 0, to: lanes.count - StateLaw.lanes, by: width) {
            guard let placement = Placement(carried: .lanes(Array(lanes[start..<(start + width)])))
            else { return nil }

            run.append(placement)
        }

        self.init(exactly: run, motion: StateLaw.motion(of: Array(lanes.suffix(StateLaw.lanes))))
    }

    /// Its own width: twelve lanes a view, and three for the motion.
    public static var lanes: Int { StateValueLanes.own }
}
