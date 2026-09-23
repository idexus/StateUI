// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
import CStateUIAndroid

/// A Label: a `TextView`.
@MainActor
final class AndroidLabelView: AndroidTextView {
    init() {
        super.init { _ in Java.new(JavaAPI.textView, JavaAPI.newTextView, .object(AndroidRenderer.context)) }
    }
}
