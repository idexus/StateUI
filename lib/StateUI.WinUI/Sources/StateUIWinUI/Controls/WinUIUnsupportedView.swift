// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// The view for a control this host does not present yet: its name in red, where it belongs.
@MainActor
final class WinUIUnsupportedView: WinUITextView {
    init(_ type: NodeType) {
        super.init()
        setText("WinUI: unsupported \(type.name)")
        setTextColor(0xFFD3_2F2F)
    }
}
