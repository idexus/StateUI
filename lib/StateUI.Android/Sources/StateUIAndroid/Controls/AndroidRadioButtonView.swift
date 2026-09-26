// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
import CStateUIAndroid

/// A RadioButton: an `android.widget.RadioButton` with its words beside it; the tree says which others
/// its check takes away.
@MainActor
final class AndroidRadioButtonView: AndroidToggleView {
    init() {
        super.init { _ in Java.new(JavaAPI.radioButton, JavaAPI.newRadioButton, .object(AndroidRenderer.context)) }
    }
}
