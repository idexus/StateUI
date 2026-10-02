// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// `Text`'s own properties, shared by the control and its `Style<Text>`.
public protocol TextProperties: PropertyContainer {}

extension TextProperties {
    /// What happens to text too long for the space: wrap it, or cut it and say
    /// so.
    public func lineBreak(_ value: LineBreak) -> Modified {
        setValue(TextContract.lineBreak, value)
    }

    /// How many lines to show before the text is cut - what the cut LOOKS like
    /// is `lineBreak`'s business. A count of -1 means no limit, which is
    /// the default.
    public func maximumLines(_ value: Int) -> Modified {
        setValue(TextContract.maximumLines, value)
    }
}

/// A read-only piece of text.
///
///     Text("Total")
///         .fontSize(20)
///         .fontAttributes(.bold)
///         .horizontalTextAlignment(.center)
public struct Text: ElementView, TextElement, FontElement, TextAlignmentElement,
    PaddingElement, LineHeightElement, DecorableTextElement, TextProperties {
    /// The node this control describes.
    public var node: Node

    /// An empty one - what a `Style<Text>` is written against.
    public init() {
        node = Node(contract: TextContract.self)
    }

    /// Words showing `text`.
    public init(_ text: String) {
        node = Node(contract: TextContract.self)
        node.write(TextElementContract.text, text)
    }

    /// Words carried from a state, written by the host as it
    /// changes, at no render.
    ///
    /// - Parameter text: the state the words are read from.
    public init(_ text: Binding<String>) {
        self = Text().text(text)
    }

    /// Text made of runs, each with a look of its own.
    ///
    ///     Text()
    ///         .spans {
    ///             TextSpan("let ").textColor(.purple)
    ///             TextSpan("counter").textColor(.steelBlue)
    ///             TextSpan(" = 0")
    ///         }
    ///
    /// The one way to colour part of the words: text in two colours is two runs.
    /// A list of runs goes in whole, each matched by where it sits, since two
    /// tokens may read the same:
    ///
    ///     Text().spans {
    ///         highlighted(code).map { TextSpan($0.text).textColor($0.colour) }
    ///     }
    ///
    /// A Text given both runs and a `text` shows the runs.
    public func spans(@TextSpanBuilder _ spans: () -> [TextSpan]) -> Self {
        modified {
            $0.children = [Node(contract: TextSpansContract.self, children: spans().map { $0.node })]
        }
    }
}

/// One run of text inside a Text, with its own colour, size and weight.
///
///     TextSpan("Sold out")
///         .textColor(.firebrick)
///         .fontAttributes(.bold)
///
/// Not a view: a run has text and font properties and nothing else, and it
/// goes only in a Text's `spans`.
public struct TextSpan: ModifiableElement, TextElement, FontElement,
    LineHeightElement, DecorableTextElement {
    /// The node this run describes.
    public var node: Node

    /// An empty one, for a run built up by modifiers.
    public init() {
        node = Node(contract: TextSpanContract.self)
    }

    /// A run showing `text`.
    public init(_ text: String) {
        node = Node(contract: TextSpanContract.self)
        node.write(TextElementContract.text, text)
    }

    /// What is drawn behind this run - a highlight over part of a line.
    public func background(_ value: Color) -> Self {
        setValue(TextSpanContract.background, value)
    }
}

extension Text {
    /// `maximumLines` from a state, `$x`: the host sets each new value as it
    /// stands, and no view is rebuilt for it.
    public func maximumLines(_ state: Binding<Int>) -> Modified {
        plain(.maximumLines, by: state)
    }
}
