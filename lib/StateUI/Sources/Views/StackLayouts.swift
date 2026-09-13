// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// Stacks its children top to bottom, each as tall as it asks to be.
///
///     VStack {
///         Label("One")
///         Label("Two")
///     }
///     .spacing(12)
///     .padding(24)
///
/// Children go in the trailing closure; everything else is a modifier, so the
/// layout of the code follows the layout on screen.
///
/// Three sizes are easy to confuse: `.spacing` is the gap BETWEEN children,
/// `.padding` is the room inside the stack's own edges, and `.margin` is the
/// room outside them.
///
/// A stack grows as tall as its children need and does not scroll, so a column
/// longer than the screen wants a `ScrollView` around it. A column that must
/// DIVIDE a fixed height among its children is a `Grid` instead.
public struct VStack: StackBase {
    /// The node this control describes.
    public var node: Node

    /// An empty stack, suitable as a `Style<VStack>` target.
    public init() {
        node = Node(type: .vStack)
    }

    /// A column of whatever the closure describes, in the order written.
    /// The closure is kept and run when the differ describes the stack.
    public init(@ViewBuilder content: @escaping () -> [Element]) {
        node = Node(type: .vStack)
        node.producer = { content().map { $0.body } }
    }
}

/// Stacks its children left to right, each as wide as it asks to be.
///
///     HStack {
///         Image("nav_home.png")
///         Label("Home")
///     }
///     .spacing(8)
///
/// A stack takes as much room as its children need and does not wrap. Use a
/// `Grid` when children must divide a known width into rows and columns.
public struct HStack: StackBase {
    /// The node this control describes.
    public var node: Node

    /// An empty stack, suitable as a `Style<HStack>` target.
    public init() {
        node = Node(type: .hStack)
    }

    /// A row of whatever the closure describes, in the order written.
    /// The closure is kept and run when the differ describes the stack.
    public init(@ViewBuilder content: @escaping () -> [Element]) {
        node = Node(type: .hStack)
        node.producer = { content().map { $0.body } }
    }
}
