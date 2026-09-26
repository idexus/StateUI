// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

extension UIKitRegistrations {
    /// A Label: its words in their case and their look (`TextMembers`), how they break, where they stand.
    static func text(_ registry: Registry<UIView>) {
        registry.add(LabelContract.self, create: { _ in UIKitLabelView() }) { label in
            label.applies(TextMembers.members) { view, values in
                if let words = TextMembers.words(values) { view.text = words }
                if let look = TextMembers.look(values) { view.setLook(look) }
            }
            label.applies([LabelContract.lineBreak, LabelContract.maximumLines]) { view, values in
                view.setLines(
                    breaking: values[LabelContract.lineBreak] ?? .wordWrap, maximum: values[LabelContract.maximumLines])
            }
            label.applies([
                TextAlignmentElementContract.horizontalTextAlignment,
                TextAlignmentElementContract.verticalTextAlignment,
            ]) { view, values in
                view.setAlignment(
                    horizontal: values[TextAlignmentElementContract.horizontalTextAlignment] ?? .start,
                    vertical: values[TextAlignmentElementContract.verticalTextAlignment] ?? .start)
            }
        }
    }
}
#endif
