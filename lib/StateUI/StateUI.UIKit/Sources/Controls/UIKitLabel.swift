// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// What a Text shows: its words in their case, or its spans' runs each in its own look over the label's, where they
/// stand across and down its room, and how they break - the same whether the user can select them or not.
/// Design: docs/design/platforms/uikit/controls.md#a-labels-words
struct UIKitLabelWords {
    var text = ""
    var look = TextLook()
    var runs: [TextRun]?
    var horizontal = TextAlignment.start
    var vertical = TextAlignment.start
    var breaking = LineBreak.wordWrap

    /// The most lines that show; 0 for any.
    var lines = 0

    /// The words - or the runs - with their look in `traits`.
    func attributed(in traits: UITraitCollection) -> NSAttributedString {
        let shown = NSMutableAttributedString()
        for run in runs ?? [TextRun(text: text, look: TextLook())] {
            shown.append(NSAttributedString(
                string: run.text, attributes: run.look.over(look).attributes(color: .label, in: traits)))
        }
        return shown.length > 0
            ? shown : NSAttributedString(string: "", attributes: look.attributes(color: .label, in: traits))
    }

    /// Where the words stand across, a line's start and end following `direction`.
    func alignment(in direction: UIUserInterfaceLayoutDirection) -> NSTextAlignment {
        switch horizontal {
        case .start: .natural
        case .center: .center
        case .end: direction == .rightToLeft ? .left : .right
        }
    }

    /// How a line too long for the room breaks, or where it is cut: wrapped words held to some lines end the last
    /// with an ellipsis (`LineBreak.endsWithEllipsis`), which UIKit draws wrapping at words.
    var lineBreakMode: NSLineBreakMode {
        if breaking.endsWithEllipsis(maximum: lines) { return .byTruncatingTail }
        return switch breaking {
        case .noWrap: .byClipping
        case .wordWrap: .byWordWrapping
        case .characterWrap: .byCharWrapping
        case .headTruncation: .byTruncatingHead
        case .tailTruncation: .byTruncatingTail
        case .middleTruncation: .byTruncatingMiddle
        }
    }
}

/// A Text's view: a label showing its words, or a text view in which the user selects them.
/// Design: docs/design/platforms/uikit/controls.md#selectable-words
@MainActor
protocol UIKitLabel: UIView {
    /// What the view shows.
    var shown: UIKitLabelWords { get set }

    /// Whether the words show as enabled, and can be selected where they can be.
    var isEnabled: Bool { get set }

    /// Shows the words again as `shown` says.
    func showWords()

    /// The room between the view's edge and its words.
    func setPadding(_ insets: Insets?)

    /// What fills the view's box behind its words: a colour, or a brush; nothing where the tree says none.
    func setBackground(_ value: HostValue?)
}

extension UIKitLabel {
    /// The words, in their case.
    func setText(_ text: String) {
        shown.text = text
        showWords()
    }

    /// Changes the words' look; what it leaves unsaid is the system's.
    func setLook(_ change: (inout TextLook) -> Void) {
        change(&shown.look)
        showWords()
    }

    /// The spans' runs in place of the words; nil for the words again.
    func setRuns(_ runs: [TextRun]?) {
        // Shown without runs before, the words stand already.
        guard runs != nil || shown.runs != nil else { return }
        shown.runs = runs
        showWords()
    }

    /// Where the words stand across and down the room: a line's start and end follow the view's own direction.
    func setAlignment(horizontal: TextAlignment, vertical: TextAlignment) {
        (shown.horizontal, shown.vertical) = (horizontal, vertical)
        showWords()
    }

    /// How the words break, and how many lines show (`LineBreak.lines`).
    func setLines(breaking: LineBreak, maximum: Int?) {
        shown.breaking = breaking
        shown.lines = breaking.lines(maximum: maximum) ?? 0
        showWords()
    }
}
#endif
