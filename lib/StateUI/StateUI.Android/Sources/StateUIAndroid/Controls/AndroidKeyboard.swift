// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUIHost

extension InputTraits {
    /// Android's kind of input for words of these traits - the keys they pick, hidden where `password`, on several
    /// lines where `multiLine`, with their capitals, correction and suggestions: a field's and a prompt's alike.
    /// Design: docs/design/platforms/android/controls.md#what-typing-is-given
    func inputType(password: Bool, multiLine: Bool) -> Int32 {
        switch keys {
        case .number:
            return ViewConstants.numberInput | ViewConstants.decimalNumber | (password ? ViewConstants.hiddenNumber : 0)
        case .digits:
            return ViewConstants.numberInput | (password ? ViewConstants.hiddenNumber : 0)
        case .telephone:
            return ViewConstants.phoneInput
        case .words, .email, .url:
            let variation = password ? ViewConstants.passwordInput
                : keys == .email ? ViewConstants.emailInput : keys == .url ? ViewConstants.linkInput : 0
            return ViewConstants.textInput | variation | (multiLine ? ViewConstants.multiLineInput : 0)
                | (capitals == .sentences ? ViewConstants.sentenceCapitals : 0)
                | (corrects && !password ? ViewConstants.autoCorrect : 0)
                | (predicts ? 0 : ViewConstants.noSuggestions)
        }
    }

    /// What Android's autofill is told the words are, which it fills them in from; none for words of no such kind.
    var autofillHints: [String] {
        switch content {
        case .emailAddress: ["emailAddress"]
        case .telephoneNumber: ["phone"]
        case .username: ["username"]
        case .newPassword: ["newPassword"]
        case .oneTimeCode: ["smsOTPCode"]
        case .url, nil: []
        }
    }
}
