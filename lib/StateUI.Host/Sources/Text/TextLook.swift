// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// How words look where the tree says, in the contract's terms - each nil or empty for the host's own - which a
/// host turns into its toolkit's attributes.
/// Design: docs/design/host/tree.md#runs-of-words
@_spi(Host) public struct TextLook: Equatable, Sendable {
    /// The font's size in points.
    public var size: Double?

    /// The font's weight and slant.
    public var attributes = FontAttributes.none

    /// The font's family.
    public var family: String?

    /// The words' colour, as the tree gives it.
    public var color: HostValue?

    /// What stands behind the words, as the tree gives it.
    public var background: HostValue?

    /// The space between the letters, in points.
    public var letterSpacing = 0.0

    /// A line's height as a multiple of the font's own.
    public var lineHeight: Double?

    /// The lines under or through the words.
    public var decorations = TextDecorations.none

    /// A look saying nothing: the host's own throughout.
    public init() {}

    /// The space between the letters as a share of a font `size` points tall - what a toolkit spacing letters in
    /// ems takes; nothing for a size that is none.
    public func letterSpacing(inEmsOf size: Double) -> Double {
        size > 0 && size.isFinite ? letterSpacing / size : 0
    }

    /// This look where it says something, `other` where it says nothing: a run of words over its label's look.
    public func over(_ other: TextLook) -> TextLook {
        var look = self
        look.size = size ?? other.size
        look.attributes = attributes.isEmpty ? other.attributes : attributes
        look.family = family ?? other.family
        look.color = color ?? other.color
        look.background = background ?? other.background
        look.letterSpacing = letterSpacing != 0 ? letterSpacing : other.letterSpacing
        look.lineHeight = lineHeight ?? other.lineHeight
        look.decorations = decorations.isEmpty ? other.decorations : decorations
        return look
    }
}

/// One run of a label's words: the words in their case, and their own look.
@_spi(Host) public struct TextRun: Equatable, Sendable {
    /// The words.
    public let text: String

    /// Their look, which the label's look stands behind.
    public let look: TextLook

    /// `text` looking as `look` says.
    public init(text: String, look: TextLook) {
        self.text = text
        self.look = look
    }
}

extension MountedElement {
    /// A label's spans as runs of its words, each in its case - its own, else the label's - and its look; nil
    /// where the label holds no spans.
    public var textRuns: [TextRun]? {
        guard let spans = children.first(where: { $0.type == .spans }) else { return nil }
        let labelCase = value(.textCase)
        return spans.children.filter { $0.type == .span }.map { span in
            var look = TextLook()
            look.size = span.number(.fontSize)
            look.attributes = span.value(.fontAttributes)?.enumeration.map { FontAttributes(rawValue: $0) } ?? .none
            look.color = span.value(.textColor)
            look.background = span.value(.background)
            look.decorations = span.value(.textDecorations)?.enumeration.map { TextDecorations(rawValue: $0) } ?? .none
            let textCase = (span.value(.textCase) ?? labelCase)?.enumeration.flatMap(TextCase.init(rawValue:))
            return TextRun(text: (textCase ?? .none).applied(to: span.string(.text) ?? ""), look: look)
        }
    }
}
