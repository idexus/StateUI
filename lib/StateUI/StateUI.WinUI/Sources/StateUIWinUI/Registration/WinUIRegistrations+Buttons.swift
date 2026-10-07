// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

extension WinUIRegistrations {
    /// A Button: its caption, its picture and its look, whether it takes a press, and the click.
    static func buttons(_ registry: Registry<WinUIView>) {
        registry.add(ButtonContract.self, create: { reports in
            let button = WinUIButtonView()
            button.onClicked = { reports.raise(ButtonContract.clicked) }
            button.onPressed = { reports.raise(ButtonContract.pressed) }
            button.onReleased = { reports.raise(ButtonContract.released) }
            return button
        }, members: { button in
            button.applies(TextMembers.members) { view, values in applyText(view, values) }
            button.applies([TextStyleElementContract.tracking, FontElementContract.fontSize]) { view, values in
                view.setLetterSpacing(values[TextStyleElementContract.tracking] ?? 0, size: values[FontElementContract.fontSize])
            }
            button.applies([
                VisualElementContract.background,
                BorderElementContract.shape, BorderElementContract.stroke, BorderElementContract.lineWidth,
            ]) { view, values in
                view.setLook(
                    background: values[VisualElementContract.background]?.propValue,
                    stroke: values[BorderElementContract.stroke]?.propValue,
                    lineWidth: values[BorderElementContract.lineWidth],
                    shape: values[BorderElementContract.shape]?.propValue)
            }
            button.applies([
                ButtonContract.icon, ButtonContract.iconPosition, ButtonContract.iconSpacing,
                ImageElementContract.contentMode,
            ]) { view, values in
                view.setIcon(
                    values[ButtonContract.icon].flatMap { $0.isEmpty ? nil : PictureArithmetic.files(for: $0.file) } ?? [],
                    position: values[ButtonContract.iconPosition] ?? .leading,
                    spacing: values[ButtonContract.iconSpacing], aspect: values[ImageElementContract.contentMode] ?? .fit)
            }
            button.property(ButtonContract.lineBreak) { view, lineBreak in view.setLineBreak(lineBreak) }
            button.property(VisualElementContract.isEnabled) { view, enabled in
                view.setEnabled(enabled ?? true)
            }
            button.raises(ButtonContract.clicked)
            button.raises(ButtonContract.pressed)
            button.raises(ButtonContract.released)
        })
    }
}
