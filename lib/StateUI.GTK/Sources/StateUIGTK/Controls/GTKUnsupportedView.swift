// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
import CStateUIGTK

/// The view for a control this host does not present yet: its name in libadwaita's error colour, where it belongs.
@MainActor
final class GTKUnsupportedView: GTKTextView {
    init(_ type: NodeType) {
        super.init()
        setText("GTK: unsupported \(type.name)")
        gtk_widget_add_css_class(widget, "error")
    }
}
