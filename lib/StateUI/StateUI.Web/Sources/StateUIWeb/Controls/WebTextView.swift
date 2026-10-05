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

    /// Shows `runs` in place of the text's own words, each in its look; nil to show the words again.
    /// Design: docs/design/platforms/web/controls.md#runs-of-words
    func setRuns(_ shown: [TextRun]?) {
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
            for (name, value) in WebCSS.font(run.look) + WebCSS.spacing(run.look) { span.style(name, value) }
            span.style("background", WebCSS.fill(run.look.background))
        }
        runs = spans
    }

    /// How the words break: onto more lines at words or anywhere, or on one line, cut short where they do not
    /// fit - at their end, the one cut the page draws - and on how many lines at most.
    func setLines(breaking lineBreak: LineBreak, maximum: Int?) {
        let lines = lineBreak.lines(maximum: maximum)
        style("white-space", lineBreak.wraps ? "pre-wrap" : "pre")
        style("overflow-wrap", lineBreak.wraps ? "break-word" : nil)
        style("word-break", lineBreak == .characterWrap ? "break-all" : nil)
        style("text-overflow", lineBreak.truncates ? "ellipsis" : nil)
        let clamped = lineBreak.wraps && lines != nil
        style("overflow", lineBreak.wraps && !clamped ? nil : "hidden")
        style("display", clamped ? "-webkit-box" : nil)
        style("-webkit-box-orient", clamped ? "vertical" : nil)
        style("-webkit-line-clamp", clamped ? String(lines!) : nil)
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

    func setBackground(_ value: HostValue?) {
        style("background", WebCSS.fill(value))
    }

    override func detach() {
        for span in runs ?? [] { span.detach() }
        super.detach()
    }
}
