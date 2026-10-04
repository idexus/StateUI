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

/// A text field whose editor's text checking follows the field's traits - the field is its editor's delegate.
@MainActor
final class AppKitWordsField: NSTextField {
    var traits = InputTraits(spellChecked: true, predicted: true, purpose: nil)

    @objc(textView:willCheckTextInRange:options:types:)
    func textView(
        _ view: NSTextView, willCheckTextIn range: NSRange, options: [NSSpellChecker.OptionKey: Any],
        types: UnsafeMutablePointer<NSTextCheckingTypes>
    ) -> [NSSpellChecker.OptionKey: Any] {
        traits.checking(options)
    }
}
#endif
