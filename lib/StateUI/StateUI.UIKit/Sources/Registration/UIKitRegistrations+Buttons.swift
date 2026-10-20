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
                    view.setLook { $0.adopt(fontAndColorOf: look) }
                }
                if values.changed(PaddingElementContract.padding) {
                    view.setPadding(values[PaddingElementContract.padding])
                }
            }
            button.property(VisualElementContract.isEnabled) { view, enabled in view.isEnabled = enabled ?? true }
            button.property(TrackingElementContract.tracking) { view, spacing in
                view.setLook { $0.letterSpacing = spacing ?? 0 }
            }
            button.applies([ButtonContract.icon, ButtonContract.iconPosition, ButtonContract.iconSpacing]) { view, values in
                view.setIcon(
                    HostPicture(values[ButtonContract.icon], dark: false).flatMap(UIKitRenderer.image),
                    position: values[ButtonContract.iconPosition] ?? .leading,
                    spacing: values[ButtonContract.iconSpacing])
            }
            // The box, and the role's look where the tree draws nothing of its own: the main action filled in the
            // tint, a destructive one's words in the system's red.
            button.applies([
                VisualElementContract.background, BorderElementContract.stroke, BorderElementContract.lineWidth,
                BorderElementContract.shape, ButtonContract.role, TextColorElementContract.textColor,
            ]) { view, values in
                let background = HostMaterial(values[VisualElementContract.background]?.propValue).painted
                let look = ButtonRoleLook(
                    values[ButtonContract.role], fills: background != nil,
                    colorsWords: values[TextColorElementContract.textColor] != nil)
                view.setBox(
                    background: background,
                    stroke: values[BorderElementContract.stroke]?.propValue,
                    width: values[BorderElementContract.lineWidth],
                    shape: values[BorderElementContract.shape]?.propValue,
                    accent: look.fillsInAccent)
                view.setCriticalWords(look.wordsInCritical)
            }
            button.property(ButtonContract.lineBreak) { view, breaking in view.setLineBreak(breaking ?? .wordWrap) }
            // UIKit's own role; its key is the window root's (`KeyboardShortcuts.pressing`).
            button.property(ButtonContract.role) { view, role in
                view.role = switch role {
                case .primary: .primary
                case .cancel: .cancel
                case .destructive: .destructive
                case nil: .normal
                }
            }
            button.raises(ButtonContract.clicked)
            button.raises(ButtonContract.pressed)
            button.raises(ButtonContract.released)
        })
    }
}
#endif
