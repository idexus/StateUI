// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// MAUI: Editor.

/// Editor's own properties - the half a `Style<Editor>` shares with the
/// control, beside what its tiers already carry. The control conforms on
/// the element side and the style on the property side, which is what
/// makes the same modifiers compile on both.
public protocol EditorProperties: PropertyContainer {}

extension EditorProperties {
    /// Whether the editor grows as the text does. MAUI: Editor.AutoSize.
    ///
    ///     Editor($notes).autoSize(.textChanges)
    ///
    /// `.textChanges` grows the control on every edit; `.disabled` - MAUI's own
    /// default - keeps the height it was given and scrolls the text inside it.
    /// A growing editor wants a ScrollView above it, having no height of its
    /// own to stop at.
    public func autoSize(_ value: EditorAutoSizeOption) -> Modified {
        setValue(.autoSize, value.propValue)
    }
}

/// A text field of several lines. MAUI: Editor.
///
///     @State private var notes = ""
///     …
///     Editor($notes)
///         .placeholder("Anything worth remembering")
///         .heightRequest(120)
///
/// An `Entry` with room: the same two-way binding and the same handlers, over a
/// field that wraps and keeps the newlines the reader types. Where an Entry
/// ends its editing with a Return, this one takes it as text - so there is no
/// `onCompleted` from the keyboard, only from losing the focus.
public struct Editor: InputView, TextElement, FontElement, TextAlignmentElement, EditorProperties {
    /// The node this control describes.
    public var node: Node

    /// An empty one - what a `Style<Editor>` is written against.
    public init() {
        node = Node(type: .editor)
    }

    /// An editor showing `text`. One-way: what is typed goes nowhere without
    /// `.onTextChanged`, which is what the binding form does for you.
    public init(_ text: String) {
        node = Node(type: .editor, props: [.text: .string(text)])
    }

    /// Two-way: shows what the binding holds, and writes back what is typed.
    public init(_ text: Binding<String>) {
        self = Editor().text(text)
    }

    /// The same two-way text as `Editor($text)`, written as a modifier.
    ///
    ///     Editor($query)
    ///     Editor().text($query)
    ///
    /// BOTH SPELLINGS ALWAYS, and they mean the same thing: the initializer is
    /// the short way to say what gives this control its purpose, and the
    /// modifier is the way every other property is written. Neither is the
    /// real one.
    ///
    /// HANDED OVER, so the field is no reader of the state: the host writes
    /// the field's text from the state on its own frames and lands what the
    /// reader types back on it, whole, as its own write. What a keystroke
    /// COSTS is decided by who reads the state at build - nothing where nobody
    /// prints it, a render per keystroke for the body that does. A part of a
    /// state or a binding made from closures has no storage for the host to
    /// carry and takes the described road instead: shown from the value read
    /// at build, written back through the binding on every report, the
    /// closure that wrote the field a reader of it.
    ///
    /// - Parameter value: the state shown, and written back into as the reader
    ///   types.
    /// - Returns: the control, wearing and reporting that text.
    public func text(_ value: Binding<String>) -> Modified {
        value.image == nil
            ? described(.text, value, on: .textChanged)
            : words(.text, by: value, mode: .inOut)
    }

    // MARK: Properties

    // MARK: Events

    /// Fires when the editor loses the focus after being edited - the place to
    /// save what was written. MAUI: Editor.Completed.
    ///
    /// A Return is an ordinary newline here, so nothing on the keyboard ends
    /// the editing; only moving the focus away does.
    public func onCompleted(_ handler: @escaping EventHandler) -> Self {
        addHandler(.completed, handler)
    }
}
