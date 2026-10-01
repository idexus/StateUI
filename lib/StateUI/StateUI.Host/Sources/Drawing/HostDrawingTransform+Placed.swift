// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
#if canImport(Darwin)
import Darwin
#elseif canImport(Android)
import Android
#elseif canImport(Glibc)
import Glibc
#elseif canImport(CRT)
import CRT
#endif

extension HostDrawingTransform {
    /// This transform drawn under `placed`, the transform of the layout placing the view: its move turned and scaled
    /// by the layout's, the turns added and the scales multiplied, about the view's centre - itself where no layout
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
}
