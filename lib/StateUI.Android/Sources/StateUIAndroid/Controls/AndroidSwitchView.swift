// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
import CStateUIAndroid

/// A Switch: an `android.widget.Switch`.
@MainActor
final class AndroidSwitchView: AndroidToggleView {
    init() {
        super.init { _ in Java.new(JavaAPI.switchView, JavaAPI.newSwitch, .object(AndroidRenderer.context)) }
    }
}
