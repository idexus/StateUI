// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

extension WinUIRegistrations {
    /// A link: its words in their case and their color, and whether it can be chosen; a click the host layer opens
    /// its address on.
    static func links(_ registry: Registry<WinUIView>) {
        registry.add(LinkContract.self, create: { reports in
            let link = WinUILinkView()
            link.onClicked = { reports.raise(LinkContract.clicked) }
            return link
        }, members: { link in
            link.applies(TextMembers.captionMembers) { view, values in
                view.setText(TextMembers.caption(values))
                view.setForeground(values[TextColorElementContract.textColor]?.propValue)
            }
            link.property(VisualElementContract.isEnabled) { view, enabled in
                view.setEnabled(enabled ?? true)
            }
            // The address is the host layer's to open as the link is chosen; the view holds nothing of it.
            link.property(LinkContract.destination) { _, _ in }
            link.raises(LinkContract.clicked)
        })
    }
}
