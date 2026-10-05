// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// An element no registration makes yet: its name, in the page's colour for errors, where it belongs.
@MainActor
final class WebUnsupportedView: WebDOMView {
    init(_ type: NodeType) {
        super.init(tag: "span")
        attribute("class", "stateui-unsupported")
        WebRelay.setText(node, "Web: unsupported \(type.name)")
    }
}
