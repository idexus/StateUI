// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
import CStateUIGTK

/// A `GtkLabel`: its words, wrapped at the width it is given, from its leading edge, in the look the tree gives them.
/// Design: docs/design/platforms/gtk/controls.md#words
@MainActor
class GTKTextView: GTKView {
    /// How the words look.
    private(set) var look = GTKTextLook()

    /// A run of words and how it looks over the label's own look.
    struct Run {
        let text: String
        let look: GTKTextLook
    }

    /// The label's own words, and the runs shown in their place; nil while none are.
    private var ownText = ""
    private var runs: [Run]?

    init() {
        super.init { _ in gtk_label_new(nil) }
        setLines(breaking: .wordWrap, maximum: nil)
        gtk_label_set_xalign(widget.opaque, 0)
    }

    /// The label's own words, shown while it shows no runs.
    func setText(_ text: String) {
        ownText = text
        if runs == nil { gtk_label_set_text(widget.opaque, text) }
        shownWordsChanged()
    }

    /// Runs of words shown in place of the label's own, each in its own look; nil shows its own words again.
    /// Design: docs/design/platforms/gtk/controls.md#runs-of-words
    func setRuns(_ runs: [Run]?) {
        self.runs = runs
        gtk_label_set_text(widget.opaque, runs.map { $0.map(\.text).joined() } ?? ownText)
        writeLook()
        shownWordsChanged()
    }

    override var shownWords: String? { text }

    /// The words the label shows now, read back from GTK.
    var text: String {
        String(cString: gtk_label_get_text(widget.opaque))
    }

    /// Changes how the words look.
    func setLook(_ change: (inout GTKTextLook) -> Void) {
        change(&look)
        writeLook()
    }

    /// Writes the look on the words: the label's over all of them, or each run's over its own bytes.
    private func writeLook() {
        let list = pango_attr_list_new()!
        if let runs {
            var start: UInt32 = 0
            for run in runs {
                let end = start + UInt32(run.text.utf8.count)
                run.look.over(look).insert(into: list, from: start, to: end)
                start = end
            }
        } else {
            look.insert(into: list)
        }
        gtk_label_set_attributes(widget.opaque, list)
        pango_attr_list_unref(list)
    }

    /// How words too long for the width break, and how many lines show before they are cut; nil or less than one
    /// for no limit. GTK cuts a word short at its start or middle on one line only; over more, at its end.
    /// Design: docs/design/platforms/gtk/controls.md#words
    func setLines(breaking: LineBreak, maximum: Int?) {
        let label = widget.opaque
        let most = Int32(max(maximum ?? 0, 0))
        let wraps: Bool
        let cut: PangoEllipsizeMode
        switch breaking {
        case .noWrap:
            (wraps, cut) = (false, PANGO_ELLIPSIZE_NONE)
        case .wordWrap, .characterWrap:
            (wraps, cut) = (true, most > 0 ? PANGO_ELLIPSIZE_END : PANGO_ELLIPSIZE_NONE)
        case .headTruncation:
            (wraps, cut) = (most > 1, most > 1 ? PANGO_ELLIPSIZE_END : PANGO_ELLIPSIZE_START)
        case .middleTruncation:
            (wraps, cut) = (most > 1, most > 1 ? PANGO_ELLIPSIZE_END : PANGO_ELLIPSIZE_MIDDLE)
        case .tailTruncation:
            (wraps, cut) = (most > 1, PANGO_ELLIPSIZE_END)
        }
        gtk_label_set_wrap(label, wraps ? 1 : 0)
        gtk_label_set_wrap_mode(label, breaking == .characterWrap ? PANGO_WRAP_CHAR : PANGO_WRAP_WORD_CHAR)
        gtk_label_set_ellipsize(label, cut)
        gtk_label_set_lines(label, wraps && most > 0 ? most : -1)
    }

    /// Where the lines stand across the label: from its leading edge, in its middle, or at its trailing edge.
    func setAlignment(horizontal: TextAlignment) {
        let (share, justification): (Float, GtkJustification) = switch horizontal {
        case .start: (0, GTK_JUSTIFY_LEFT)
        case .center: (0.5, GTK_JUSTIFY_CENTER)
        case .end: (1, GTK_JUSTIFY_RIGHT)
        }
        gtk_label_set_xalign(widget.opaque, share)
        gtk_label_set_justify(widget.opaque, justification)
    }
}
