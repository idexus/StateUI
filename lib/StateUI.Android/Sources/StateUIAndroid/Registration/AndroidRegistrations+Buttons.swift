// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

extension AndroidRegistrations {
    /// A Button: its caption, and its click.
    static func buttons(_ registry: Registry<AndroidView>) {
        registry.add(ButtonContract.self, create: { reports in
            let button = AndroidButtonView()
            button.onClicked = { reports.raise(ButtonContract.clicked) }
            return button
        }, members: { button in
            button.applies(textMembers) { view, values in applyText(view, values) }
            button.property(VisualElementContract.isEnabled) { view, enabled in
                view.setEnabled(enabled ?? true)
            }
            button.raises(ButtonContract.clicked)
        })
    }
}
