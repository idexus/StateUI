// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// Properties shared by a `TitleBar` and `Style<TitleBar>`.
public protocol TitleBarProperties: PropertyContainer {}

extension TitleBarProperties {
    /// Adds a second line that identifies the current document or section.
    public func subtitle(_ value: String) -> Modified {
        setValue(TitleBarContract.subtitle, value)
    }

    /// Places a small image beside the authored title.
    public func icon(_ value: ImageSource) -> Modified {
        setValue(TitleBarContract.icon, value)
    }

    /// The colour the bar draws its authored title and subtitle in.
    ///
    /// Use `background(_:)` for the title area's background.
    public func barForegroundColor(_ value: Color) -> Modified {
        setValue(TitleBarContract.barForegroundColor, value)
    }
}

/// An authored title area attached to a window through `WindowSession`.
///
/// Hosts with native window chrome place this content according to their own
/// title-area conventions. Hosts without an authored title area may ignore it.
///
///     struct HomePage: ContentView {
///         @Environment private var window: WindowSession
///
///         var content: any View {
///             VStack { … }
///                 .onCreated {
///                     window.titleBar = TitleBar("StateUI Gallery")
///                         .subtitle("Fundamentals")
///                         .trailingContent {
///                             Button("Surprise me")
///                         }
///                 }
///         }
///     }
///
/// `leadingContent`, `content`, and `trailingContent` are identified child
/// subtrees. A composed view inside a slot reads and follows its own state even
/// when the surrounding `TitleBar` value is written only once. Returning no
/// child removes the slot:
///
///     TitleBar("Notes")
///         .trailingContent {
///             if showsAccount {
///                 Button(icon: "account.png")
///             }
///         }
///
/// Each slot presents one root view. Put several controls in a layout and use
/// that layout as the root.
public struct TitleBar: View, TitleBarProperties {
    /// The node this control describes.
    public var node: Node

    /// An empty one - what a `Style<TitleBar>` is written against.
    public init() {
        node = Node(contract: TitleBarContract.self)
    }

    /// Creates a title area reading `title`.
    public init(_ title: String) {
        node = Node(contract: TitleBarContract.self)
        node.write(TitleBarContract.title, title)
    }

    // MARK: The slots

    /// Places one root view before the title, such as a sidebar toggle.
    ///
    ///     TitleBar("Notes")
    ///         .leadingContent {
    ///             Button(icon: "menu.png").onClicked { showsPane.toggle() }
    ///         }
    ///
    /// A closure producing nothing empties the slot, which is what an `if` in
    /// one is for.
    public func leadingContent(@ViewBuilder _ content: () -> [Element]) -> Self {
        slot(.leadingContent, content())
    }

    /// Places one root view in the central title-area position.
    ///
    ///     TitleBar("Notes")
    ///         .content {
    ///             SearchField($query).width(320)
    ///         }
    ///
    /// A closure producing nothing empties the slot.
    public func content(@ViewBuilder _ content: () -> [Element]) -> Self {
        slot(.content, content())
    }

    /// Places one root view at the far end of the title area.
    ///
    /// A closure producing nothing empties the slot.
    public func trailingContent(@ViewBuilder _ content: () -> [Element]) -> Self {
        slot(.trailingContent, content())
    }

    /// Replaces one named slot while keeping structural children last.
    private func slot(_ type: NodeType, _ views: [Element]) -> Self {
        var copy = self
        copy.node.children.removeAll { $0.type == type }
        let slots = copy.node.children.filter { $0.type == .contextMenu }
        copy.node.children.removeAll { $0.type == .contextMenu }

        let filled = views.first.map { [Node(type: type, children: [$0.body])] } ?? []

        copy.node.children += filled + slots
        return copy
    }
}
