// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The screen the interface is on, as the host last reported it. Read it as
/// the device's `display`, `@Environment(\.device)`. Rotating a phone updates
/// `orientation`, `rotation`, `width` and `height` in one host update.
@MainActor
public final class DeviceDisplay {
    /// The screen's width in PIXELS - divide by `density` for the points a
    /// layout speaks.
    @State public internal(set) var width: Double = 0

    /// The screen's height in pixels.
    @State public internal(set) var height: Double = 0

    /// Pixels per layout point - 3 on a modern phone, 2 on a Mac.
    @State public internal(set) var density: Double = 0

    /// Portrait or landscape.
    @State public internal(set) var orientation: DisplayOrientation = .unknown

    /// How far the screen is rotated from its natural position.
    @State public internal(set) var rotation: DisplayRotation = .unknown

    /// Frames per second the display draws, where the platform says - 0 where
    /// it does not.
    @State public internal(set) var refreshRate: Double = 0

    /// A display as a test or a preview fakes it; what is not said starts as a headless host's does.
    public init(
        width: Double = 0, height: Double = 0, density: Double = 0, orientation: DisplayOrientation = .unknown,
        rotation: DisplayRotation = .unknown, refreshRate: Double = 0
    ) {
        self.width = width
        self.height = height
        self.density = density
        self.orientation = orientation
        self.rotation = rotation
        self.refreshRate = refreshRate
    }
}
