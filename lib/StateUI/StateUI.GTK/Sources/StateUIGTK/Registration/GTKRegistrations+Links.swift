// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

extension GTKRegistrations {
    /// A link: its words in their case and their color, and whether it can be chosen; a click the host layer opens
    /// its address on.
    static func links(_ registry: Registry<GTKView>) {
        registry.add(LinkContract.self, create: { reports in
            let link = GTKLinkView()
            link.onClicked = { reports.raise(LinkContract.clicked) }
            return link
        }, members: { link in
            link.property(VisualElementContract.isEnabled) { view, enabled in view.setEnabled(enabled ?? true) }
            link.applies(TextMembers.captionMembers) { view, values in
                view.setCaption(TextMembers.caption(values), look: TextMembers.captionLook(values))
            }
            // The address is the host layer's to open as the link is chosen; the view holds nothing of it.
            link.property(LinkContract.destination) { _, _ in }
            link.raises(LinkContract.clicked)
        })
    }
}
