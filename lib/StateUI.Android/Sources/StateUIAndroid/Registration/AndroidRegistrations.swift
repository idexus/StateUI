// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// The contracts this host realizes through the core's registry: how each
/// element's view is made, which of its members the view takes, and what it reports.
@MainActor
enum AndroidRegistrations {
    /// The registry, built once.
    static let registry: Registry<AndroidView> = {
        let registry = Registry<AndroidView>()

        text(registry)
        buttons(registry)
        toggles(registry)
        values(registry)
        fields(registry)
        layouts(registry)
        shared(registry)

        return registry
    }()

    /// What `AndroidElement` puts on every view wearing each member's contract.
    static func shared(_ registry: Registry<AndroidView>) {
        registry.everyElementRealizes(VisualElementContract.opacity)
        registry.everyElementRealizes(VisualElementContract.isVisible)
        registry.everyElementRealizes(VisualElementContract.background)
        registry.everyElementRealizes(VisualElementContract.width)
        registry.everyElementRealizes(VisualElementContract.height)
        registry.everyElementRealizes(VisualElementContract.minimumWidth)
        registry.everyElementRealizes(VisualElementContract.minimumHeight)
        registry.everyElementRealizes(VisualElementContract.maximumWidth)
        registry.everyElementRealizes(VisualElementContract.maximumHeight)
        registry.everyElementRealizes(ViewContract.margin)
        registry.everyElementRealizes(ViewContract.horizontalAlignment)
        registry.everyElementRealizes(ViewContract.verticalAlignment)
    }

    /// The words of a text control, their size, weight and colour.
    static let textMembers: [any ContractMember] = [
        TextElementContract.text, FontElementContract.fontSize,
        FontElementContract.fontAttributes, TextStyleElementContract.textColor,
    ]

    /// Puts `textMembers` on a text view.
    static func applyText<Realized: ElementContract>(_ view: AndroidTextView, _ values: ElementValues<Realized>) {
        if values.changed(TextElementContract.text) {
            view.setText(values[TextElementContract.text] ?? "")
        }
        if values.changed(FontElementContract.fontSize) {
            view.setFontSize(values[FontElementContract.fontSize])
        }
        if values.changed(FontElementContract.fontAttributes) {
            view.setFontAttributes(values[FontElementContract.fontAttributes])
        }
        if values.changed(TextStyleElementContract.textColor) {
            view.setTextColor(values[TextStyleElementContract.textColor]?.propValue)
        }
    }
}
