// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// A Border: its one child within its padding, on a shape it fills, outlines, and cuts what it holds to.
/// Design: docs/design/platforms/android/drawing.md#a-border
@MainActor
final class AndroidBorderView: AndroidSingleChildView {
    private let drawing = AndroidShapeDrawable()

    override init() {
        super.init()
        Java.call(reference, JavaAPI.setBackground, .object(drawing.reference))
        Java.call(reference, JavaAPI.setClipToOutline, .bool(true))
    }

    /// What fills the shape: a colour or a brush; nil for nothing.
    override func setBackground(_ value: HostValue?) {
        drawing.setFill(value)
    }

    /// The outline and the shape, the width in points and one point where none is said.
    func apply(stroke: HostValue?, strokeWidth: Double?, shape: AndroidShapeDrawable.Shape) {
        drawing.setStroke(stroke, width: max(0, strokeWidth ?? 1) * density)
        drawing.setShape(shape, density: density)
        Java.call(reference, JavaAPI.invalidateOutline)
    }
}
