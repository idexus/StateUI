// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// A run of taps where the platform's own toolkit counts none: a tap carries the run on where it comes within
/// `interval` of the last and within `slop` points of it - the platform's own double tap - and starts one otherwise.
/// Design: docs/design/host/runtime.md#a-run-of-taps
@_spi(Host) public struct TapRun: Sendable {
    /// How long after the last a tap carries the run on.
    public let interval: Duration

    /// How far from the last a tap carries the run on, in points.
    public let slop: Double

    private var last: (time: Duration, point: Point, count: Int)?

    /// A run measured as the platform measures its double tap.
    public init(interval: Duration, slop: Double) {
        self.interval = interval
        self.slop = slop
    }

    /// A tap at `point`, in points, at `time` on the pointer's clock - the platform's own time of the event, from
    /// any start: its place in its run, from one.
    public mutating func tapped(at point: Point, time: Duration) -> Int {
        let count = last.map { last in
            let near = ((point.x - last.point.x) * (point.x - last.point.x)
                + (point.y - last.point.y) * (point.y - last.point.y)).squareRoot() <= slop
            return near && time - last.time <= interval ? last.count + 1 : 1
        } ?? 1
        last = (time, point, count)
        return count
    }
}
