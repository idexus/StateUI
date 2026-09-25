// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

extension GTKRegistrations {
    /// A Button: its caption, whether it takes a press, and the click.
    static func buttons(_ registry: Registry<GTKView>) {
        registry.add(ButtonContract.self, create: { reports in
            let button = GTKButtonView()
            button.onClicked = { reports.raise(ButtonContract.clicked) }
            return button
        }, members: { button in
            button.applies([TextElementContract.text, TextElementContract.textCase]) { view, values in
                view.setText(cased(values[TextElementContract.text] ?? "", values[TextElementContract.textCase]))
            }
            button.property(VisualElementContract.isEnabled) { view, enabled in
                view.setEnabled(enabled ?? true)
            }
            button.raises(ButtonContract.clicked)
        })
    }
}
