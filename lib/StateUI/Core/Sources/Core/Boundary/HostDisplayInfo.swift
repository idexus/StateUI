// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// Main-display facts supplied by a native host.
@_spi(Host) public struct HostDisplayInfo: Equatable, Sendable {
    /// Display width in physical pixels.
    public let width: Double

    /// Display height in physical pixels.
    public let height: Double

    /// Physical pixels per layout point.
    public let density: Double

    /// The coarse display orientation.
    public let orientation: DisplayOrientation

    /// Rotation from the display's natural orientation.
    public let rotation: DisplayRotation

    /// Frames per second, or zero when the platform does not expose it.
    public let refreshRate: Double

    /// A complete main-display report.
    public init(
        width: Double,
        height: Double,
        density: Double,
        orientation: DisplayOrientation,
        rotation: DisplayRotation,
        refreshRate: Double
    ) {
        self.width = width
        self.height = height
        self.density = density
        self.orientation = orientation
        self.rotation = rotation
        self.refreshRate = refreshRate
    }
}
