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
        pictures(registry)
        shared(registry)

        return registry
    }()

    /// What `AndroidElement` puts on every view wearing each member's contract.
    static func shared(_ registry: Registry<AndroidView>) {
        registry.everyElementRealizes(VisualElementContract.opacity)
        registry.everyElementRealizes(VisualElementContract.translationX)
        registry.everyElementRealizes(VisualElementContract.translationY)
        registry.everyElementRealizes(VisualElementContract.rotation)
        registry.everyElementRealizes(VisualElementContract.rotationX)
        registry.everyElementRealizes(VisualElementContract.rotationY)
        registry.everyElementRealizes(VisualElementContract.scale)
        registry.everyElementRealizes(VisualElementContract.scaleX)
        registry.everyElementRealizes(VisualElementContract.scaleY)
        registry.everyElementRealizes(VisualElementContract.pivotX)
        registry.everyElementRealizes(VisualElementContract.pivotY)
        registry.everyElementRealizes(VisualElementContract.isVisible)
        registry.everyElementRealizes(VisualElementContract.background)
        registry.everyElementRealizes(VisualElementContract.width)
        registry.everyElementRealizes(VisualElementContract.height)
        registry.everyElementRealizes(VisualElementContract.minimumWidth)
        registry.everyElementRealizes(VisualElementContract.minimumHeight)
        registry.everyElementRealizes(VisualElementContract.maximumWidth)
        registry.everyElementRealizes(VisualElementContract.maximumHeight)
        registry.everyElementRealizes(ViewContract.margin)
        registry.everyElementRealizes(ViewContract.gridRow)
        registry.everyElementRealizes(ViewContract.gridColumn)
        registry.everyElementRealizes(ViewContract.gridRowSpan)
        registry.everyElementRealizes(ViewContract.gridColumnSpan)
        registry.everyElementRealizes(ViewContract.absoluteLayoutBounds)
        registry.everyElementRealizes(ViewContract.absoluteLayoutProportions)
        registry.everyElementRealizes(ViewContract.horizontalAlignment)
        registry.everyElementRealizes(ViewContract.verticalAlignment)
    }

    /// The words of a text control, their size, weight and colour, and the room around them.
    static let textMembers: [any ContractMember] = [
        TextElementContract.text, FontElementContract.fontSize,
        FontElementContract.fontAttributes, TextStyleElementContract.textColor,
        PaddingElementContract.padding,
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
        if values.changed(PaddingElementContract.padding) {
            view.setPadding(values[PaddingElementContract.padding])
        }
    }
}
