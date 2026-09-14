// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// Label's own properties - the half a `Style<Label>` shares with the
/// control, beside what its tiers already carry. The control conforms on
/// the element side and the style on the property side, which is what
/// makes the same modifiers compile on both.
public protocol LabelProperties: PropertyContainer {}

extension LabelProperties {
    /// What happens to text too long for the space: wrap it, or cut it and say
    /// so.
    public func lineBreak(_ value: LineBreak) -> Modified {
        setValue(.lineBreak, value.propValue)
    }

    /// How many lines to show before the text is cut - what the cut LOOKS like
    /// is `lineBreak`'s business. A count of -1 means no limit, which is
    /// the default.
    public func maximumLines(_ value: Int) -> Modified {
        setValue(.maximumLines, .number(Double(value)))
    }
}

/// A read-only piece of text.
///
///     Label("Total")
///         .fontSize(20)
///         .fontAttributes(.bold)
///         .horizontalTextAlignment(.center)
///
/// The text is available in the initializer because it is what a Label is for.
/// Everything else is a modifier in StateUI's text vocabulary.
public struct Label: View, TextElement, FontElement, TextAlignmentElement,
    PaddingElement, LineHeightElement, DecorableTextElement, LabelProperties {
    /// The node this control describes.
    public var node: Node

    /// An empty one - what a `Style<Label>` is written against.
    public init() {
        node = Node(type: .label)
    }

    /// A label showing `text`.
    public init(_ text: String) {
        node = Node(type: .label, props: [.text: .string(text)])
    }

    /// The same spelling over a state the host carries: written by the host when the bytes
    /// change, never described - which is what lets a reading be rewritten
    /// sixty times a second at no render at all.
    ///
    /// - Parameter text: the state the words are read from.
    public init(_ text: Binding<String>) {
        self = Label().text(text)
    }

    /// Text made of runs, each with a look of its own.
    ///
    ///     Label()
    ///         .spans {
    ///             TextSpan("let ").textColor(.purple)
    ///             TextSpan("counter").textColor(.steelBlue)
    ///             TextSpan(" = 0")
    ///         }
    ///
    /// This is the ONLY way to colour part of a label: a Label has one
    /// `textColor`, and text in two colours is two runs. Syntax highlighting is
    /// what it is usually for, and a `ForEach` builds the runs - identified by
    /// where each one sits, since two tokens may read the same:
    ///
    ///     Label().spans {
    ///         ForEach(Array(highlighted(code).enumerated()), id: \.offset) { token in
    ///             TextSpan(token.element.text).textColor(token.element.colour)
    ///         }
    ///     }
    ///
    /// **This and `text` are mutually exclusive**: a Label given both shows
    /// the runs and not its `text`.
    public func spans(@ViewBuilder _ spans: () -> [Element]) -> Self {
        modified {
            $0.children = [Node(type: .spans, children: spans().map { $0.body })]
        }
    }
}

/// One run of text inside a Label, with its own colour, size and weight.
///
///     TextSpan("Sold out")
///         .textColor(.firebrick)
///         .fontAttributes(.bold)
///
/// NOT a view, which is why it wears `TextElement` and `FontElement` rather
/// than `View`: a run is a `BindableObject` with text and font properties
/// and nothing else - no opacity, no margin, no size of its own. It goes in one
/// place, a Label's `spans`, and nowhere else in the tree.
///
/// **`TextSpan` rather than `Span`, because `Span` is taken.** Swift's own
/// standard library has a `Span<Element>` - a view over contiguous memory - and
/// it is in scope in every file without an import, so an application writing
/// `Span("…")` gets *"no exact matches in call to initializer"* and a plain
/// `[Span]` gets *"reference to generic type 'Span' requires arguments"*.
/// Measured from a module importing this one. The node on the wire is `Span`
/// all the same - the vocabulary's name for a run, and what the fixture
/// sidecars read.
public struct TextSpan: BindableObject, TextElement, FontElement,
    LineHeightElement, DecorableTextElement {
    /// The node this run describes.
    public var node: Node

    /// An empty one, for a run built up by modifiers.
    public init() {
        node = Node(type: .span)
    }

    /// A run showing `text`.
    public init(_ text: String) {
        node = Node(type: .span, props: [.text: .string(text)])
    }

    /// What is drawn behind this run - a highlight over part of a line.
    public func background(_ value: Color) -> Self {
        setValue(.background, value.propValue)
    }
}
