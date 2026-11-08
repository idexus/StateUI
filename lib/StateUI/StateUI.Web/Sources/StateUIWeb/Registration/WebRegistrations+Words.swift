// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

extension WebRegistrations {
    /// A Text and a Button: their words in their case, their font and color and the room around them; a text's
    /// lines, alignment, spacing and decorations; a button's picture, its lines, its spacing, its box, whether it
    /// takes a click, the press, its release and the click.
    static func words(_ registry: Registry<WebDOMView>) {
        registry.add(TextContract.self, create: { _ in WebTextView() }) { text in
            text.applies(TextMembers.members) { view, values in applyWords(view, values) }
            text.applies(LineBreakElementContract.lineBreak, TextContract.maximumLines) { view, values in
                view.setLines(breaking: values[LineBreakElementContract.lineBreak] ?? .wordWrap, maximum: values[TextContract.maximumLines])
            }
            text.property(TextAlignmentElementContract.horizontalTextAlignment) { view, alignment in
                view.setAlignment(horizontal: alignment ?? .start)
            }
            text.property(TextContract.verticalTextAlignment) { view, alignment in
                view.setAlignment(vertical: alignment ?? .start)
            }
            text.property(TextContract.isSelectable) { view, selectable in view.isSelectable = selectable ?? false }
            text.applies(
                TrackingElementContract.tracking, LineHeightElementContract.lineHeight,
                DecorableTextElementContract.textDecorations) { view, values in
                var look = TextLook()
                look.letterSpacing = values[TrackingElementContract.tracking] ?? 0
                look.lineHeight = values[LineHeightElementContract.lineHeight]
                look.decorations = values[DecorableTextElementContract.textDecorations] ?? []
                view.setSpacing(look)
            }
        }

        registry.add(ButtonContract.self, create: { reports in
            let button = WebButtonView()
            button.onClicked = { reports.raise(ClickElementContract.clicked) }
            button.listenForHolding(
                pressed: { reports.raise(PressElementContract.pressed) }, released: { reports.raise(PressElementContract.released) })
            return button
        }, members: { button in
            button.applies(TextMembers.members) { view, values in applyWords(view, values) }
            button.applies(
                IconElementContract.icon, ButtonContract.iconPosition, ButtonContract.iconSpacing,
                ContentModeElementContract.contentMode, TextAndIconElementContract.showsText) { view, values in
                view.setIcon(
                    values[IconElementContract.icon], position: values[ButtonContract.iconPosition] ?? .start,
                    spacing: values[ButtonContract.iconSpacing], aspect: values[ContentModeElementContract.contentMode] ?? .fit,
                    showsText: TextAndIcon.showsText(
                        values[TextAndIconElementContract.showsText],
                        hasPicture: HostPicture(values[IconElementContract.icon], dark: false) != nil, byDefault: true))
            }
            button.property(LineBreakElementContract.lineBreak) { view, lineBreak in view.setLines(lineBreak) }
            button.property(TrackingElementContract.tracking) { view, spacing in
                view.style("letter-spacing", WebCSS.letterSpacing(spacing ?? 0))
            }
            button.applies(
                BackgroundElementContract.background, BorderElementContract.shape, BorderElementContract.stroke,
                BorderElementContract.lineWidth) { view, values in
                view.setBox(
                    fill: values[BackgroundElementContract.background]?.propValue,
                    stroke: values[BorderElementContract.stroke]?.propValue,
                    lineWidth: values[BorderElementContract.lineWidth],
                    shape: values[BorderElementContract.shape]?.propValue)
            }
            button.property(EnabledElementContract.isEnabled) { view, enabled in view.setEnabled(enabled ?? true) }
            // The page holds a shortcut on no control - the one stated, else the role's: the window's keys reach it,
            // and assistive technology is told. The role is the document's own for the main action, a submit, and
            // the page's look for each.
            button.applies(ShortcutElementContract.keyboardShortcut, ButtonContract.role) { view, values in
                let role = values[ButtonContract.role]
                let shortcut = KeyboardShortcuts.pressing(stated: values[ShortcutElementContract.keyboardShortcut], role: role)
                view.attribute("aria-keyshortcuts", shortcut.map { WebKeys.spelled($0, onApple: WebRelay.onApple) })
                view.attribute("type", role == .primary ? "submit" : "button")
                view.attribute("data-role", role.map { ["primary", "cancel", "destructive"][Int($0.rawValue)] })
            }
            button.declares(ClickElementContract.clicked)
            button.declares(PressElementContract.pressed)
            button.declares(PressElementContract.released)
        })
    }

    /// Puts the text tiers' members (`TextMembers`) on a view showing words.
    static func applyWords<Realized: ElementContract>(_ view: some WebWordsView, _ values: ElementValues<Realized>) {
        if let words = TextMembers.words(values) { view.setText(words) }
        if let look = TextMembers.look(values) { view.setLook(look) }
        if values.changed(PaddingElementContract.padding) { view.setPadding(values[PaddingElementContract.padding]) }
    }
}
