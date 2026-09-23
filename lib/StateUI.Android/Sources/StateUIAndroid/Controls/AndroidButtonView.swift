// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
import CStateUIAndroid

/// A Button: an `android.widget.Button` whose click reaches Swift through a `StateUIClick`.
@MainActor
final class AndroidButtonView: AndroidTextView {
    /// What the button does when it is clicked.
    var onClicked: (() -> Void)?

    init() {
        super.init { _ in Java.new(JavaAPI.button, JavaAPI.newButton, .object(AndroidRenderer.context)) }
        Java.call(reference, JavaAPI.setAllCaps, .bool(false))

        let listener = Java.new(JavaAPI.click, JavaAPI.newClick, .long(number))
        Java.call(reference, JavaAPI.setOnClickListener, .object(listener.reference))
    }

    override func detach() {
        onClicked = nil
    }
}
