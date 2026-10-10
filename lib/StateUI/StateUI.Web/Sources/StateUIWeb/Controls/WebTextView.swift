// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A Text: a `<span>` whose words wrap at the width it is given and keep their line breaks, or show runs of words,
/// each a `<span>` of its own look over the text's.
/// Design: docs/design/platforms/web/controls.md#words
@MainActor
final class WebTextView: WebDOMView, WebWordsView {
    /// The text's own words, shown where it holds no runs.
    private var words = ""

    /// A span for each run shown, in order; nil showing the text's own words.
    private var runs: [WebDOMView]?

    init() {
        super.init(tag: "span")
        setLines(breaking: .wordWrap, maximum: nil)
    }

    func setText(_ text: String) {
        words = text
        if runs == nil { WebRelay.setText(node, text) }
    }

    /// Shows `runs` in place of the text's own words, each in its look over the text's `look`; nil to show the words
    /// again. A run held at its size within words that scale holds the text's size where it gives none.
    /// Design: docs/design/platforms/web/controls.md#runs-of-words
    func setRuns(_ shown: [TextRun]?, over look: TextLook) {
        guard let shown else {
            for span in runs ?? [] { span.detach() }
            runs = nil
            return WebRelay.setText(node, words)
        }
        if runs == nil { WebRelay.setText(node, "") }
        var spans = runs ?? []
        while spans.count > shown.count { spans.removeLast().detach() }
        while spans.count < shown.count { spans.append(WebDOMView(tag: "span")) }
        for (index, (span, run)) in zip(spans, shown).enumerated() {
            WebRelay.insert(span.node, into: node, at: index)
            WebRelay.setText(span.node, run.text)
            var runLook = run.look
            runLook.scales = run.look.scales && look.scales
            if runLook.scales != look.scales, runLook.size == nil { runLook.size = look.size }
            for (name, value) in WebCSS.font(runLook) + WebCSS.spacing(runLook) { span.style(name, value) }
            span.style("background", WebCSS.fill(run.look.background))
        }
        runs = spans
    }

    /// How the words break: onto more lines at words or anywhere, or on one line, cut short where they do not
    /// fit - at their end, the one cut the page draws - and on how many lines at most.
    func setLines(breaking lineBreak: LineBreak, maximum: Int?) {
        for (name, value) in WebCSS.lines(lineBreak, most: lineBreak.lines(maximum: maximum)) { style(name, value) }
    }

    func setAlignment(horizontal: TextAlignment) {
        style("text-align", horizontal == .center ? "center" : horizontal == .end ? "end" : nil)
    }

    /// Where the words stand down a box taller than they are.
    func setAlignment(vertical: TextAlignment) {
        style("align-content", vertical == .center ? "center" : vertical == .end ? "end" : nil)
    }

    func setSpacing(_ look: TextLook) {
        for (name, value) in WebCSS.spacing(look) { style(name, value) }
    }

    override func detach() {
        for span in runs ?? [] { span.detach() }
        super.detach()
    }
}
