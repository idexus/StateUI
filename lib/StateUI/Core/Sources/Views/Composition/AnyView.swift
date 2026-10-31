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

    /// Whether the view it holds may build one root or another, told by its type as it was held.
    private let flips: Bool

    /// Holds `view`, its type left behind.
    public init<Held: View>(_ view: Held) {
        node = view.node
        flips = Node.flips(Held.self)
    }

    /// Holds a node built by hand.
    init(node: Node) {
        self.node = node
        flips = node.type == .anchor
    }

    /// The same view with a modifier written on it: what outlives its branches on its anchor, where the view it
    /// holds may build one or another.
    public func modified(_ change: (inout Node) -> Void) -> Self {
        var modified = self
        modified.node = node.writing(change, flips: flips)
        return modified
    }
}
