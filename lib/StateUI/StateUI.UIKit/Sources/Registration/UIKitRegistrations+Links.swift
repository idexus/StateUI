// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

extension UIKitRegistrations {
    /// A link: its words and their color, whether it can be chosen; a tap the host layer opens its address on.
    static func links(_ registry: Registry<UIView>) {
        registry.add(LinkContract.self, create: { reports in
            let link = UIKitLinkView()
            link.onClicked = { reports.raise(LinkContract.clicked) }
            return link
        }, members: { link in
            link.applies(TextMembers.captionMembers) { view, values in
                view.show(
                    TextMembers.caption(values),
                    color: values[TextColorElementContract.textColor].flatMap { UIColor(stateUI: $0.propValue) })
            }
            link.property(VisualElementContract.isEnabled) { view, enabled in view.isEnabled = enabled ?? true }
            // The address is the host layer's to open as the link is chosen; the view holds nothing of it.
            link.property(LinkContract.destination) { _, _ in }
            link.raises(LinkContract.clicked)
        })
    }
}
#endif
