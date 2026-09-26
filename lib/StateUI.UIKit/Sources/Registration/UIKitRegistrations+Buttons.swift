// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

extension UIKitRegistrations {
    /// A Button: its words and their look, and the user's tap as its click.
    static func buttons(_ registry: Registry<UIView>) {
        registry.add(ButtonContract.self, create: { reports in
            let button = UIKitButtonView()
            button.onClicked = { reports.raise(ButtonContract.clicked) }
            return button
        }, members: { button in
            button.applies(TextMembers.members) { view, values in
                if let words = TextMembers.words(values) { view.setText(words) }
                if let look = TextMembers.look(values) { view.setLook(look) }
            }
            button.raises(ButtonContract.clicked)
        })
    }
}
#endif
