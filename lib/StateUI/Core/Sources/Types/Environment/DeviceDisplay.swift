// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The screen the interface is on, as the host last reported it. Read it as
/// the device's `display`, `@Environment(\.device)`. Rotating a phone updates
/// `orientation`, `rotation`, `width` and `height` in one host update. A number
/// the host has not said is nil.
@MainActor
public final class DeviceDisplay {
    /// The screen's width in PIXELS - divide by `density` for the points a
    /// layout speaks.
    public internal(set) var width: Double? {
        get { _width }
        set { _width = newValue }
    }

    @State private var _width: Double?

    /// The screen's height in pixels.
    public internal(set) var height: Double? {
        get { _height }
        set { _height = newValue }
    }

    @State private var _height: Double?

    /// Pixels per layout point - 3 on a modern phone, 2 on a Mac.
    public internal(set) var density: Double? {
        get { _density }
        set { _density = newValue }
    }

    @State private var _density: Double?

    /// Portrait or landscape.
    public internal(set) var orientation: DisplayOrientation {
        get { _orientation }
        set { _orientation = newValue }
    }

    @State private var _orientation: DisplayOrientation = .unknown

    /// How far the screen is rotated from its natural position.
    public internal(set) var rotation: DisplayRotation {
        get { _rotation }
        set { _rotation = newValue }
    }

    @State private var _rotation: DisplayRotation = .unknown

    /// Frames per second the display draws; nil where the platform does not
    /// say.
    public internal(set) var refreshRate: Double? {
        get { _refreshRate }
        set { _refreshRate = newValue }
    }

    @State private var _refreshRate: Double?

    /// A display as a test or a preview fakes it; what is not said starts as a headless host's does.
    public init(
        width: Double? = nil, height: Double? = nil, density: Double? = nil,
        orientation: DisplayOrientation = .unknown, rotation: DisplayRotation = .unknown, refreshRate: Double? = nil
    ) {
        self.width = width
        self.height = height
        self.density = density
        self.orientation = orientation
        self.rotation = rotation
        self.refreshRate = refreshRate
    }
}
