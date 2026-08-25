// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// MAUI: SearchBar (and the InputView properties it inherits).

/// SearchBar's own properties - the half a `Style<SearchBar>` shares with the
/// control, beside what its tiers already carry. The control conforms on
/// the element side and the style on the property side, which is what
/// makes the same modifiers compile on both.
public protocol SearchBarProperties: PropertyContainer {}

extension SearchBarProperties {
    /// What the keyboard's return key is captioned. What that key DOES is
    /// `.onSearchButtonPressed`, which is a handler rather than a caption.
    /// MAUI: SearchBar.ReturnType, already `.search` on a search box.
    public func returnType(_ value: ReturnType) -> Modified {
        setValue(.returnType, value.propValue)
    }

    /// The colour of the button that empties the box - the one the platform
    /// draws inside the field once there is something to clear.
    /// MAUI: SearchBar.CancelButtonColor.
    public func cancelButtonColor(_ value: Color) -> Modified {
        setValue(.cancelButtonColor, value.propValue)
    }

    /// The colour of the magnifier drawn at the front of the field.
    /// MAUI: SearchBar.SearchIconColor.
    public func searchIconColor(_ value: Color) -> Modified {
        setValue(.searchIconColor, value.propValue)
    }
}

/// A text field with a search button on the keyboard. MAUI: SearchBar.
///
///     SearchBar($query)
///         .placeholder("Search the list")
///         .onSearchButtonPressed { runTheSearch() }
///
/// An Entry that says what it is for: the platform draws the magnifier and the
/// cancel button, and the keyboard's return key searches.
///
/// It goes wherever a view goes - in the page's content, or ON the navigation
/// bar as that page's `navigationPageTitleView`, which is what an application
/// writes when it wants the bar to do the searching.
///
/// Given a binding the field shows the value and writes every edit back; given a
/// plain string it shows that, and `.onTextChanged` is how what is typed gets
/// anywhere.
public struct SearchBar: InputView, TextElement, FontElement, TextAlignmentElement,
    SearchBarProperties
{
    /// The node this control describes.
    public var node: Node

    /// An empty one - what a `Style<SearchBar>` is written against.
    public init() {
        node = Node(type: .searchBar)
    }

    /// A search box showing `text`. One-way: what is typed goes nowhere without
    /// `.onTextChanged`.
    public init(_ text: String) {
        node = Node(type: .searchBar, props: [.text: .string(text)])
    }

    /// Two-way: shows what the binding holds, and writes back what is typed.
    public init(_ text: Binding<String>) {
        node = Node(type: .searchBar, props: [.text: .string(text.wrappedValue)])
        node.addHandler(.textChanged) {
            if let typed = EventBuffer.current.value()?.string {
                text.wrappedValue = typed
            }
        }
    }

    // MARK: Properties

    // MARK: Events

    /// Fires on every edit, with the new text. Runs after a binding's write, if
    /// there is one. MAUI: InputView.TextChanged.
    public func onTextChanged(_ handler: @escaping ValueEventHandler<String>) -> Self {
        addHandler(.textChanged) {
            if let text = EventBuffer.current.value()?.string {
                try await handler(text)
            }
        }
    }

    /// Fires when the search button is pressed - the one on the keyboard, or the
    /// magnifier where a platform draws a button.
    /// MAUI: SearchBar.SearchButtonPressed.
    public func onSearchButtonPressed(_ handler: @escaping EventHandler) -> Self {
        addHandler(.searchButtonPressed, handler)
    }
}
