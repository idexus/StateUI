// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A view showing the words the text tier writes: a label's own, a button's or a radio button's caption.
@MainActor
protocol WinUIWordsView: WinUIView {
    /// The words shown.
    func setText(_ text: String)
}

extension WinUITextView: WinUIWordsView {}
extension WinUIButtonView: WinUIWordsView {}
