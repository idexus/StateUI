// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A text field that searches.

/// SearchField's own properties - the half a `Style<SearchField>` shares with the
/// control, beside what its tiers already carry. The control conforms on
/// the element side and the style on the property side, which is what
/// makes the same modifiers compile on both.
public protocol SearchFieldProperties: PropertyContainer {}

extension SearchFieldProperties {
    /// What the keyboard's return key is captioned. What that key DOES is
    /// `.onSubmitted`, which is a handler rather than a caption.
    /// Already `.search` on a search box.
    public func returnKey(_ value: ReturnKey) -> Modified {
        setValue(.returnKey, value.propValue)
    }

    /// The colour of the button that empties the box - the one the platform
    /// draws inside the field once there is something to clear.
    public func cancelButtonColor(_ value: Color) -> Modified {
        setValue(.cancelButtonColor, value.propValue)
    }

    /// The colour of the magnifier drawn at the front of the field.
    public func searchIconColor(_ value: Color) -> Modified {
        setValue(.searchIconColor, value.propValue)
    }
}

/// A text field with a search button on the keyboard.
///
///     SearchField($query)
///         .placeholder("Search the list")
///         .onSubmitted { runTheSearch() }
///
/// A TextField that says what it is for: the platform draws the magnifier and the
/// cancel button, and the keyboard's return key searches.
///
/// It goes wherever a view goes - in the page's content, or ON the navigation
/// bar as that page's `titleView`, which is what an application
/// writes when it wants the bar to do the searching.
///
/// Given a binding the field shows the value and writes every edit back; given a
/// plain string it shows that, and `.onTextChanged` is how what is typed gets
/// anywhere.
public struct SearchField: InputView, TextElement, FontElement, TextAlignmentElement,
    SearchFieldProperties
{
    /// The node this control describes.
    public var node: Node

    /// An empty one - what a `Style<SearchField>` is written against.
    public init() {
        node = Node(type: .searchField)
    }

    /// A search box showing `text`. One-way: what is typed goes nowhere without
    /// `.onTextChanged`.
    public init(_ text: String) {
        node = Node(type: .searchField, props: [.text: .string(text)])
    }

    /// Two-way: shows what the binding holds, and writes back what is typed.
    public init(_ text: Binding<String>) {
        self = SearchField().text(text)
    }

    /// The same two-way text as `SearchField($text)`, written as a modifier.
    ///
    ///     SearchField($query)
    ///     SearchField().text($query)
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

    /// Fires when the search is submitted - the return key, or the magnifier
    /// where a platform draws a button.
    public func onSubmitted(_ handler: @escaping EventHandler) -> Self {
        addHandler(.submitted, handler)
    }
}
