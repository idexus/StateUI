// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// `Label`'s own properties, shared by the control and its `Style<Label>`.
public protocol LabelProperties: PropertyContainer {}

extension LabelProperties {
    /// What happens to text too long for the space: wrap it, or cut it and say
    /// so.
    public func lineBreak(_ value: LineBreak) -> Modified {
        setValue(LabelContract.lineBreak, value)
    }

    /// How many lines to show before the text is cut - what the cut LOOKS like
    /// is `lineBreak`'s business. A count of -1 means no limit, which is
    /// the default.
    public func maximumLines(_ value: Int) -> Modified {
        setValue(LabelContract.maximumLines, value)
    }
}

/// A read-only piece of text.
///
///     Label("Total")
///         .fontSize(20)
///         .fontAttributes(.bold)
///         .horizontalTextAlignment(.center)
public struct Label: View, TextElement, FontElement, TextAlignmentElement,
    PaddingElement, LineHeightElement, DecorableTextElement, LabelProperties {
    /// The node this control describes.
    public var node: Node

    /// An empty one - what a `Style<Label>` is written against.
    public init() {
        node = Node(contract: LabelContract.self)
    }

    /// A label showing `text`.
    public init(_ text: String) {
        node = Node(contract: LabelContract.self)
        node.write(TextElementContract.text, text)
    }

    /// A label whose text is carried from a state, written by the host as it
    /// changes, at no render.
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
    /// The one way to colour part of a label: text in two colours is two runs.
    /// A `ForEach` builds them, keyed by where each sits, since two tokens may
    /// read the same:
    ///
    ///     Label().spans {
    ///         ForEach(Array(highlighted(code).enumerated()), id: \.offset) { token in
    ///             TextSpan(token.element.text).textColor(token.element.colour)
    ///         }
    ///     }
    ///
    /// A Label given both runs and a `text` shows the runs.
    public func spans(@ViewBuilder _ spans: () -> [Element]) -> Self {
        modified {
            $0.children = [Node(contract: SpansContract.self, children: spans().map { $0.body })]
        }
    }
}

/// One run of text inside a Label, with its own colour, size and weight.
///
///     TextSpan("Sold out")
///         .textColor(.firebrick)
///         .fontAttributes(.bold)
///
/// Not a view: a run has text and font properties and nothing else, and it
/// goes only in a Label's `spans`.
public struct TextSpan: ModifiableElement, TextElement, FontElement,
    LineHeightElement, DecorableTextElement {
    /// The node this run describes.
    public var node: Node

    /// An empty one, for a run built up by modifiers.
    public init() {
        node = Node(contract: SpanContract.self)
    }

    /// A run showing `text`.
    public init(_ text: String) {
        node = Node(contract: SpanContract.self)
        node.write(TextElementContract.text, text)
    }

    /// What is drawn behind this run - a highlight over part of a line.
    public func background(_ value: Color) -> Self {
        setValue(SpanContract.background, value)
    }
}
