// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The runtime's one frame signal and its one timebase; a toolkit's display link drives it.
/// Design: docs/design/host/runtime.md#one-frame
@_spi(Host) @MainActor public protocol FrameClock: AnyObject {
    /// The runtime's time, in milliseconds on one monotonic clock.
    var now: () -> Double { get }

    /// Whether something holds the clock; frames come only while it does.
    var held: Bool { get set }
}
