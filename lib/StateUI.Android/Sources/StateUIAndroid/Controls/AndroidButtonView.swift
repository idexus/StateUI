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

        listen(JavaAPI.setOnClickListener)
    }

    override func detach() {
        onClicked = nil
    }
}
