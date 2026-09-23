// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

extension AndroidRegistrations {
    /// A Label: a `TextView`.
    static func text(_ registry: Registry<AndroidView>) {
        registry.add(LabelContract.self, create: { _ in AndroidLabelView() }) { label in
            label.applies(textMembers) { view, values in applyText(view, values) }
        }
    }
}
