// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUIHost

extension NSTextView {
    /// Checks, corrects, replaces and predicts the words a user types here as `traits` say.
    /// Design: docs/design/platforms/appkit/views.md#what-typing-is-given
    func take(_ traits: InputTraits) {
        isContinuousSpellCheckingEnabled = traits.checksSpelling
        isAutomaticSpellingCorrectionEnabled = traits.corrects
        isAutomaticTextReplacementEnabled = traits.corrects
        isAutomaticTextCompletionEnabled = traits.predicts
        inlinePredictionType = traits.predicts ? .default : .no
    }
}

extension InputTraits {
    /// The options the text checking a user's typing runs is given: capitals where the traits say, over the user's
    /// own setting; the platform's own where they leave it.
    func checking(_ options: [NSSpellChecker.OptionKey: Any]) -> [NSSpellChecker.OptionKey: Any] {
        var given = options
        switch capitals {
        case .platform: break
        case .sentences: given[.automaticCapitalizationEnabledKey] = true
        case .none: given[.automaticCapitalizationEnabledKey] = false
        }
        return given
    }
}

/// A field standing in a filled box drawn around it: the ring it draws while it holds the keyboard goes round the box,
/// rounded as the box is.
@MainActor
protocol AppKitBoxedField: NSTextField {
    /// The box the field stands in, in the field's own coordinates; nil for the field's own ring.
    var ringBox: NSRect? { get set }
}

extension AppKitBoxedField {
    /// The ring's outline round `box`: the box's corners.
    func drawRing(round box: NSRect) {
        NSBezierPath(roundedRect: box, xRadius: AppKitTextEditorView.cornerRadius, yRadius: AppKitTextEditorView.cornerRadius)
            .fill()
    }
}

/// A text field whose editor's text checking follows the field's traits - the field is its editor's delegate.
@MainActor
final class AppKitWordsField: NSTextField, AppKitBoxedField {
    var traits = InputTraits(spellChecked: true, predicted: true, purpose: nil)

    var ringBox: NSRect? {
        didSet { if ringBox != oldValue { noteFocusRingMaskChanged() } }
    }

    override var focusRingMaskBounds: NSRect { ringBox ?? super.focusRingMaskBounds }

    override func drawFocusRingMask() {
        guard let ringBox else { return super.drawFocusRingMask() }
        drawRing(round: ringBox)
    }

    @objc(textView:willCheckTextInRange:options:types:)
    func textView(
        _ view: NSTextView, willCheckTextIn range: NSRange, options: [NSSpellChecker.OptionKey: Any],
        types: UnsafeMutablePointer<NSTextCheckingTypes>
    ) -> [NSSpellChecker.OptionKey: Any] {
        traits.checking(options)
    }
}

/// A secure text field whose ring goes round the box it stands in.
@MainActor
final class AppKitSecureWordsField: NSSecureTextField, AppKitBoxedField {
    var ringBox: NSRect? {
        didSet { if ringBox != oldValue { noteFocusRingMaskChanged() } }
    }

    override var focusRingMaskBounds: NSRect { ringBox ?? super.focusRingMaskBounds }

    override func drawFocusRingMask() {
        guard let ringBox else { return super.drawFocusRingMask() }
        drawRing(round: ringBox)
    }
}
#endif
