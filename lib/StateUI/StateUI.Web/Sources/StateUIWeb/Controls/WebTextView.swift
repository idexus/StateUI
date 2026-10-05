// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A Text: a `<span>` whose words wrap at the width it is given and keep their line breaks.
/// Design: docs/design/platforms/web/controls.md#words
@MainActor
final class WebTextView: WebDOMView, WebWordsView {
    init() {
        super.init(tag: "span")
        style("white-space", "pre-wrap")
    }
}
