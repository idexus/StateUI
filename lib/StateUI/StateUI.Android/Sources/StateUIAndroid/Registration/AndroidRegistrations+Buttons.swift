// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

extension AndroidRegistrations {
    /// A Button: its caption and its icon, its look, and the three moments of a press.
    static func buttons(_ registry: Registry<AndroidView>) {
        registry.add(ButtonContract.self, create: { reports in
            let button = AndroidButtonView()
            button.onClicked = { reports.raise(ClickElementContract.clicked) }
            button.onPressed = { reports.raise(PressElementContract.pressed) }
            button.onReleased = { reports.raise(PressElementContract.released) }
            return button
        }, members: { button in
            button.applies(TextMembers.members) { view, values in applyText(view, values) }
            button.property(TrackingElementContract.tracking) { view, spacing in view.setLetterSpacing(spacing ?? 0) }
            button.applies(
                IconElementContract.icon, ButtonContract.iconPosition, ButtonContract.iconSpacing,
                ContentModeElementContract.contentMode, TextAndIconElementContract.showsText) { view, values in
                let icon = HostPicture(values[IconElementContract.icon], dark: false)
                view.setIcon(
                    icon, position: values[ButtonContract.iconPosition] ?? .start,
                    spacing: values[ButtonContract.iconSpacing], aspect: values[ContentModeElementContract.contentMode] ?? .fit,
                    showsText: TextAndIcon.showsText(
                        values[TextAndIconElementContract.showsText], hasPicture: icon != nil, byDefault: true))
            }
            button.applies(
                BorderElementContract.shape, BorderElementContract.stroke,
                BorderElementContract.lineWidth) { view, values in
                view.setOutline(
                    stroke: values[BorderElementContract.stroke]?.propValue,
                    width: values[BorderElementContract.lineWidth],
                    shape: values[BorderElementContract.shape]?.propValue)
            }
            button.property(LineBreakElementContract.lineBreak) { view, breaking in
                view.setLines(breaking: breaking ?? .wordWrap, maximum: nil)
            }
            button.property(EnabledElementContract.isEnabled) { view, enabled in
                view.setEnabled(enabled ?? true)
            }
            // The role's look; its key is the window's (`KeyboardShortcuts.pressing`).
            button.property(ButtonContract.role) { view, role in view.setRole(role) }
            button.declares(ClickElementContract.clicked)
            button.declares(PressElementContract.pressed)
            button.declares(PressElementContract.released)
        })
    }
}
