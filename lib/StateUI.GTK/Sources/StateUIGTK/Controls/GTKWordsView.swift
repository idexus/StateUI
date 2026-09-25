// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A view showing words: a label, a button's caption - its words and how they look.
/// Design: docs/design/platforms/gtk/controls.md#words
@MainActor
protocol GTKWordsView: GTKView {
    func setText(_ text: String)
    func setLook(_ change: (inout GTKTextLook) -> Void)
}

extension GTKTextView: GTKWordsView {}
extension GTKButtonView: GTKWordsView {}
