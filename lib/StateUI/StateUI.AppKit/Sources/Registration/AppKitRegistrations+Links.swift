// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

extension AppKitRegistrations {
    /// A link: its words, their color and whether it can be chosen; a click the host layer opens its address on.
    static func links(_ registry: Registry<NSView>) {
        registry.add(LinkContract.self, create: { reports in
            let link = AppKitLinkView()
            link.onClicked = { reports.raise(LinkContract.clicked) }
            return link
        }, members: { link in
            link.applies(VisualElementContract.isEnabled, TextMembers.captionMembers) { view, values in
                view.apply(
                    text: TextMembers.caption(values),
                    color: values[TextColorElementContract.textColor].flatMap { nsColor($0.propValue) },
                    enabled: values[VisualElementContract.isEnabled] ?? true)
            }
            // The address is the host layer's to open as the link is chosen; the view holds nothing of it.
            link.property(LinkContract.destination) { _, _ in }
            link.raises(LinkContract.clicked)
        })
    }
}
#endif
