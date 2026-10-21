// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

extension WinUIRegistrations {
    /// A Button: its caption, its picture and its look, whether it takes a press, the press, its release and the click.
    static func buttons(_ registry: Registry<WinUIView>) {
        registry.add(ButtonContract.self, create: { reports in
            // A button holding a menu is made as it opens it from the first.
            let button = WinUIButtonView(
                menu: ButtonMenu.opening(made: reports.made), showsArrow: ButtonMenu.showsArrow(made: reports.made))
            button.onClicked = { reports.raise(ButtonContract.clicked) }
            button.onPressed = { reports.raise(ButtonContract.pressed) }
            button.onReleased = { reports.raise(ButtonContract.released) }
            return button
        }, members: { button in
            button.applies(TextMembers.members) { view, values in applyText(view, values) }
            button.applies(TrackingElementContract.tracking, FontElementContract.fontSize) { view, values in
                view.setLetterSpacing(values[TrackingElementContract.tracking] ?? 0, size: values[FontElementContract.fontSize])
            }
            button.applies(
                VisualElementContract.background, BorderElementContract.shape, BorderElementContract.stroke,
                BorderElementContract.lineWidth) { view, values in
                view.setLook(
                    background: HostMaterial(values[VisualElementContract.background]?.propValue).painted,
                    stroke: values[BorderElementContract.stroke]?.propValue,
                    lineWidth: values[BorderElementContract.lineWidth],
                    shape: values[BorderElementContract.shape]?.propValue)
            }
            button.applies(
                ButtonContract.icon, ButtonContract.iconPosition, ButtonContract.iconSpacing,
                ImageElementContract.contentMode) { view, values in
                view.setIcon(
                    WinUIPictures.lines(HostPicture(values[ButtonContract.icon], dark: false)),
                    position: values[ButtonContract.iconPosition] ?? .start,
                    spacing: values[ButtonContract.iconSpacing], aspect: values[ImageElementContract.contentMode] ?? .fit)
            }
            button.property(ButtonContract.lineBreak) { view, lineBreak in view.setLineBreak(lineBreak) }
            // WinUI's own accelerator - the one stated, else the role's - pressing the button while its window is in
            // front, and the role's look: the accent style for the main action, a destructive one's words in the
            // theme's critical colour where the tree colours them not.
            button.applies(
                ButtonContract.keyboardShortcut, ButtonContract.role,
                TextColorElementContract.textColor) { view, values in
                let role = values[ButtonContract.role]
                view.setShortcut(KeyboardShortcuts.pressing(stated: values[ButtonContract.keyboardShortcut], role: role))
                view.setRole(role)
                view.setCritical(
                    ButtonRoleLook(role, fills: false, colorsWords: values[TextColorElementContract.textColor] != nil)
                        .wordsInCritical)
            }
            button.property(VisualElementContract.isEnabled) { view, enabled in
                view.setEnabled(enabled ?? true)
            }
            button.raises(ButtonContract.clicked)
            button.raises(ButtonContract.pressed)
            button.raises(ButtonContract.released)
        })
    }
}
