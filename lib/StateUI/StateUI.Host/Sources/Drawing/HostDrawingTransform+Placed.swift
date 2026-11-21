// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
import StateUIFoundation

extension HostDrawingTransform {
    /// This transform drawn under `placed`, the transform of the layout placing the view: its move turned and scaled
    /// by the layout's, the turns added and the scales multiplied, about the view's center - itself where no layout
    /// places it with one.
    /// Design: docs/design/host/layout.md#a-placed-child
    public func under(_ placed: HostDrawingTransform?) -> HostDrawingTransform {
        guard let placed else { return self }
        var drawn = self
        let angle = placed.rotation * .pi / 180
        let (x, y) = (translationX * placed.scaleX, translationY * placed.scaleY)
        drawn.translationX = placed.translationX + x * cos(angle) - y * sin(angle)
        drawn.translationY = placed.translationY + x * sin(angle) + y * cos(angle)
        drawn.rotation += placed.rotation
        drawn.scaleX *= placed.scaleX
        drawn.scaleY *= placed.scaleY
        drawn.pivotX = 0.5
        drawn.pivotY = 0.5
        return drawn
    }

    /// The rectangle around `place` as this transform draws it: scaled and turned about its pivot, then moved. A
    /// tilt out of the page is left out: it draws inside what the flat view covers.
    /// Design: docs/design/host/runtime.md#two-rectangles
    public func bounds(of place: Rect) -> Rect {
        bounds(of: place, within: place)
    }

    /// The rectangle around `rect` as this transform draws it, the transform of a view standing at `frame`: scaled
    /// and turned about that view's pivot, then moved - where the view draws what it holds there.
    public func bounds(of rect: Rect, within frame: Rect) -> Rect {
        guard translationX != 0 || translationY != 0 || rotation != 0 || scaleX != 1 || scaleY != 1 else {
            return rect
        }
        let angle = rotation * .pi / 180
        let (pivotAcross, pivotDown) = (frame.x + frame.width * pivotX, frame.y + frame.height * pivotY)
        var (left, top, right, bottom) = (Double.infinity, Double.infinity, -Double.infinity, -Double.infinity)
        let (maxX, maxY) = (rect.x + rect.width, rect.y + rect.height)
        for corner in [(rect.x, rect.y), (maxX, rect.y), (rect.x, maxY), (maxX, maxY)] {
            let (across, down) = ((corner.0 - pivotAcross) * scaleX, (corner.1 - pivotDown) * scaleY)
            let x = across * cos(angle) - down * sin(angle) + pivotAcross + translationX
            let y = across * sin(angle) + down * cos(angle) + pivotDown + translationY
            (left, top, right, bottom) = (min(left, x), min(top, y), max(right, x), max(bottom, y))
        }
        return Rect(x: left, y: top, width: right - left, height: bottom - top)
    }
}
