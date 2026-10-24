// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

extension WebRegistrations {
    /// A link: its words in their case and their color, its address; a click the host layer opens it on.
    static func links(_ registry: Registry<WebDOMView>) {
        registry.add(LinkContract.self, create: { reports in
            let link = WebLinkView()
            link.onClicked = { reports.raise(LinkContract.clicked) }
            return link
        }, members: { link in
            link.applies(TextMembers.captionMembers) { view, values in
                view.setText(TextMembers.caption(values))
                view.setColor(values[TextColorElementContract.textColor]?.propValue)
            }
            link.property(LinkContract.destination) { view, address in view.setDestination(address) }
            link.raises(LinkContract.clicked)
        })
    }
}
