// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// A platform's gesture as a host tells it on: under way from the beginning told to the end told; once the host
/// takes it away, none of it told until the platform's gesture ends or the next begins - though what took it away
/// is gone before its end.
/// Design: docs/design/host/runtime.md#a-gesture-taken-away
@_spi(Host) public struct ToldGesture: Sendable {
    /// Whether a gesture is told under way: begun and not yet ended.
    public private(set) var isUnderWay = false

    /// Whether the platform's gesture under way was taken away.
    private var isTakenAway = false

    /// Nothing told yet.
    public init() {}

    /// Whether the platform's gesture at `phase` is told on: a beginning is, and nothing of a gesture taken away -
    /// its end lets the next be told, with a beginning or with none.
    public mutating func tells(_ phase: GesturePhase) -> Bool {
        if phase == .began { isTakenAway = false }
        guard isTakenAway else { return true }
        if phase != .changed { isTakenAway = false }
        return false
    }

    /// The gesture told at `phase`: one told begun is the next, whatever was taken away before.
    public mutating func told(_ phase: GesturePhase) {
        isUnderWay = phase == .began || phase == .changed
        if phase == .began { isTakenAway = false }
    }

    /// The host takes the platform's gesture away at `phase`: whether a gesture was told under way, whose end the
    /// host tells then, as cancelled.
    public mutating func takeAway(at phase: GesturePhase) -> Bool {
        isTakenAway = phase == .began || phase == .changed
        return isUnderWay
    }
}
