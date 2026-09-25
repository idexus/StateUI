// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

extension GTKRegistrations {
    /// A Label: a `GtkLabel` - its words, in the case asked for.
    static func text(_ registry: Registry<GTKView>) {
        registry.add(LabelContract.self, create: { _ in GTKLabelView() }) { label in
            label.applies([TextElementContract.text, TextElementContract.textCase]) { view, values in
                view.setText(cased(values[TextElementContract.text] ?? "", values[TextElementContract.textCase]))
            }
        }
    }
}
