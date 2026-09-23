// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
import CStateUIAndroid

/// A ColorBox: a plain `android.view.View`, its colour a rounded shape drawn over its background.
@MainActor
final class AndroidColorBoxView: AndroidView {
    private let drawing = AndroidShapeDrawable()

    init() {
        super.init { _ in Java.new(JavaAPI.view, JavaAPI.newView, .object(AndroidRenderer.context)) }
        Java.call(reference, JavaAPI.setForeground, .object(drawing.reference))
    }

    /// The box's colour, and the radii of its corners; nil draws no colour.
    func apply(color: HostValue?, corners: AndroidShapeDrawable.Shape) {
        drawing.setFill(color)
        drawing.setShape(corners, density: density)
    }

    /// A box has nothing to show but its colour: it takes the room its layout gives it, and asks for none.
    override func measure(width: Int32, height: Int32) -> (width: Int32, height: Int32) {
        func exact(_ spec: Int32) -> Int32 {
            ViewConstants.mode(spec) == ViewConstants.exactly ? spec : ViewConstants.unspecified
        }
        return super.measure(width: exact(width), height: exact(height))
    }
}
