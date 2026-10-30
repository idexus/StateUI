// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The poses a layout's arithmetic answered at keyframes, each asked once and kept while what it was worked out with
/// stands: one description of the layout, its room, where its motion set out, the states it follows and the axes
/// that have no keyframes.
/// Design: docs/design/views/motion-layout.md#keyframes
@MainActor
final class LayoutPoses {
    /// What every kept pose was worked out with.
    struct Ground: Equatable {
        var room: Rect
        var from: [Double]
        var followed: [Int]
        var live: [Double]
    }

    private var ground: Ground?
    private var kept: [[Double]: [Placement]] = [:]

    /// Stands the poses on `ground`: those kept on another are let go.
    func stand(on ground: Ground) {
        guard ground != self.ground else { return }

        self.ground = ground
        kept = [:]
    }

    /// The pose kept at the parameters whose axes stand at `lanes`, or the one `work` answers, kept.
    func pose(at lanes: [Double], _ work: () -> [Placement]) -> [Placement] {
        if let pose = kept[lanes] { return pose }

        let pose = work()
        kept[lanes] = pose
        return pose
    }
}
