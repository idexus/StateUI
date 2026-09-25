// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// What a view heard of the user's input, as its GTK controllers tell it.
/// Design: docs/design/platforms/gtk/input.md
enum GTKHeard: Equatable, Sendable {
    /// A tap: its place in a quick run of taps, from 1; 0 for a press assistive technology made.
    case tap(run: Int)

    /// The pointer over the view: the View tier's event, and where it is, in logical pixels of the view.
    case pointer(Event, Point)

    /// A press dragged: its phase - 0 began, 1 moved, 2 ended, 3 cancelled - and how far it has moved since it began.
    case drag(phase: Int32, x: Double, y: Double)

    /// A pinch: its phase, its scale since the last, and where, as shares of the view's size.
    case pinch(phase: Int32, scale: Double, at: Point)
}

/// What a view listens for of the user's input.
struct GTKHearing: OptionSet, Hashable, Sendable {
    let rawValue: UInt32

    static let taps = GTKHearing(rawValue: 1 << 0)
    static let pointer = GTKHearing(rawValue: 1 << 1)
    static let drags = GTKHearing(rawValue: 1 << 2)
    static let pinches = GTKHearing(rawValue: 1 << 3)

    /// Each kind of input on its own.
    static let kinds: [GTKHearing] = [.taps, .pointer, .drags, .pinches]
}
