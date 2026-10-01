// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
import CStateUIAndroid

/// The view for a control this host does not present yet: its name in red, where it belongs.
@MainActor
final class AndroidUnsupportedView: AndroidTextView {
    init(_ type: NodeType) {
        super.init { _ in Java.new(JavaAPI.textView, JavaAPI.newTextView, .object(AndroidRenderer.context)) }
        setText("Android: unsupported \(type.name)")
        Java.call(reference, JavaAPI.setTextColor, .int(Int32(bitPattern: 0xFFD3_2F2F)))
    }
}
