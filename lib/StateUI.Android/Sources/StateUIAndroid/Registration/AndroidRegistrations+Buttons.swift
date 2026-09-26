// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

extension AndroidRegistrations {
    /// A Button: its caption and its icon, its look, and the three moments of a press.
    static func buttons(_ registry: Registry<AndroidView>) {
        registry.add(ButtonContract.self, create: { reports in
            let button = AndroidButtonView()
            button.onClicked = { reports.raise(ButtonContract.clicked) }
            button.onPressed = { reports.raise(ButtonContract.pressed) }
            button.onReleased = { reports.raise(ButtonContract.released) }
            return button
        }, members: { button in
            button.applies(textMembers) { view, values in applyText(view, values) }
            button.applies([
                ButtonContract.icon, ButtonContract.iconPosition, ButtonContract.iconSpacing,
                ImageElementContract.aspect,
            ]) { view, values in
                view.setIcon(
                    values[ButtonContract.icon], position: values[ButtonContract.iconPosition] ?? .leading,
                    spacing: values[ButtonContract.iconSpacing], aspect: values[ImageElementContract.aspect] ?? .fit)
            }
            button.applies([
                BorderElementContract.shape, BorderElementContract.stroke, BorderElementContract.strokeWidth,
            ]) { view, values in
                view.setOutline(
                    stroke: values[BorderElementContract.stroke]?.propValue,
                    width: values[BorderElementContract.strokeWidth],
                    shape: values[BorderElementContract.shape]?.propValue)
            }
            button.property(ButtonContract.lineBreak) { view, breaking in
                view.setLines(breaking: breaking ?? .wordWrap, maximum: nil)
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
