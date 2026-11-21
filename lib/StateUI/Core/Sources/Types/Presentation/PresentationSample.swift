// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// Design: docs/design/core/acts.md#where-a-view-stands-asked

/// How a view stands on the page at one moment: where its layout puts it, the rectangle around what is drawn of
/// it, and how it is drawn - a movement's place on its way, not where it is going.
///
///     let panel = try await sidePanel.presentationSample()
///     let isOpen = panel.translation.x > -40
public struct PresentationSample: Equatable, Sendable {
    /// Where the view's layout puts it, in what holds it.
    public let layoutFrame: Rect

    /// The rectangle around what is drawn of the view, in what holds it: its own move, turn and scale in it.
    public let frame: Rect

    /// How far the view is drawn from where its layout put it.
    public let translation: Point

    /// How the view is scaled across, `scale` and `scaleX` together.
    public let scaleX: Double

    /// How the view is scaled down, `scale` and `scaleY` together.
    public let scaleY: Double

    /// How far the view is turned, in degrees clockwise.
    public let rotation: Double

    /// How opaque the view is drawn, 0 to 1.
    public let opacity: Double

    /// A sample of a view standing so.
    @_spi(Host) public init(
        layoutFrame: Rect, frame: Rect, translation: Point, scaleX: Double, scaleY: Double, rotation: Double,
        opacity: Double
    ) {
        self.layoutFrame = layoutFrame
        self.frame = frame
        self.translation = translation
        self.scaleX = scaleX
        self.scaleY = scaleY
        self.rotation = rotation
        self.opacity = opacity
    }
}

extension PresentationSample: HostRepresentable {
    /// The two rectangles' four numbers each, the move's two, the two scales, the turn and the opacity.
    public var propValue: PropValue {
        .numbers([
            layoutFrame.x, layoutFrame.y, layoutFrame.width, layoutFrame.height,
            frame.x, frame.y, frame.width, frame.height,
            translation.x, translation.y, scaleX, scaleY, rotation, opacity,
        ])
    }

    /// The sample back from its fourteen numbers; nil for anything else.
    /// - Parameter propValue: what crossed.
    public init?(propValue: PropValue) {
        guard case .numbers(let numbers) = propValue, numbers.count == 14, numbers.allSatisfy(\.isFinite)
        else { return nil }

        self.init(
            layoutFrame: Rect(x: numbers[0], y: numbers[1], width: numbers[2], height: numbers[3]),
            frame: Rect(x: numbers[4], y: numbers[5], width: numbers[6], height: numbers[7]),
            translation: Point(x: numbers[8], y: numbers[9]), scaleX: numbers[10], scaleY: numbers[11],
            rotation: numbers[12], opacity: numbers[13])
    }
}
