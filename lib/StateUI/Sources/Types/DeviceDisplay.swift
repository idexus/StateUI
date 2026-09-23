// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The screen the interface is on, as the host last reported it. Resolve it
/// with `@Environment var display: DeviceDisplay`. Rotating a phone updates
/// `orientation`, `rotation`, `width` and `height` in one host update.
public final class DeviceDisplay {
    /// The screen's width in PIXELS - divide by `density` for the points a
    /// layout speaks.
    @State public var width: Double = 0

    /// The screen's height in pixels.
    @State public var height: Double = 0

    /// Pixels per layout point - 3 on a modern phone, 2 on a Mac.
    @State public var density: Double = 0

    /// Portrait or landscape.
    @State public var orientation: DisplayOrientation = .unknown

    /// How far the screen is rotated from its natural position.
    @State public var rotation: DisplayRotation = .unknown

    /// Frames per second the display draws, where the platform says - 0 where
    /// it does not.
    @State public var refreshRate: Double = 0

    /// A fresh instance, for providing a fake to one branch with
    /// `.environment(...)`. The values start as a headless host's do.
    public init() {}
}
