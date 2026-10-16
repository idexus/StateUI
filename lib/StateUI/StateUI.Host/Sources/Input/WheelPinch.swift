// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// A pinch a platform tells as a wheel turned with Control - a trackpad's pinch, to an application that hears no
/// gesture of it, on Windows and in a browser; a mouse's wheel with Control, which zooms on the desktops - read alike
/// on every host: begun with its first turn, each turn a step of its scale, and let go once the wheel has stood still
/// `HandReading.pause`, as a wheel tells no lift.
/// Design: docs/design/host/runtime.md#a-wheel-turned-as-a-pinch
@_spi(Host) public struct WheelPinch: Sendable {
    /// How much a notch of a wheel turned with Control scales: a tenth, away from the user larger.
    public static let notch = 1.1

    /// When the wheel last turned, while its pinch is under way, and where.
    private var last: Double?
    private var at = Point(x: 0.5, y: 0.5)

    /// No pinch under way.
    public init() {}

    /// Whether a pinch is under way.
    public var isOpen: Bool { last != nil }

    /// The wheel turned at `now`, scaling by `scale` at `point`, as shares of the view: the pinch's step - its
    /// beginning first, where none is under way.
    public mutating func turned(_ scale: Double, at point: Point, now: Double) -> [HeardInput] {
        let begins = last == nil
        last = now
        at = point
        return (begins ? [.pinch(.began, scale: 1, at: point)] : []) + [.pinch(.changed, scale: scale, at: point)]
    }

    /// A frame at `now`: the pinch let go where the wheel has stood still long enough.
    public mutating func paced(now: Double) -> [HeardInput] {
        guard let last, now - last >= HandReading.pause else { return [] }

        self.last = nil
        return [.pinch(.ended, scale: 1, at: at)]
    }
}
