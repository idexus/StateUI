// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A view whose type is chosen at run time: one of several views a value
/// picks, or a view held as `any View`. It offers what every view has, and
/// nothing that only some views do.
///
///     let pages: [AnyView] = [AnyView(Text("Home")), AnyView(Text("Settings"))]
///
/// Its type no longer tells what it holds, so a window's view whose `body`
/// is one stands on a page, an arrangement inside it included.
public struct AnyView: ElementView {
    /// The node of the view it holds.
    public var node: Node

    /// Holds `view`, its type left behind.
    public init(_ view: some View) {
        node = view.node
    }

    /// Holds a node built by hand.
    init(node: Node) {
        self.node = node
    }
}
