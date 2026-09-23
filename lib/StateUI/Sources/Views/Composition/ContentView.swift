// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A view assembled from other views - how a piece of interface is factored
/// out and reused:
///
///     struct Header: ContentView {
///         private let title: String
///
///         init(_ title: String) {
///             self.title = title
///         }
///
///         var content: any View {
///             Label(title).fontSize(28).fontAttributes(.bold)
///         }
///     }
///
/// `content` is read the first time the view is built, and again when what it
/// was built with or a state it read changes; otherwise the view is carried
/// whole.
///
/// Configure it the way every control is: what it is goes in the initializer,
/// with no default, and what a caller may leave out is a modifier returning
/// `Self` that sets a `private` field. The modifiers every view has work on it
/// too, written after its own, since they return a `ModifiedContent`:
///
///     Header("Settings")
///         .margin(0, 8)
///         .gridRow(1)
public protocol ContentView: View where Modified == ModifiedContent {
    /// What this view is made of, read each time the view is built.
    var content: any View { get }
}

extension ContentView {
    // Design: docs/design/views/composition.md#a-composed-view-is-a-placeholder
    /// A placeholder for the content, which the differ builds once it knows
    /// whether this view stood here last render - so its `@State` is kept.
    public var body: Node {
        Node.composed(self, type: String(reflecting: Self.self)) { content.body }
    }

    /// A modifier written on a composed view, kept on a `ModifiedContent`
    /// wrapping the placeholder.
    public func modified(_ change: (inout Node) -> Void) -> ModifiedContent {
        var node = body
        change(&node)
        return ModifiedContent(node: node)
    }

    /// The placeholder, read afresh each time; assigning to it does nothing.
    public var node: Node {
        get { body }
        set {}
    }
}
