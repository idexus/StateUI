// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

extension UIKitRegistrations {
    /// A Button: its words and their look, an icon beside them, the box behind them and the room inside it; the
    /// user's tap as its click, and the press as it goes down and is let go.
    static func buttons(_ registry: Registry<UIView>) {
        registry.add(ButtonContract.self, create: { reports in
            let button = UIKitButtonView()
            button.onClicked = { reports.raise(ButtonContract.clicked) }
            button.onPressed = { reports.raise(ButtonContract.pressed) }
            button.onReleased = { reports.raise(ButtonContract.released) }
            return button
        }, members: { button in
            button.applies(TextMembers.members) { view, values in
                if let words = TextMembers.words(values) { view.setText(words) }
                if let look = TextMembers.look(values) {
                    view.setLook { shown in
                        (shown.size, shown.attributes, shown.family, shown.color) =
                            (look.size, look.attributes, look.family, look.color)
                    }
                }
                if values.changed(PaddingElementContract.padding) {
                    view.setPadding(values[PaddingElementContract.padding])
                }
            }
            button.property(VisualElementContract.isEnabled) { view, enabled in view.isEnabled = enabled ?? true }
            button.property(TextStyleElementContract.characterSpacing) { view, spacing in
                view.setLook { $0.letterSpacing = spacing ?? 0 }
            }
            button.applies([ButtonContract.icon, ButtonContract.iconPosition, ButtonContract.iconSpacing]) { view, values in
                view.setIcon(
                    values[ButtonContract.icon].flatMap { $0.isEmpty ? nil : UIKitRenderer.image(named: $0.file) },
                    position: values[ButtonContract.iconPosition] ?? .leading,
                    spacing: values[ButtonContract.iconSpacing])
            }
            button.applies([
                VisualElementContract.background, BorderElementContract.stroke, BorderElementContract.strokeWidth,
                BorderElementContract.shape,
            ]) { view, values in
                view.setBox(
                    background: values[VisualElementContract.background]?.propValue,
                    stroke: values[BorderElementContract.stroke]?.propValue,
                    width: values[BorderElementContract.strokeWidth],
                    shape: values[BorderElementContract.shape]?.propValue)
            }
            button.property(ButtonContract.lineBreak) { view, breaking in view.setLineBreak(breaking ?? .wordWrap) }
            button.raises(ButtonContract.clicked)
            button.raises(ButtonContract.pressed)
            button.raises(ButtonContract.released)
        })
    }
}
#endif
