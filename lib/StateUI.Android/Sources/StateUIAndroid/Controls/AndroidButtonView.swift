// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
import CStateUIAndroid

/// A Button: an `android.widget.Button` whose click reaches Swift through its `StateUIListener`.
@MainActor
final class AndroidButtonView: AndroidTextView {
    /// What the button does when it is clicked.
    var onClicked: (() -> Void)?

    init() {
        super.init { _ in Java.new(JavaAPI.button, JavaAPI.newButton, .object(AndroidRenderer.context)) }
        Java.call(reference, JavaAPI.setAllCaps, .bool(false))
        setLeastSize(width: 0, height: 0)

        listen(JavaAPI.setOnClickListener)
    }

    /// The least pixels the button takes, in place of its theme's: a button is its words and its padding.
    /// Design: docs/design/platforms/android/controls.md#a-buttons-size
    func setLeastSize(width: Int32, height: Int32) {
        Java.call(reference, JavaAPI.setMinWidth, .int(width))
        Java.call(reference, JavaAPI.setMinimumWidth, .int(width))
        Java.call(reference, JavaAPI.setMinHeight, .int(height))
        Java.call(reference, JavaAPI.setMinimumHeight, .int(height))
    }

    /// A click is the button's own event, and a tap as any view's.
    override func clicked() {
        onClicked?()
        super.clicked()
    }

    override func detach() {
        super.detach()
        onClicked = nil
    }
}
