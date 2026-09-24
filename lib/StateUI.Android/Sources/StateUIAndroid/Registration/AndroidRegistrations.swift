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
        pickers(registry)
        dates(registry)
        values(registry)
        fields(registry)
        layouts(registry)
        pictures(registry)
        shapes(registry)
        drawing(registry)
        indicators(registry)
        shared(registry)

        return registry
    }()

    /// The acts this host performs, whichever element each is aimed at; `AndroidActPerformer` answers
    /// exactly these, and refuses every other by name.
    static let acts: [any ContractMember] = [
        VisualElementContract.focus, VisualElementContract.unfocus,
        ApplicationContract.alert, ApplicationContract.announce, ApplicationContract.chooseAction,
        ApplicationContract.confirm, ApplicationContract.currentTime, ApplicationContract.currentTimeZone,
        ApplicationContract.handlerFailed, ApplicationContract.hideOnScreenKeyboard, ApplicationContract.persistValue,
        ApplicationContract.prompt, ApplicationContract.utcOffset,
    ]

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
        registry.everyElementRaises(ViewContract.tapped)
        registry.everyElementRealizes(ViewContract.horizontalAlignment)
        registry.everyElementRealizes(ViewContract.verticalAlignment)
    }

    /// The words of a text control, their size, weight and colour, and the room around them.
    static let textMembers: [any ContractMember] = [
        TextElementContract.text, TextElementContract.textCase, FontElementContract.fontSize,
        FontElementContract.fontAttributes, FontElementContract.fontFamily, TextStyleElementContract.textColor,
        PaddingElementContract.padding,
    ]

    /// Puts `textMembers` on a text view.
    static func applyText<Realized: ElementContract>(_ view: AndroidTextView, _ values: ElementValues<Realized>) {
        if values.changed(TextElementContract.text) || values.changed(TextElementContract.textCase) {
            view.setText(cased(values[TextElementContract.text] ?? "", values[TextElementContract.textCase]))
        }
        if values.changed(FontElementContract.fontSize) {
            view.setFontSize(values[FontElementContract.fontSize])
        }
        if values.changed(FontElementContract.fontAttributes) {
            view.setFontAttributes(values[FontElementContract.fontAttributes])
        }
        if values.changed(FontElementContract.fontFamily) {
            view.setFontFamily(values[FontElementContract.fontFamily]?.text)
        }
        if values.changed(TextStyleElementContract.textColor) {
            view.setTextColor(values[TextStyleElementContract.textColor]?.propValue)
        }
        if values.changed(PaddingElementContract.padding) {
            view.setPadding(values[PaddingElementContract.padding])
        }
    }

    /// `text` in the case the tree asks for: as written, or in one case throughout.
    static func cased(_ text: String, _ textCase: TextCase?) -> String {
        switch textCase {
        case .lowercase: text.lowercased()
        case .uppercase: text.uppercased()
        default: text
        }
    }
}
