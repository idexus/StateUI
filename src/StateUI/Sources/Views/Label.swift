// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// MAUI: Label.

/// Label's own properties - the half a `Style<Label>` shares with the
/// control, beside what its tiers already carry. The control conforms on
/// the element side and the style on the property side, which is what
/// makes the same modifiers compile on both.
public protocol LabelProperties: PropertyContainer {}

extension LabelProperties {
    /// Whether the text is shown as written or read as HTML.
    /// MAUI: Label.TextType.
    ///
    ///     Label("<b>Bold</b> and <i>italic</i>").textType(.html)
    ///
    /// THE TRAP: with `.html` the font and colour modifiers compete with
    /// whatever the markup says, and which wins is the platform's business - a
    /// Label showing HTML is best left unstyled. For text in more than one
    /// colour that this side controls, `FormattedString` and its spans are the
    /// answer instead.
    public func textType(_ value: TextType) -> Modified {
        setValue(.textType, value.propValue)
    }

    /// What happens to text too long for the space: wrap it, or cut it and say
    /// so. MAUI: Label.LineBreakMode.
    public func lineBreakMode(_ value: LineBreakMode) -> Modified {
        setValue(.lineBreakMode, value.propValue)
    }

    /// How many lines to show before the text is cut - what the cut LOOKS like
    /// is `lineBreakMode`'s business. MAUI: Label.MaxLines, whose -1 means no
    /// limit and is the default.
    public func maxLines(_ value: Int) -> Modified {
        setValue(.maxLines, .number(Double(value)))
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
/// Everything else is a modifier, named exactly as the MAUI property is.
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

    /// A label showing what a state holds - and the DECLARATION says how.
    ///
    ///     @State private var name = "Ada"                    // described
    ///     @State(describing: .none) private var clock = "0.0" // driven
    ///
    ///     Label($name)     // rebuilt when it changes
    ///     Label($clock)    // written by the host, never described
    ///
    /// ONE SPELLING, and `describing:` on the declaration decides which of the
    /// two it is. A driven state costs no render at all, which is what lets a
    /// reading be rewritten sixty times a second; a described one is an
    /// ordinary value the tree shows.
    ///
    /// - Parameter text: the state the words are read from.
    public init(_ text: Binding<String>) {
        self = text.driving == nil ? Label(text.wrappedValue) : Label().text(text)
    }

    /// Text made of runs, each with a look of its own.
    /// MAUI: Label.FormattedText, which takes a FormattedString of Spans.
    ///
    ///     Label()
    ///         .formattedText {
    ///             TextSpan("let ").textColor(.purple)
    ///             TextSpan("counter").textColor(.steelBlue)
    ///             TextSpan(" = 0")
    ///         }
    ///
    /// This is the ONLY way to colour part of a label: a MAUI Label has one
    /// TextColor, and text in two colours is two Spans. Syntax highlighting is
    /// what it is usually for, and a `ForEach` builds the runs - identified by
    /// where each one sits, since two tokens may read the same:
    ///
    ///     Label().formattedText {
    ///         ForEach(Array(highlighted(code).enumerated()), id: \.offset) { token in
    ///             TextSpan(token.element.text).textColor(token.element.colour)
    ///         }
    ///     }
    ///
    /// **This and `text` are mutually exclusive**, and that is MAUI's rule
    /// rather than one made here: assigning FormattedText puts Text back to
    /// null. Measured. A Label given both shows the runs, since they are
    /// applied last.
    public func formattedText(@ViewBuilder _ spans: () -> [Element]) -> Self {
        modified {
            $0.children = [Node(type: .formattedString, children: spans().map { $0.body })]
        }
    }
}

/// One run of text inside a Label, with its own colour, size and weight.
/// MAUI: Span.
///
///     TextSpan("Sold out")
///         .textColor(.firebrick)
///         .fontAttributes(.bold)
///
/// NOT a view, which is why it wears `TextElement` and `FontElement` rather
/// than `View`: MAUI's Span is a BindableObject with text and font properties
/// and nothing else - no opacity, no margin, no size of its own. It goes in one
/// place, a Label's `formattedText`, and nowhere else in the tree.
///
/// **`TextSpan` rather than `Span`, because `Span` is taken.** Swift's own
/// standard library has a `Span<Element>` - a view over contiguous memory - and
/// it is in scope in every file without an import, so an application writing
/// `Span("…")` gets *"no exact matches in call to initializer"* and a plain
/// `[Span]` gets *"reference to generic type 'Span' requires arguments"*.
/// Measured from a module importing this one. The node on the wire is `Span`
/// all the same - MAUI's class name, and what the fixture sidecars read.
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
    /// MAUI: Span.BackgroundColor.
    public func backgroundColor(_ value: Color) -> Self {
        setValue(.backgroundColor, value.propValue)
    }
}
